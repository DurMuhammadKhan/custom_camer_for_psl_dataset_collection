import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sign_word.dart';

/// Everything about files lives here: where the dataset folder is,
/// saving a video, deleting a video and counting saved videos.
///
/// Folder layout:
///   `PSL_Dataset/<Category>/<word>/<word>_<NNN>.mp4`
///
/// There is only one DatasetService, shared by all screens:
///   DatasetService.instance
class DatasetService {
  DatasetService._();
  static final DatasetService instance = DatasetService._();

  static const String folderName = 'PSL_Dataset';

  /// The PSL_Dataset folder we are saving into. Set by [init].
  late Directory root;

  /// Android only: true when storage permission was NOT given, so we are
  /// saving inside the app's own folder instead of the shared storage.
  bool usingAppFolder = false;

  /// How many videos each word has. Key = `<Category folder>/<word folder>`.
  final Map<String, int> _counts = {};

  // ---------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------

  /// Decides which folder to use, creates it and counts the saved videos.
  /// This never shows a permission popup, it only checks.
  Future<void> init() async {
    if (Platform.isAndroid) {
      // The app's own external folder. Needs no permission:
      //   /storage/emulated/0/Android/data/<app id>/files
      // (null only if the phone has no usable storage, then use Documents.)
      final appDir =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();

      // Everything before "/Android/" is the shared storage:
      //   /storage/emulated/0
      final sharedStorage = appDir.path.split('/Android/').first;
      final publicFolder = Directory('$sharedStorage/$folderName');

      // Try the public folder first (easy to find in Files app / over USB).
      // If we are not allowed to write there, fall back to the app folder.
      if (await _canWriteTo(publicFolder)) {
        root = publicFolder;
        usingAppFolder = false;
      } else {
        root = Directory('${appDir.path}/$folderName');
        usingAppFolder = true;
      }
    } else {
      // iOS: the app's Documents folder. It shows up in the Files app
      // because file sharing is switched on in ios/Runner/Info.plist.
      final documents = await getApplicationDocumentsDirectory();
      root = Directory('${documents.path}/$folderName');
      usingAppFolder = false;
    }

    await root.create(recursive: true);
    await refreshCounts();
  }

  /// Asks the user for storage permission (Android), then runs [init] again
  /// so we switch to the public folder if the permission was given.
  Future<void> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 11 and newer: "All files access". This opens a system
      // Settings page with a switch. (On older Android this permission does
      // not exist, so the call returns straight away without showing anything.)
      final allFiles = await Permission.manageExternalStorage.request();

      // Android 10 and older: the normal "Allow access to storage?" popup.
      if (!allFiles.isGranted) {
        await Permission.storage.request();
      }
    }
    await init();
  }

  /// Checks write access the simple way: really try to write a tiny file.
  Future<bool> _canWriteTo(Directory folder) async {
    try {
      await folder.create(recursive: true);
      final testFile = File('${folder.path}/.write_test');
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Names and folders
  // ---------------------------------------------------------------------

  /// Makes a text safe to use as a folder / file name:
  /// spaces and '/' become '_'. (A few other characters that phones and
  /// Windows do not allow in file names are replaced too.)
  static String sanitize(String text) {
    return text.trim().replaceAll(RegExp(r'[ /\\:*?"<>|]'), '_');
  }

  /// Folder of one word: `PSL_Dataset/<Category>/<word>`
  Directory wordFolder(SignWord word) {
    return Directory(
      '${root.path}/${sanitize(word.category)}/${sanitize(word.label)}',
    );
  }

  /// Finds the next free number from the existing file names.
  ///   ["able_001.mp4", "able_003.mp4"]  ->  4
  /// We use "highest + 1" (not "how many files + 1") so that after deleting
  /// a sample we never overwrite another one.
  static int nextIndex(Iterable<String> fileNames) {
    var highest = 0;
    for (final name in fileNames) {
      final match = RegExp(r'_(\d+)\.mp4$').firstMatch(name);
      if (match == null) continue;
      final number = int.parse(match.group(1)!);
      if (number > highest) highest = number;
    }
    return highest + 1;
  }

  // ---------------------------------------------------------------------
  // Saving, listing, deleting
  // ---------------------------------------------------------------------

  /// All saved videos of one word, in order (001, 002, ...).
  Future<List<File>> listSamples(SignWord word) async {
    final folder = wordFolder(word);
    if (!await folder.exists()) return [];

    final everything = await folder.list().toList();
    final videos = everything
        .whereType<File>()
        .where((file) => file.path.endsWith('.mp4'))
        .toList();
    videos.sort((a, b) => a.path.compareTo(b.path));
    return videos;
  }

  /// Moves a freshly recorded clip into the dataset and returns the new file.
  Future<File> saveSample(SignWord word, String recordedClipPath) async {
    // 1. Make sure the word's folder exists.
    final folder = wordFolder(word);
    await folder.create(recursive: true);

    // 2. Work out the file name, e.g. able_004.mp4
    final existing = await listSamples(word);
    final number = nextIndex(existing.map((file) => file.path));
    final paddedNumber = number.toString().padLeft(3, '0');
    final target = File(
      '${folder.path}/${sanitize(word.label)}_$paddedNumber.mp4',
    );

    // 3. Copy the clip there, then remove the temporary recording.
    //    (Copy + delete instead of "rename", because the camera's temp
    //    folder is on a different storage area and rename cannot cross it.)
    final clip = File(recordedClipPath);
    await clip.copy(target.path);
    await clip.delete();

    // 4. Update the count for this word.
    _counts[_key(word)] = existing.length + 1;
    return target;
  }

  /// Deletes one saved video (used for bad samples).
  Future<void> deleteSample(SignWord word, File video) async {
    await video.delete();
    _counts[_key(word)] = (await listSamples(word)).length;
  }

  // ---------------------------------------------------------------------
  // Counting (progress tracking)
  // ---------------------------------------------------------------------

  String _key(SignWord word) {
    return '${sanitize(word.category)}/${sanitize(word.label)}';
  }

  /// Counts every saved video by walking through the dataset folder once.
  /// The files themselves are the "source of truth", so the numbers stay
  /// correct even if videos are deleted with a file manager.
  Future<void> refreshCounts() async {
    _counts.clear();
    try {
      if (!await root.exists()) return;
      await for (final item in root.list(recursive: true)) {
        if (item is! File || !item.path.endsWith('.mp4')) continue;

        // .../PSL_Dataset/<Category>/<word>/<file>.mp4
        final parts = item.path.split('/');
        if (parts.length < 3) continue;
        final key = '${parts[parts.length - 3]}/${parts[parts.length - 2]}';
        _counts[key] = (_counts[key] ?? 0) + 1;
      }
    } on FileSystemException {
      // Folder not readable right now: show zero instead of crashing.
    }
  }

  /// Saved videos of one word.
  int countForWord(SignWord word) => _counts[_key(word)] ?? 0;

  /// Saved videos of all words in one category.
  int countForCategory(SignCategory category) {
    var total = 0;
    for (final word in category.words) {
      total += countForWord(word);
    }
    return total;
  }
}
