// Tests for the small pieces of logic that do not need a phone:
// reading the words list, cleaning names and numbering the files.

import 'dart:io';

import 'package:custom_camera_for_dataset_collection/models/sign_word.dart';
import 'package:custom_camera_for_dataset_collection/services/dataset_service.dart';
import 'package:custom_camera_for_dataset_collection/services/words_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('words.json is read into categories and words', () {
    final categories = parseCategories(
      '{"Adjectives": ["Adjectives_able", "Adjectives_absent minded"],'
      ' "Numbers": ["Numbers_10"]}',
    );

    expect(categories.map((c) => c.name), ['Adjectives', 'Numbers']);
    expect(categories[0].words.map((w) => w.label), ['able', 'absent minded']);
    expect(categories[0].words[0].category, 'Adjectives');
    expect(categories[1].words[0].label, '10');
  });

  test('label drops the prefix before the first underscore', () {
    const word = SignWord(id: 'family marriage_aunt (khala)', category: 'x');
    expect(word.label, 'aunt (khala)');

    const plain = SignWord(id: 'hello', category: 'x');
    expect(plain.label, 'hello');
  });

  test('sanitize replaces spaces and slashes with underscores', () {
    expect(DatasetService.sanitize('absent minded'), 'absent_minded');
    expect(DatasetService.sanitize('a/b c'), 'a_b_c');
    expect(DatasetService.sanitize('aunt (khala)'), 'aunt_(khala)');
  });

  test('nextIndex is the highest existing number plus one', () {
    expect(DatasetService.nextIndex([]), 1);
    expect(DatasetService.nextIndex(['/x/able_001.mp4']), 2);
    // 002 was deleted: we must not reuse 003 and overwrite it.
    expect(DatasetService.nextIndex(['able_001.mp4', 'able_003.mp4']), 4);
    // The number inside the word itself ("10") is not the sample number.
    expect(DatasetService.nextIndex(['10_002.mp4']), 3);
  });

  test('save, count and delete use PSL_Dataset/<Category>/<word>/', () async {
    final temp = await Directory.systemTemp.createTemp('psl_test');
    final dataset = DatasetService.instance..root = Directory(temp.path);
    const word = SignWord(
      id: 'Adjectives_absent minded',
      category: 'Adjectives',
    );

    // Pretend the camera recorded two clips.
    Future<String> fakeClip(String name) async {
      final clip = File('${temp.path}/$name');
      await clip.writeAsString('video');
      return clip.path;
    }

    final first = await dataset.saveSample(word, await fakeClip('a.tmp'));
    final second = await dataset.saveSample(word, await fakeClip('b.tmp'));

    expect(
      first.path,
      '${temp.path}/Adjectives/absent_minded/absent_minded_001.mp4',
    );
    expect(second.path.endsWith('absent_minded_002.mp4'), isTrue);
    expect(File('${temp.path}/a.tmp').existsSync(), isFalse);
    expect(dataset.countForWord(word), 2);

    // Counting from the files on disk gives the same answer.
    await dataset.refreshCounts();
    expect(dataset.countForWord(word), 2);

    await dataset.deleteSample(word, first);
    expect(dataset.countForWord(word), 1);

    // The next sample continues after 002 instead of reusing a number.
    final third = await dataset.saveSample(word, await fakeClip('c.tmp'));
    expect(third.path.endsWith('absent_minded_003.mp4'), isTrue);

    await temp.delete(recursive: true);
  });
}
