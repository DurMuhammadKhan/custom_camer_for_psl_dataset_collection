// Small data classes that describe what we want to record.
// They are filled from assets/words.json (see services/words_service.dart).

/// One word (sign) that we record videos for.
class SignWord {
  const SignWord({required this.id, required this.category});

  /// The exact text from words.json, e.g. "Adjectives_able".
  final String id;

  /// The category key from words.json, e.g. "Adjectives".
  final String category;

  /// The clean word shown on screen and used for the folder / file name.
  ///
  /// Every entry in words.json looks like `<prefix>_<word>`
  /// (e.g. "Adjectives_able"), so we drop everything up to the first "_"
  /// and keep "able". An entry without "_" is used as it is.
  ///
  /// If you ever want the full id in the folder names instead,
  /// just change this to `return id;`.
  String get label {
    final underscore = id.indexOf('_');
    return underscore == -1 ? id : id.substring(underscore + 1);
  }
}

/// A group of words, e.g. "Adjectives".
class SignCategory {
  const SignCategory({required this.name, required this.words});

  /// The category key from words.json. Also used as the folder name.
  final String name;

  final List<SignWord> words;
}
