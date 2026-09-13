import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../../domain/entities/viewer_type.dart';
import '../../../widgets/file_type_icon.dart';
import '../../../widgets/o_banner.dart';
import '../../../widgets/viewer_shell.dart';
import '../../viewer/viewer_router_screen.dart';

class ArchiveViewer extends ConsumerStatefulWidget {
  final FileEntity file;

  const ArchiveViewer({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<ArchiveViewer> createState() => _ArchiveViewerState();
}

class _ArchiveEntryNode {
  final String name;
  final String fullPath;
  final bool isDirectory;
  final int size;
  final ArchiveFile? file;

  _ArchiveEntryNode({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    required this.size,
    this.file,
  });
}

class _ArchiveViewerState extends ConsumerState<ArchiveViewer> {
  Archive? _archive;
  bool _isLoading = true;
  String? _errorMessage;
  String _currentPath = ''; // Empty string = root
  bool _isExtracting = false;
  double _extractProgress = 0.0;
  String? _statusBanner;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  String _stripArchiveExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.tar.gz')) return name.substring(0, name.length - 7);
    if (lower.endsWith('.tar.bz2')) return name.substring(0, name.length - 8);
    if (lower.endsWith('.tar.xz')) return name.substring(0, name.length - 7);
    if (lower.endsWith('.tgz')) return '${name.substring(0, name.length - 4)}.tar';
    if (lower.endsWith('.tbz2')) return '${name.substring(0, name.length - 5)}.tar';
    if (lower.endsWith('.tbz')) return '${name.substring(0, name.length - 4)}.tar';
    if (lower.endsWith('.txz')) return '${name.substring(0, name.length - 4)}.tar';
    final dot = name.lastIndexOf('.');
    if (dot > 0) return name.substring(0, dot);
    return 'extracted';
  }

  bool _isTarBytes(List<int> bytes) {
    if (bytes.length >= 262) {
      final ustar = String.fromCharCodes(bytes.sublist(257, 262));
      if (ustar == 'ustar') return true;
    }
    return false;
  }

  Future<void> _loadArchive() async {
    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Archive file not found.';
        });
        return;
      }

      final bytes = await file.readAsBytes();
      Archive? archive;

      final nameLower = widget.file.name.toLowerCase();
      final ext = widget.file.extension.toLowerCase();

      if (ext == 'zip' || ext == 'jar' || ext == 'war' || ext == 'apk' || ext == 'cbz' || ext == 'xpi') {
        archive = ZipDecoder().decodeBytes(bytes);
      } else if (ext == 'tar' || ext == 'cbr') {
        archive = TarDecoder().decodeBytes(bytes);
      } else if (ext == 'gz' || ext == 'tgz' || nameLower.endsWith('.tar.gz')) {
        final decompressed = GZipDecoder().decodeBytes(bytes);
        if (ext == 'tgz' || nameLower.endsWith('.tar.gz') || _isTarBytes(decompressed)) {
          archive = TarDecoder().decodeBytes(decompressed);
        } else {
          archive = Archive()
            ..addFile(ArchiveFile(_stripArchiveExtension(widget.file.name), decompressed.length, decompressed));
        }
      } else if (ext == 'bz2' || ext == 'tbz2' || ext == 'tbz' || nameLower.endsWith('.tar.bz2')) {
        final decompressed = BZip2Decoder().decodeBytes(bytes);
        if (ext == 'tbz2' || ext == 'tbz' || nameLower.endsWith('.tar.bz2') || _isTarBytes(decompressed)) {
          archive = TarDecoder().decodeBytes(decompressed);
        } else {
          archive = Archive()
            ..addFile(ArchiveFile(_stripArchiveExtension(widget.file.name), decompressed.length, decompressed));
        }
      } else if (ext == 'xz' || ext == 'txz' || nameLower.endsWith('.tar.xz')) {
        final decompressed = XZDecoder().decodeBytes(bytes);
        if (ext == 'txz' || nameLower.endsWith('.tar.xz') || _isTarBytes(decompressed)) {
          archive = TarDecoder().decodeBytes(decompressed);
        } else {
          archive = Archive()
            ..addFile(ArchiveFile(_stripArchiveExtension(widget.file.name), decompressed.length, decompressed));
        }
      } else {
        // Multi-level fallback: zip -> tar -> gz -> bz2 -> xz
        try {
          archive = ZipDecoder().decodeBytes(bytes);
        } catch (_) {
          try {
            archive = TarDecoder().decodeBytes(bytes);
          } catch (_) {
            try {
              final decompressed = GZipDecoder().decodeBytes(bytes);
              if (_isTarBytes(decompressed)) {
                archive = TarDecoder().decodeBytes(decompressed);
              } else {
                archive = Archive()
                  ..addFile(ArchiveFile(_stripArchiveExtension(widget.file.name), decompressed.length, decompressed));
              }
            } catch (_) {
              try {
                final decompressed = BZip2Decoder().decodeBytes(bytes);
                if (_isTarBytes(decompressed)) {
                  archive = TarDecoder().decodeBytes(decompressed);
                } else {
                  archive = Archive()
                    ..addFile(ArchiveFile(_stripArchiveExtension(widget.file.name), decompressed.length, decompressed));
                }
              } catch (_) {
                final decompressed = XZDecoder().decodeBytes(bytes);
                if (_isTarBytes(decompressed)) {
                  archive = TarDecoder().decodeBytes(decompressed);
                } else {
                  archive = Archive()
                    ..addFile(ArchiveFile(_stripArchiveExtension(widget.file.name), decompressed.length, decompressed));
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _archive = archive;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to read archive: $e';
        });
      }
    }
  }

  List<_ArchiveEntryNode> _getItemsInCurrentPath() {
    if (_archive == null) return [];

    final directChildren = <String, _ArchiveEntryNode>{};
    final prefix = _currentPath.isEmpty ? '' : '$_currentPath/';

    for (final file in _archive!.files) {
      final path = file.name.replaceAll('\\', '/');

      // Zip-Slip security check
      if (path.contains('../') || path.startsWith('/') || path.startsWith('..')) {
        continue;
      }

      if (_currentPath.isNotEmpty && !path.startsWith(prefix)) {
        continue;
      }

      final relative = path.substring(prefix.length);
      final slashIndex = relative.indexOf('/');

      if (slashIndex != -1) {
        // Directory
        final dirName = relative.substring(0, slashIndex);
        if (dirName.isNotEmpty && !directChildren.containsKey(dirName)) {
          directChildren[dirName] = _ArchiveEntryNode(
            name: dirName,
            fullPath: _currentPath.isEmpty ? dirName : '$_currentPath/$dirName',
            isDirectory: true,
            size: 0,
          );
        }
      } else {
        // File
        if (relative.isNotEmpty) {
          directChildren[relative] = _ArchiveEntryNode(
            name: relative,
            fullPath: path,
            isDirectory: file.isFile ? false : true,
            size: file.size,
            file: file,
          );
        }
      }
    }

    final list = directChildren.values.toList();
    list.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> _openEntry(_ArchiveEntryNode entry) async {
    if (entry.isDirectory) {
      setState(() {
        _currentPath = entry.fullPath;
      });
      return;
    }

    final file = entry.file;
    if (file == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(tempDir.path, 'openfile_cache', 'archive_preview'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final sanitizedName = p.basename(entry.name);
      final previewFile = File(p.join(cacheDir.path, sanitizedName));

      final content = file.content as List<int>;
      await previewFile.writeAsBytes(content);

      if (mounted) {
        final entity = FileEntity(
          path: previewFile.path,
          name: sanitizedName,
          size: content.length,
          lastModified: DateTime.now(),
          detectedType: ViewerType.unknown,
        );
        ViewerRouterScreen.open(context, entity);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to preview entry: $e')),
        );
      }
    }
  }

  Future<void> _extractAll() async {
    if (_archive == null) return;

    final outputDir = await FilePicker.getDirectoryPath();
    if (outputDir == null) return;

    setState(() {
      _isExtracting = true;
      _extractProgress = 0.0;
      _statusBanner = null;
    });

    try {
      final total = _archive!.files.length;
      int count = 0;

      for (final file in _archive!.files) {
        final normPath = p.normalize(file.name.replaceAll('\\', '/'));

        // ZIP-SLIP PROTECTION: reject any relative traversal attempts
        if (normPath.startsWith('..') || normPath.startsWith('/') || normPath.contains('../')) {
          continue;
        }

        final targetPath = p.join(outputDir, normPath);
        if (!p.isWithin(outputDir, targetPath) && targetPath != outputDir) {
          continue; // Block Zip Slip
        }

        if (file.isFile) {
          final outFile = File(targetPath);
          await outFile.parent.create(recursive: true);
          final data = file.content as List<int>;
          await outFile.writeAsBytes(data);
        } else {
          await Directory(targetPath).create(recursive: true);
        }

        count++;
        if (mounted) {
          setState(() {
            _extractProgress = count / (total > 0 ? total : 1);
          });
        }
      }

      if (mounted) {
        setState(() {
          _isExtracting = false;
          _statusBanner = 'Successfully extracted $count files to $outputDir';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _statusBanner = 'Extraction failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final customActions = <Widget>[
      if (!_isLoading && _archive != null)
        TextButton.icon(
          icon: const Icon(Icons.unarchive, size: 18),
          label: const Text('Extract all'),
          style: TextButton.styleFrom(
            foregroundColor: colors.accentPrimary,
          ),
          onPressed: _isExtracting ? null : _extractAll,
        ),
    ];

    Widget body;
    if (_isLoading) {
      body = Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
        ),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.stateError),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary)),
            ],
          ),
        ),
      );
    } else {
      final items = _getItemsInCurrentPath();

      body = Column(
        children: [
          if (_isExtracting)
            LinearProgressIndicator(
              value: _extractProgress,
              backgroundColor: colors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
            ),
          // Breadcrumbs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceApp,
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _currentPath = ''),
                  child: Row(
                    children: [
                      Icon(Icons.folder_zip, size: 18, color: colors.accentPrimary),
                      const SizedBox(width: 4),
                      Text('root', style: TextStyle(color: colors.accentPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                if (_currentPath.isNotEmpty) ...[
                  ..._currentPath.split('/').map((seg) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_right, size: 16, color: colors.textDisabled),
                        Text(seg, style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text('Folder is empty', style: TextStyle(color: colors.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: colors.divider),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: item.isDirectory
                            ? Icon(Icons.folder, color: colors.accentPrimary, size: 28)
                            : FileTypeIcon(
                                viewerType: ViewerType.unknown,
                                extension: p.extension(item.name).replaceFirst('.', ''),
                                size: 28,
                              ),
                        title: Text(
                          item.name,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: item.isDirectory
                            ? null
                            : Text(
                                Formatters.formatFileSize(item.size),
                                style: TextStyle(color: colors.textSecondary, fontSize: 12),
                              ),
                        trailing: Icon(Icons.chevron_right, size: 18, color: colors.textDisabled),
                        onTap: () => _openEntry(item),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    Widget? noticeBanner;
    if (_statusBanner != null) {
      noticeBanner = OBanner.notice(
        text: _statusBanner!,
        actionLabel: 'Dismiss',
        onAction: () => setState(() => _statusBanner = null),
      );
    }

    return ViewerShell(
      file: widget.file,
      noticeBanner: noticeBanner,
      customActions: customActions,
      child: body,
    );
  }
}
