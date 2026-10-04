import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/dataset_service.dart';

/// "Where are my videos?" - shows the dataset folder and how to reach it.
class DatasetInfoScreen extends StatefulWidget {
  const DatasetInfoScreen({super.key});

  @override
  State<DatasetInfoScreen> createState() => _DatasetInfoScreenState();
}

class _DatasetInfoScreenState extends State<DatasetInfoScreen> {
  final _dataset = DatasetService.instance;

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: _dataset.root.path));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Folder path copied')));
  }

  Future<void> _allowStorage() async {
    await _dataset.requestStoragePermission();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // How to find the folder is different on Android and iPhone.
    final String howToFind;
    if (Platform.isIOS) {
      howToFind =
          'Open the Files app > On My iPhone > PSL Dataset Collector > '
          'PSL_Dataset. With a cable, the same folder appears in Finder / '
          'iTunes under File Sharing.';
    } else if (_dataset.usingAppFolder) {
      howToFind =
          'Storage permission was not given, so the videos are inside the '
          'app\'s own folder. Connect the phone to a computer with USB (File '
          'transfer mode) and open the path above. Note: this folder is '
          'removed if you uninstall the app.';
    } else {
      howToFind =
          'Open the Files app > Internal storage > PSL_Dataset, or connect '
          'the phone to a computer with USB (File transfer mode) and open '
          'the PSL_Dataset folder.';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Where are my videos?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Dataset folder', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // SelectableText lets the user long-press and copy the path.
          SelectableText(_dataset.root.path),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _copyPath,
              icon: const Icon(Icons.copy),
              label: const Text('Copy path'),
            ),
          ),

          const Divider(height: 32),
          Text('Inside the folder', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'PSL_Dataset/<Category>/<word>/<word>_001.mp4\n'
            'Example: PSL_Dataset/Adjectives/able/able_001.mp4',
          ),

          const Divider(height: 32),
          Text('How to find it', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(howToFind),

          // Only when Android storage permission is missing.
          if (_dataset.usingAppFolder) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _allowStorage,
              icon: const Icon(Icons.lock_open),
              label: const Text('Allow storage access'),
            ),
          ],
        ],
      ),
    );
  }
}
