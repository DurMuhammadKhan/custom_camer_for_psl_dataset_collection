import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sign_word.dart';
import '../services/dataset_service.dart';
import 'review_screen.dart';
import 'samples_screen.dart';

/// What the record screen is doing right now.
enum _Stage {
  ready, // preview is showing, waiting for the Record button
  countdown, // 3-2-1 is on screen
  recording, // camera is recording
  stopping, // Stop was pressed, the clip is being finished
}

/// Back-camera preview card for ONE word:
/// Record -> 3-2-1 countdown -> recording (Stop + timer) -> review screen.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key, required this.word});

  final SignWord word;

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

// "WidgetsBindingObserver" tells us when the app goes to the background
// and comes back, so we can let go of the camera and take it again.
class _RecordScreenState extends State<RecordScreen>
    with WidgetsBindingObserver {
  final _dataset = DatasetService.instance;

  // The main app (psl_bridge) shows its camera inside a box that is 320 high
  // with 16 padding outside and 20 inside. So the picture you see there is
  // (screen width - 72) wide and 280 high. Our card gets the same shape, so
  // BoxFit.cover cuts the preview the same way and the signer is framed
  // exactly like in the main app.
  static const double _mainAppPreviewHeight = 280;
  static const double _mainAppSidePadding = 72;

  // --- camera ---
  CameraController? _controller; // null until the camera is ready
  bool _startingCamera = false;
  String? _problem; // shown instead of the preview when something is wrong
  bool _offerSettings = false; // show the "Open settings" button

  // --- recording ---
  _Stage _stage = _Stage.ready;
  int _countdown = 3;
  Timer? _countdownTimer;
  final Stopwatch _stopwatch = Stopwatch(); // measures the recording time
  Timer? _clockTimer; // redraws the timer text while recording

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _clockTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// App went to the background -> free the camera for other apps.
  /// App came back -> start the camera again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_controller == null) _initCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseCamera();
    }
  }

  // ---------------------------------------------------------------------
  // Camera init (back camera, 1080p, no audio) - same setup as the main app
  // ---------------------------------------------------------------------

  Future<void> _initCamera() async {
    if (_startingCamera) return; // already on its way
    _startingCamera = true;

    try {
      // Ask for the camera permission first, so a "no" gets a clear message.
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        _showProblem(
          'Camera permission is needed to record videos.',
          offerSettings: true,
        );
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showProblem('No camera was found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh, // ~1080p, matches main app
        enableAudio: false, // video only
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _problem = null;
        _stage = _Stage.ready;
      });
    } on CameraException catch (e) {
      _showProblem('Camera error: ${e.description ?? e.code}');
    } finally {
      _startingCamera = false;
    }
  }

  void _showProblem(String message, {bool offerSettings = false}) {
    if (!mounted) return;
    setState(() {
      _problem = message;
      _offerSettings = offerSettings;
    });
  }

  /// Stops everything and lets go of the camera.
  void _releaseCamera() {
    _countdownTimer?.cancel();
    _clockTimer?.cancel();
    _stopwatch
      ..stop()
      ..reset();

    final controller = _controller;
    _controller = null;
    controller?.dispose();

    if (mounted) setState(() => _stage = _Stage.ready);
  }

  // ---------------------------------------------------------------------
  // Cover-crop preview card (same look as the main app)
  // ---------------------------------------------------------------------

  // FittedBox(cover) + SizedBox(preview size) so the preview FILLS the card
  // and the overflow is cut off: no black bands, no distortion.
  //
  // This crop is ONLY what you see on screen. The saved video is always the
  // full camera frame (see _stopRecording).
  Widget _cameraCard(CameraController controller) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final preview = controller.value.previewSize!; // landscape (w > h)
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: preview.height, // swap for portrait
              height: preview.width,
              child: CameraPreview(controller),
            ),
          ),

          // Framing guide - stays visible BEFORE and DURING recording.
          IgnorePointer(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // 3-2-1 overlay (only before the recording starts).
          if (_stage == _Stage.countdown)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: Text(
                '$_countdown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Countdown
  // ---------------------------------------------------------------------

  /// Record button pressed: show 3, 2, 1 and then start recording.
  void _startCountdown() {
    setState(() {
      _stage = _Stage.countdown;
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _startRecording();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() => _stage = _Stage.ready);
  }

  // ---------------------------------------------------------------------
  // Record / stop (saves the FULL frame, uncropped)
  // ---------------------------------------------------------------------

  Future<void> _startRecording() async {
    try {
      await _controller!.startVideoRecording();
    } on CameraException catch (e) {
      _recordingFailed(e);
      return;
    }
    if (!mounted) return;

    // Start the on-screen timer and redraw it 10 times per second.
    _stopwatch
      ..reset()
      ..start();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {});
    });
    setState(() => _stage = _Stage.recording);
  }

  /// Returns the camera's temporary file. It is the full-frame video,
  /// NOT cropped to the card. The save logic copies it as it is into
  /// PSL_Dataset/Category/word/word_NNN.mp4.
  Future<XFile> _stopRecording() async {
    final file = await _controller!.stopVideoRecording();
    return file;
  }

  /// Stop button pressed: finish the clip, then show the review screen.
  Future<void> _stopAndReview() async {
    _clockTimer?.cancel();
    _stopwatch.stop();
    setState(() => _stage = _Stage.stopping);

    // 1. Finish the clip.
    final XFile clip;
    try {
      clip = await _stopRecording();
    } on CameraException catch (e) {
      _recordingFailed(e);
      return;
    }
    if (!mounted) return;
    setState(() => _stage = _Stage.ready);

    // 2. Show it on the review screen. That screen gives back the saved
    //    file after SAVE, or nothing (null) after RE-RECORD / back.
    final savedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(word: widget.word, clipPath: clip.path),
      ),
    );

    // 3a. RE-RECORD: throw the temporary clip away.
    if (savedFile == null) {
      final temporaryClip = File(clip.path);
      if (await temporaryClip.exists()) await temporaryClip.delete();
      return;
    }

    // 3b. SAVE: we are back on this word, ready for the next sample.
    if (!mounted) return;
    setState(() {}); // refresh the "saved" count in the top bar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${savedFile.uri.pathSegments.last}')),
    );
  }

  void _recordingFailed(CameraException e) {
    if (!mounted) return;
    setState(() => _stage = _Stage.ready);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording failed: ${e.description ?? e.code}')),
    );
  }

  Future<void> _openSamples() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SamplesScreen(word: widget.word)),
    );
    if (mounted) setState(() {}); // a sample may have been deleted
  }

  // ---------------------------------------------------------------------
  // What the screen looks like
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final savedCount = _dataset.countForWord(widget.word);

    final Widget body;
    if (_problem != null) {
      body = _buildProblem();
    } else if (controller == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _buildRecorder(controller);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.word.category),
        actions: [
          // How many samples this word already has. Tap to see / delete them.
          TextButton.icon(
            onPressed: _stage == _Stage.ready ? _openSamples : null,
            icon: const Icon(Icons.video_library),
            label: Text('$savedCount saved'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: body,
    );
  }

  /// Word on top, camera card in the middle, buttons at the bottom.
  Widget _buildRecorder(CameraController controller) {
    // Width / height of the card = shape of the main app's camera picture.
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardShape =
        (screenWidth - _mainAppSidePadding) / _mainAppPreviewHeight;

    return Column(
      children: [
        // The word to sign, big and clear at the top.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Text(
            widget.word.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Camera card.
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AspectRatio(
                aspectRatio: cardShape,
                child: _cameraCard(controller),
              ),
            ),
          ),
        ),

        // Buttons. The fixed height keeps the card from jumping when the
        // timer appears.
        SafeArea(
          top: false,
          child: Container(
            height: 160,
            margin: const EdgeInsets.only(bottom: 20),
            alignment: Alignment.bottomCenter,
            child: _buildControls(),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    switch (_stage) {
      case _Stage.ready:
        return _RoundButton(
          label: 'Record',
          icon: Icons.fiber_manual_record,
          color: Colors.red,
          onPressed: _startCountdown,
        );

      case _Stage.countdown:
        return _RoundButton(
          label: 'Cancel',
          icon: Icons.close,
          color: Colors.grey.shade700,
          onPressed: _cancelCountdown,
        );

      case _Stage.recording:
        final seconds = _stopwatch.elapsedMilliseconds / 1000;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Running timer.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'REC  ${seconds.toStringAsFixed(1)} s',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _RoundButton(
              label: 'Stop',
              icon: Icons.stop,
              color: Colors.red,
              onPressed: _stopAndReview,
            ),
          ],
        );

      case _Stage.stopping:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Colors.white),
        );
    }
  }

  /// Shown when the camera cannot be used (permission denied, no camera...).
  Widget _buildProblem() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              _problem!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _initCamera,
              child: const Text('Try again'),
            ),
            if (_offerSettings)
              TextButton(
                // Opens this app's page in the phone Settings, where the
                // permission can be switched on after "Don't ask again".
                onPressed: openAppSettings,
                child: const Text('Open settings'),
              ),
          ],
        ),
      ),
    );
  }
}

/// The big round Record / Stop / Cancel button with its label underneath.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 4),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon, size: 44),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
