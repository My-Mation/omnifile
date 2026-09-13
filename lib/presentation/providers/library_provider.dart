import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/file_entity.dart';
import '../../domain/entities/viewer_type.dart';
import 'detection_provider.dart';
import 'shared_preferences_provider.dart';

enum FileCategoryFilter {
  all('All'),
  pdf('PDF'),
  word('Word'),
  excel('Excel'),
  ppt('PPT'),
  code('Code'),
  media('Media'),
  archive('Archive');

  final String label;
  const FileCategoryFilter(this.label);
}

class LibraryState {
  final List<FileEntity> allFiles;
  final bool isLoading;
  final String searchQuery;
  final FileCategoryFilter activeFilter;
  final List<String> indexedFolders;

  const LibraryState({
    this.allFiles = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.activeFilter = FileCategoryFilter.all,
    this.indexedFolders = const [],
  });

  LibraryState copyWith({
    List<FileEntity>? allFiles,
    bool? isLoading,
    String? searchQuery,
    FileCategoryFilter? activeFilter,
    List<String>? indexedFolders,
  }) {
    return LibraryState(
      allFiles: allFiles ?? this.allFiles,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      indexedFolders: indexedFolders ?? this.indexedFolders,
    );
  }

  List<FileEntity> get filteredFiles {
    return allFiles.where((file) {
      // 1. Search filter
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        if (!file.name.toLowerCase().contains(q)) return false;
      }

      // 2. Category filter
      final ext = file.extension.toLowerCase();
      switch (activeFilter) {
        case FileCategoryFilter.all:
          return true;
        case FileCategoryFilter.pdf:
          return file.detectedType == ViewerType.pdf || ext == 'pdf';
        case FileCategoryFilter.word:
          return ext == 'doc' || ext == 'docx' || ext == 'odt';
        case FileCategoryFilter.excel:
          return ext == 'xls' || ext == 'xlsx' || ext == 'ods' || ext == 'csv';
        case FileCategoryFilter.ppt:
          return ext == 'ppt' || ext == 'pptx' || ext == 'odp';
        case FileCategoryFilter.code:
          return file.detectedType == ViewerType.code ||
              file.detectedType == ViewerType.html ||
              file.detectedType == ViewerType.json ||
              file.detectedType == ViewerType.text ||
              file.detectedType == ViewerType.markdown;
        case FileCategoryFilter.media:
          return file.detectedType == ViewerType.image ||
              file.detectedType == ViewerType.video ||
              file.detectedType == ViewerType.audio ||
              file.detectedType == ViewerType.svg;
        case FileCategoryFilter.archive:
          return file.detectedType == ViewerType.archive ||
              file.detectedType == ViewerType.epub ||
              ext == 'zip' ||
              ext == 'tar' ||
              ext == 'gz' ||
              ext == 'tgz' ||
              ext == 'bz2' ||
              ext == 'tbz2' ||
              ext == 'xz' ||
              ext == 'txz' ||
              ext == '7z' ||
              ext == 'rar' ||
              ext == 'jar' ||
              ext == 'apk';
      }
    }).toList();
  }
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  final Ref _ref;
  final SharedPreferences _prefs;

  static const String _foldersKey = 'v2_indexed_folders';

  LibraryNotifier(this._ref, this._prefs) : super(const LibraryState()) {
    _loadCustomFolders();
    scanLibrary();
  }

  void _loadCustomFolders() {
    final custom = _prefs.getStringList(_foldersKey) ?? [];
    state = state.copyWith(indexedFolders: custom);
  }

  Future<void> addFolder(String folderPath) async {
    if (state.indexedFolders.contains(folderPath)) return;
    final updated = [...state.indexedFolders, folderPath];
    await _prefs.setStringList(_foldersKey, updated);
    state = state.copyWith(indexedFolders: updated);
    await scanLibrary();
  }

  Future<void> removeFolder(String folderPath) async {
    final updated = state.indexedFolders.where((f) => f != folderPath).toList();
    await _prefs.setStringList(_foldersKey, updated);
    state = state.copyWith(indexedFolders: updated);
    await scanLibrary();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(FileCategoryFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> scanLibrary() async {
    state = state.copyWith(isLoading: true);

    final detector = _ref.read(detectFileTypeUseCaseProvider);
    final filesFound = <FileEntity>[];
    final scannedPaths = <String>{};

    // Standard Android & system storage paths to look into
    final searchDirs = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      Platform.environment['HOME'] != null ? '${Platform.environment['HOME']}/Downloads' : '',
      Platform.environment['HOME'] != null ? '${Platform.environment['HOME']}/Documents' : '',
      ...state.indexedFolders,
    ].where((p) => p.isNotEmpty).toSet();

    for (final dirPath in searchDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        final pendingFiles = <File>[];
        await for (final entry in dir.list(recursive: false, followLinks: false)) {
          if (entry is File) {
            final name = entry.path.split(RegExp(r'[/\\]')).last;
            if (name.startsWith('.')) continue;
            if (scannedPaths.contains(entry.path)) continue;
            scannedPaths.add(entry.path);
            pendingFiles.add(entry);
          }
        }

        // Process in concurrent batches of 32 to maximize I/O throughput without blocking UI
        const batchSize = 32;
        for (int i = 0; i < pendingFiles.length; i += batchSize) {
          final chunk = pendingFiles.sublist(
            i,
            i + batchSize > pendingFiles.length ? pendingFiles.length : i + batchSize,
          );

          final results = await Future.wait(
            chunk.map((file) async {
              try {
                final stat = await file.stat();
                final name = file.path.split(RegExp(r'[/\\]')).last;
                final detected = detector.detectByPathOnly(file.path);
                return FileEntity(
                  path: file.path,
                  name: name,
                  size: stat.size,
                  lastModified: stat.modified,
                  detectedType: detected,
                );
              } catch (_) {
                return null;
              }
            }),
          );

          for (final f in results) {
            if (f != null) filesFound.add(f);
          }
        }
      } catch (_) {}
    }

    // Sort by modified date descending (newest first)
    filesFound.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    state = state.copyWith(allFiles: filesFound, isLoading: false);
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LibraryNotifier(ref, prefs);
});
