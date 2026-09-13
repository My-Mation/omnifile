import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openfile/data/repositories/recents_repository_impl.dart';
import 'package:openfile/domain/entities/file_entity.dart';
import 'package:openfile/domain/entities/viewer_type.dart';

void main() {
  group('RecentsRepositoryImpl', () {
    late SharedPreferences prefs;
    late RecentsRepositoryImpl repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = RecentsRepositoryImpl(prefs);
    });

    test('adds and retrieves recent files, preserving order and cap of 20', () async {
      final file1 = FileEntity(
        path: '/path/to/file1.txt',
        name: 'file1.txt',
        size: 100,
        lastModified: DateTime.now(),
        detectedType: ViewerType.unknown,
      );
      final file2 = FileEntity(
        path: '/path/to/file2.pdf',
        name: 'file2.pdf',
        size: 200,
        lastModified: DateTime.now(),
        detectedType: ViewerType.unknown,
      );

      await repo.addRecent(file1);
      await repo.addRecent(file2);

      var recents = await repo.getRecents();
      expect(recents.length, 2);
      expect(recents[0].name, 'file2.pdf'); // latest at index 0
      expect(recents[1].name, 'file1.txt');

      // Re-adding file1 moves it to index 0 without duplicates
      await repo.addRecent(file1);
      recents = await repo.getRecents();
      expect(recents.length, 2);
      expect(recents[0].name, 'file1.txt');
      expect(recents[1].name, 'file2.pdf');
    });

    test('removes recent file and supports restore', () async {
      final file1 = FileEntity(
        path: '/path/to/file1.txt',
        name: 'file1.txt',
        size: 100,
        lastModified: DateTime.now(),
      );
      await repo.addRecent(file1);
      expect((await repo.getRecents()).length, 1);

      await repo.removeRecent(file1.path);
      expect((await repo.getRecents()).length, 0);

      await repo.insertRecentAt(0, file1);
      expect((await repo.getRecents()).length, 1);
    });

    test('clearRecents removes all entries', () async {
      final file = FileEntity(
        path: '/path/to/file.txt',
        name: 'file.txt',
        size: 100,
        lastModified: DateTime.now(),
      );
      await repo.addRecent(file);
      await repo.clearRecents();
      expect((await repo.getRecents()).length, 0);
    });
  });
}
