import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays one video file in a loop. Tap the video to pause / resume.
/// Used for the preview after recording and for watching saved samples.
class ClipPlayer extends StatefulWidget {
  const ClipPlayer({super.key, required this.file});

  final File file;

  @override
  State<ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends State<ClipPlayer> {
  late final VideoPlayerController _player;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(widget.file);
    _start();
  }

  Future<void> _start() async {
    try {
      // Load the file, then play it again and again without sound.
      await _player.initialize();
      await _player.setLooping(true);
      await _player.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _player.value.isPlaying ? _player.pause() : _player.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Could not play this clip.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Center(
        // Keep the video's own shape (portrait) instead of stretching it.
        child: AspectRatio(
          aspectRatio: _player.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_player),
              if (!_player.value.isPlaying)
                const Icon(Icons.play_circle, size: 72, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
