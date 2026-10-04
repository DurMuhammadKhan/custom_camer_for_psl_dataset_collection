import 'package:flutter/material.dart';

import '../models/sign_word.dart';
import '../services/dataset_service.dart';
import '../widgets/count_badge.dart';
import 'record_screen.dart';

/// The words of one category, each with its sample count badge.
/// Tap a word to record it.
class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key, required this.category});

  final SignCategory category;

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  final _dataset = DatasetService.instance;

  Future<void> _openWord(SignWord word) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecordScreen(word: word)),
    );
    // Back from recording: rebuild so the badges show the new counts.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final total = _dataset.countForCategory(category);

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$total videos recorded in this category '
              '(${category.words.length} words)',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            // ListView.builder only builds the rows you can see,
            // which keeps long lists (400+ words) fast.
            child: ListView.builder(
              itemCount: category.words.length,
              itemBuilder: (context, index) {
                final word = category.words[index];
                return ListTile(
                  title: Text(word.label),
                  trailing: CountBadge(_dataset.countForWord(word)),
                  onTap: () => _openWord(word),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
