import 'dart:io';

import 'package:flutter/material.dart';

import '../models/sign_word.dart';
import '../services/dataset_service.dart';
import '../widgets/clip_player.dart';

/// The saved videos of one word. Tap to watch, bin icon to delete a bad one.
class SamplesScreen extends StatefulWidget {
  const SamplesScreen({super.key, required this.word});

  final SignWord word;

  @override
  State<SamplesScreen> createState() => _SamplesScreenState();
}

class _SamplesScreenState extends State<SamplesScreen> {
  final _dataset = DatasetService.instance;

  /// null while the list is loading.
  List<File>? _samples;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final samples = await _dataset.listSamples(widget.word);
    if (mounted) setState(() => _samples = samples);
  }

  String _fileName(File file) => file.uri.pathSegments.last;

  /// Opens a simple page that plays the saved video.
  void _play(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(_fileName(file)),
          ),
          body: ClipPlayer(file: file),
        ),
      ),
    );
  }

  /// Asks "are you sure?" first, because a deleted video cannot come back.
  Future<void> _delete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this sample?'),
        content: Text('${_fileName(file)} will be removed from the phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _dataset.deleteSample(widget.word, file);
    } on FileSystemException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: ${e.message}')));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final samples = _samples;

    return Scaffold(
      appBar: AppBar(title: Text('Samples: ${widget.word.label}')),
      body: samples == null
          ? const Center(child: CircularProgressIndicator())
          : samples.isEmpty
          ? const Center(child: Text('No videos saved for this word yet.'))
          : ListView.builder(
              itemCount: samples.length,
              itemBuilder: (context, index) {
                final file = samples[index];
                return ListTile(
                  leading: const Icon(Icons.movie),
                  title: Text(_fileName(file)),
                  onTap: () => _play(file),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(file),
                  ),
                );
              },
            ),
    );
  }
}
