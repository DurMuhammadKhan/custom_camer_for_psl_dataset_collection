import 'package:flutter/material.dart';

import '../models/sign_word.dart';
import '../services/dataset_service.dart';
import '../services/words_service.dart';
import '../widgets/count_badge.dart';
import 'dataset_info_screen.dart';
import 'words_screen.dart';

/// HOME SCREEN: overall summary + the list of categories.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _dataset = DatasetService.instance;

  /// null while the app is still loading.
  List<SignCategory>? _categories;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Runs once when the app opens.
  Future<void> _start() async {
    try {
      // 1. Read the words list from assets/words.json.
      final categories = await loadCategories();
      // 2. Find the dataset folder and count the videos already saved.
      await _dataset.init();
      if (!mounted) return;
      setState(() => _categories = categories);

      // 3. Android without storage permission: explain and ask for it.
      if (_dataset.usingAppFolder) _askStoragePermission();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start: $e');
    }
  }

  /// Explains why we need storage access, then opens the system request.
  /// If the user says no, the app still works and saves in its own folder.
  Future<void> _askStoragePermission() async {
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow storage access?'),
        content: const Text(
          'Videos are saved in a "PSL_Dataset" folder on your phone storage, '
          'so you can find them in the Files app or copy them over USB.\n\n'
          'Without this permission the videos are saved inside the app\'s own '
          'folder instead, which is harder to find.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (allow != true) return;

    await _dataset.requestStoragePermission();
    if (mounted) setState(() {});
  }

  Future<void> _openCategory(SignCategory category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WordsScreen(category: category)),
    );
    // Back on this screen: count again so the numbers are up to date.
    await _dataset.refreshCounts();
    if (mounted) setState(() {});
  }

  Future<void> _openInfo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DatasetInfoScreen()),
    );
    // Storage permission may have changed on that screen.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PSL Dataset Collector'),
        actions: [
          IconButton(
            tooltip: 'Where are my videos?',
            icon: const Icon(Icons.folder_open),
            onPressed: categories == null ? null : _openInfo,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : categories == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSummary(categories),
                for (final category in categories)
                  ListTile(
                    title: Text(category.name),
                    subtitle: Text('${category.words.length} words'),
                    // Total videos recorded in this category.
                    trailing: CountBadge(_dataset.countForCategory(category)),
                    onTap: () => _openCategory(category),
                  ),
              ],
            ),
    );
  }

  /// The card on top, e.g. "120 videos across 14 categories".
  Widget _buildSummary(List<SignCategory> categories) {
    var totalVideos = 0;
    var totalWords = 0;
    var wordsWithVideos = 0;
    for (final category in categories) {
      totalVideos += _dataset.countForCategory(category);
      totalWords += category.words.length;
      for (final word in category.words) {
        if (_dataset.countForWord(word) > 0) wordsWithVideos++;
      }
    }

    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$totalVideos videos across ${categories.length} categories',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('$wordsWithVideos of $totalWords words have a sample'),

            // Shown only when storage permission is missing on Android.
            if (_dataset.usingAppFolder) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.warning_amber, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No storage permission: saving inside the app folder.',
                    ),
                  ),
                  TextButton(
                    onPressed: _askStoragePermission,
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
