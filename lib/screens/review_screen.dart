import 'dart:io';

import 'package:flutter/material.dart';

import '../models/sign_word.dart';
import '../services/dataset_service.dart';
import '../widgets/clip_player.dart';

/// Shown right after Stop: plays the new clip with SAVE and RE-RECORD.
///
/// It closes with:
///   - the saved File  -> SAVE was pressed and the video is in the dataset
///   - null            -> RE-RECORD (or the back button): discard the clip
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.word, required this.clipPath});

  final SignWord word;

  /// The temporary video file that the camera just recorded.
  final String clipPath;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final savedFile = await DatasetService.instance.saveSample(
        widget.word,
        widget.clipPath,
      );
      if (mounted) Navigator.pop(context, savedFile);
    } on FileSystemException catch (e) {
      // Stay on this screen so the clip is not lost and Save can be retried.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Review: ${widget.word.label}'),
      ),
      body: Column(
        children: [
          // The recorded clip, playing in a loop.
          Expanded(child: ClipPlayer(file: File(widget.clipPath))),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.replay),
                      label: const Text('RE-RECORD'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.check),
                      label: Text(_saving ? 'SAVING...' : 'SAVE'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
