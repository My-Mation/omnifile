import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../core/theme/open_file_colors.dart';
import '../../domain/entities/file_entity.dart';
import '../providers/detection_provider.dart';
import '../providers/library_provider.dart';
import '../providers/recents_provider.dart';

class OcrResultSheet extends ConsumerStatefulWidget {
  final String text;
  final String sourceFileName;
  final String sourceFilePath;

  const OcrResultSheet({
    super.key,
    required this.text,
    required this.sourceFileName,
    required this.sourceFilePath,
  });

  static Future<void> show(
    BuildContext context, {
    required String text,
    required String sourceFileName,
    required String sourceFilePath,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OcrResultSheet(
        text: text,
        sourceFileName: sourceFileName,
        sourceFilePath: sourceFilePath,
      ),
    );
  }

  @override
  ConsumerState<OcrResultSheet> createState() => _OcrResultSheetState();
}

class _OcrResultSheetState extends ConsumerState<OcrResultSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportAsTxt() async {
    try {
      final sourceFile = File(widget.sourceFilePath);
      final parentDir = sourceFile.parent.path;
      final originalName = widget.sourceFileName;
      final nameWithoutExt = originalName.contains('.')
          ? originalName.substring(0, originalName.lastIndexOf('.'))
          : originalName;

      String newFileName = '$nameWithoutExt (ocr).txt';
      String newFilePath = p.join(parentDir, newFileName);
      int counter = 2;
      while (await File(newFilePath).exists()) {
        newFileName = '$nameWithoutExt (ocr) ($counter).txt';
        newFilePath = p.join(parentDir, newFileName);
        counter++;
      }

      await File(newFilePath).writeAsString(widget.text);

      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final entity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: widget.text.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(entity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported as $newFileName'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final wordCount = widget.text.trim().isEmpty ? 0 : widget.text.trim().split(RegExp(r'\s+')).length;
    final charCount = widget.text.length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recognized Text (OCR)',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$wordCount words • $charCount chars',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: colors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions Bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Text copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.save_alt_rounded, size: 16),
                    label: const Text('Export .txt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _exportAsTxt,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  color: colors.textPrimary,
                  tooltip: 'Share text',
                  onPressed: () {
                    SharePlus.instance.share(ShareParams(text: widget.text));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colors.surfaceInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: colors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: colors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search within recognized text...',
                        hintStyle: TextStyle(color: colors.textDisabled, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${RegExp(RegExp.escape(_searchQuery), caseSensitive: false).allMatches(widget.text).length} matches',
                        style: TextStyle(color: colors.textSecondary, fontSize: 11),
                      ),
                    ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: colors.textSecondary,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Text Content Box
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceApp,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.divider, width: 0.5),
                ),
                child: SingleChildScrollView(
                  child: widget.text.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'No readable text detected.',
                              style: TextStyle(color: colors.textDisabled, fontSize: 13),
                            ),
                          ),
                        )
                      : SelectableText(
                          widget.text,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            height: 1.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
