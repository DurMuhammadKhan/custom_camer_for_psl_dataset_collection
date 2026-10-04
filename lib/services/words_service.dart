import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/sign_word.dart';

/// Step 1: read the manifest file that is bundled with the app.
/// Step 2: turn its text into a list of categories.
Future<List<SignCategory>> loadCategories() async {
  final text = await rootBundle.loadString('assets/words.json');
  return parseCategories(text);
}

/// Turns the JSON text into categories.
///
/// Expected shape:
///   { "Category": ["word1", "word2"], "AnotherCategory": ["word3"] }
List<SignCategory> parseCategories(String jsonText) {
  final Map<String, dynamic> json = jsonDecode(jsonText);

  final categories = <SignCategory>[];
  for (final entry in json.entries) {
    final words = <SignWord>[];
    for (final word in entry.value as List) {
      words.add(SignWord(id: word as String, category: entry.key));
    }
    categories.add(SignCategory(name: entry.key, words: words));
  }
  return categories;
}
