import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../domain/entities/file_entity.dart';
import '../../../domain/entities/image_text_overlay_model.dart';
import '../../providers/detection_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/recents_provider.dart';
import '../../widgets/in_viewer_find_bar.dart';
import '../viewer/viewer_router_screen.dart';

class PdfEditorScreen extends ConsumerStatefulWidget {
  final FileEntity file;
  final int initialPage;
  final String? initialSearchQuery;

  const PdfEditorScreen({
    super.key,
    required this.file,
    this.initialPage = 0,
    this.initialSearchQuery,
  });

  static void open(
    BuildContext context,
    FileEntity file, {
    int initialPage = 0,
    String? initialSearchQuery,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfEditorScreen(
          file: file,
          initialPage: initialPage,
          initialSearchQuery: initialSearchQuery,
        ),
      ),
    );
  }

  @override
  ConsumerState<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends ConsumerState<PdfEditorScreen> {
  late int _currentPage;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  String? _renderedImagePath;
  int _imageWidth = 0;
  int _imageHeight = 0;
  double _pdfPageWidth = 595.0;
  double _pdfPageHeight = 842.0;

  List<ImageTextBlock> _textBlocks = [];
  ImageTextBlock? _selectedBlock;
  bool _tapToAddTextMode = false;

  // Search State
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchMatchIndices = [];
  int _currentSearchMatchIndex = -1;

  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _isSearchActive = true;
      _searchController.text = widget.initialSearchQuery!;
    }
    _loadPage(_currentPage);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _transformController.dispose();
    _cleanupRenderedImage();
    super.dispose();
  }

  void _cleanupRenderedImage() {
    if (_renderedImagePath != null) {
      try {
        final f = File(_renderedImagePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _loadPage(int pageIndex) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _textBlocks = [];
      _selectedBlock = null;
      _searchMatchIndices = [];
      _currentSearchMatchIndex = -1;
    });

    _cleanupRenderedImage();

    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'PDF file not found on disk.';
        });
        return;
      }

      final bytes = await file.readAsBytes();

      // Read PDF document geometry
      PdfDocument? doc;
      try {
        doc = PdfDocument(inputBytes: bytes);
        _totalPages = math.max(1, doc.pages.count);
        final safeIndex = pageIndex.clamp(0, _totalPages - 1);
        _currentPage = safeIndex;
        final page = doc.pages[safeIndex];
        _pdfPageWidth = page.size.width;
        _pdfPageHeight = page.size.height;
      } catch (e) {
        // Fallback dimensions if encrypted or partially damaged
        _pdfPageWidth = 595.0;
        _pdfPageHeight = 842.0;
      }

      // Render page using native Android PdfRenderer platform channel
      final renderedPaths = await OcrService.instance.renderPdfPages(
        widget.file.path,
        pageIndices: [_currentPage],
        scale: 2.0,
      );

      if (renderedPaths.isEmpty) {
        doc?.dispose();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to rasterize PDF page.';
        });
        return;
      }

      final imagePath = renderedPaths.first;
      _renderedImagePath = imagePath;

      // Get image dimensions
      final imgBytes = await File(imagePath).readAsBytes();
      final descriptor = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(imgBytes),
      );
      _imageWidth = descriptor.width;
      _imageHeight = descriptor.height;

      // Extract vector text lines with exact bounding boxes
      final blocks = <ImageTextBlock>[];
      if (doc != null) {
        try {
          final extractor = PdfTextExtractor(doc);
          final textLines = extractor.extractTextLines(
            startPageIndex: _currentPage,
            endPageIndex: _currentPage,
          );

          final scaleX = _imageWidth / _pdfPageWidth;
          final scaleY = _imageHeight / _pdfPageHeight;

          for (final line in textLines) {
            if (line.text.trim().isEmpty) continue;
            final rect = Rect.fromLTWH(
              line.bounds.left * scaleX,
              line.bounds.top * scaleY,
              line.bounds.width * scaleX,
              line.bounds.height * scaleY,
            );
            final fontSize = line.fontSize > 0 ? line.fontSize : (rect.height * 0.8);

            blocks.add(ImageTextBlock(
              id: 'vec_${line.hashCode}_${line.bounds.left.toInt()}_${line.bounds.top.toInt()}',
              rect: rect,
              text: line.text,
              originalText: line.text,
              fontSize: fontSize,
              textColor: Colors.black,
              backgroundColor: Colors.white,
              isCoverOriginal: true,
              isManual: false,
            ));
          }
        } catch (_) {}
      }
      doc?.dispose();

      // If page had no vector text (scanned book/document), automatically run on-device ML Kit OCR
      if (blocks.length < 3) {
        try {
          final recognized = await OcrService.instance.recognizeImageFileDetailed(imagePath);
          final ocrBlocks = <ImageTextBlock>[];
          for (final b in recognized.blocks) {
            for (final line in b.lines) {
              final box = line.boundingBox;
              if (box.width <= 0 || box.height <= 0 || line.text.trim().isEmpty) continue;
              final estFontSize = (box.height * 0.82).clamp(8.0, 72.0);
              ocrBlocks.add(ImageTextBlock(
                id: 'ocr_${line.hashCode}_${box.left.toInt()}_${box.top.toInt()}',
                rect: box,
                text: line.text,
                originalText: line.text,
                fontSize: estFontSize,
                textColor: Colors.black,
                backgroundColor: Colors.white,
                isCoverOriginal: true,
                isManual: false,
              ));
            }
          }
          if (ocrBlocks.isNotEmpty) {
            blocks.clear();
            blocks.addAll(ocrBlocks);
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _textBlocks = blocks;
          _isLoading = false;
        });

        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load PDF page: $e';
        });
      }
    }
  }

  void _copyWholePageText() async {
    if (_textBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text detected on this page')),
      );
      return;
    }

    final allText = _textBlocks.map((b) => b.text).join('\n').trim();
    await Clipboard.setData(ClipboardData(text: allText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied all page text (${_textBlocks.length} blocks, ${allText.length} chars) to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchMatchIndices = [];
        _currentSearchMatchIndex = -1;
      });
      return;
    }

    final lower = query.toLowerCase();
    final matches = <int>[];
    for (int i = 0; i < _textBlocks.length; i++) {
      if (_textBlocks[i].text.toLowerCase().contains(lower)) {
        matches.add(i);
      }
    }

    setState(() {
      _searchMatchIndices = matches;
      _currentSearchMatchIndex = matches.isNotEmpty ? 0 : -1;
      if (matches.isNotEmpty) {
        _selectedBlock = _textBlocks[matches[0]];
      }
    });
  }

  void _editTextBlockDialog(ImageTextBlock block) {
    final colors = context.colors;
    final controller = TextEditingController(text: block.text);
    double curFontSize = block.fontSize;
    Color curTextColor = block.textColor;
    Color curBgColor = block.backgroundColor;
    bool isCover = block.isCoverOriginal;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            block.isManual ? 'Edit Added Text Block' : 'Edit PDF Text (Cover & Replace)',
            style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  maxLines: null,
                  autofocus: true,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Text Content',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Font Size: ${curFontSize.toInt()} pt',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                Slider(
                  value: curFontSize.clamp(8.0, 72.0),
                  min: 8.0,
                  max: 72.0,
                  activeColor: colors.accentPrimary,
                  onChanged: (v) => setDialogState(() => curFontSize = v),
                ),
                const SizedBox(height: 8),
                Text('Cover & Style', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Black on White'),
                      selected: curTextColor == Colors.black && curBgColor == Colors.white,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = Colors.black;
                        curBgColor = Colors.white;
                        isCover = true;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('White on Black'),
                      selected: curTextColor == Colors.white && curBgColor == Colors.black,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = Colors.white;
                        curBgColor = Colors.black;
                        isCover = true;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Clear / Transparent'),
                      selected: curBgColor == Colors.transparent,
                      onSelected: (_) => setDialogState(() {
                        curBgColor = Colors.transparent;
                        isCover = false;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Delete text: replace with empty string & cover original
                setState(() {
                  block.text = '';
                  block.isCoverOriginal = true;
                  block.backgroundColor = Colors.white;
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Covered / Removed original text')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: colors.stateError),
              child: const Text('Delete / Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentPrimary,
                foregroundColor: colors.accentOnAccent,
              ),
              onPressed: () {
                setState(() {
                  block.text = controller.text;
                  block.fontSize = curFontSize;
                  block.textColor = curTextColor;
                  block.backgroundColor = curBgColor;
                  block.isCoverOriginal = isCover;
                  _selectedBlock = block;
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _addTextBlockDialog(double imgX, double imgY) {
    final colors = context.colors;
    final controller = TextEditingController();
    double curFontSize = 14.0;
    Color curTextColor = Colors.black;
    Color curBgColor = Colors.white;
    bool isCover = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Add Text at Tapped Position',
            style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Enter text',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Font Size: ${curFontSize.toInt()} pt',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                Slider(
                  value: curFontSize,
                  min: 8.0,
                  max: 72.0,
                  activeColor: colors.accentPrimary,
                  onChanged: (v) => setDialogState(() => curFontSize = v),
                ),
                const SizedBox(height: 8),
                Text('Style & Background', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Black on White'),
                      selected: curTextColor == Colors.black && curBgColor == Colors.white,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = Colors.black;
                        curBgColor = Colors.white;
                        isCover = true;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('White on Black'),
                      selected: curTextColor == Colors.white && curBgColor == Colors.black,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = Colors.white;
                        curBgColor = Colors.black;
                        isCover = true;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Transparent'),
                      selected: curBgColor == Colors.transparent,
                      onSelected: (_) => setDialogState(() {
                        curBgColor = Colors.transparent;
                        isCover = false;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentPrimary,
                foregroundColor: colors.accentOnAccent,
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  final estimatedWidth = (text.length * curFontSize * 0.6).clamp(60.0, 600.0);
                  final estimatedHeight = curFontSize * 1.3;
                  final newBlock = ImageTextBlock(
                    id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
                    rect: Rect.fromLTWH(imgX, imgY, estimatedWidth, estimatedHeight),
                    text: text,
                    originalText: '',
                    fontSize: curFontSize,
                    textColor: curTextColor,
                    backgroundColor: curBgColor,
                    isCoverOriginal: isCover,
                    isManual: true,
                  );
                  setState(() {
                    _textBlocks.add(newBlock);
                    _selectedBlock = newBlock;
                  });
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Add Text'),
            ),
          ],
        ),
      ),
    );
  }

  // Golden Save Rule (§1.1): NEVER overwrite the original. Always write a new file.
  Future<void> _saveAsNewFile() async {
    setState(() => _isSaving = true);

    try {
      final originalBytes = await File(widget.file.path).readAsBytes();
      PdfDocument? doc;
      Uint8List finalPdfBytes;

      try {
        doc = PdfDocument(inputBytes: originalBytes);
        final page = doc.pages[_currentPage];
        final scaleX = _pdfPageWidth / _imageWidth;
        final scaleY = _pdfPageHeight / _imageHeight;

        for (final block in _textBlocks) {
          if (block.isModified || block.isManual) {
            final pdfRect = Rect.fromLTWH(
              block.rect.left * scaleX,
              block.rect.top * scaleY,
              block.rect.width * scaleX,
              block.rect.height * scaleY,
            );

            if (block.isCoverOriginal && block.backgroundColor != Colors.transparent) {
              final bgR = (block.backgroundColor.r * 255.0).round().clamp(0, 255);
              final bgG = (block.backgroundColor.g * 255.0).round().clamp(0, 255);
              final bgB = (block.backgroundColor.b * 255.0).round().clamp(0, 255);
              page.graphics.drawRectangle(
                brush: PdfSolidBrush(PdfColor(bgR, bgG, bgB)),
                bounds: pdfRect,
              );
            }

            if (block.text.trim().isNotEmpty) {
              final fontPt = (block.fontSize * scaleY).clamp(6.0, 72.0);
              final fgR = (block.textColor.r * 255.0).round().clamp(0, 255);
              final fgG = (block.textColor.g * 255.0).round().clamp(0, 255);
              final fgB = (block.textColor.b * 255.0).round().clamp(0, 255);
              page.graphics.drawString(
                block.text,
                PdfStandardFont(PdfFontFamily.helvetica, fontPt),
                brush: PdfSolidBrush(PdfColor(fgR, fgG, fgB)),
                bounds: pdfRect,
              );
            }
          }
        }
        finalPdfBytes = Uint8List.fromList(await doc.save());
      } finally {
        doc?.dispose();
      }

      // Safe filename generation: <name> (edited).pdf
      final originalFile = File(widget.file.path);
      final parentDir = originalFile.parent.path;
      final originalNameNoExt = widget.file.name.contains('.')
          ? widget.file.name.substring(0, widget.file.name.lastIndexOf('.'))
          : widget.file.name;

      String newFileName = '$originalNameNoExt (edited).pdf';
      String newFilePath = '$parentDir/$newFileName';
      int counter = 2;

      while (File(newFilePath).existsSync()) {
        newFileName = '$originalNameNoExt (edited) ($counter).pdf';
        newFilePath = '$parentDir/$newFileName';
        counter++;
      }

      await File(newFilePath).writeAsBytes(finalPdfBytes);

      // Register new file in detection and recents
      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final newEntity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: finalPdfBytes.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(newEntity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved as new PDF: $newFileName'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () {
              Navigator.of(context).pop();
              ViewerRouterScreen.open(context, newEntity);
            },
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save PDF: $e')),
      );
    }
  }

  void _showJumpToPageDialog() {
    final colors = context.colors;
    final controller = TextEditingController(text: '${_currentPage + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Jump to page', style: TextStyle(color: colors.textPrimary)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Page ', style: TextStyle(color: colors.textSecondary)),
            SizedBox(
              width: 60,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            Text(' of $_totalPages', style: TextStyle(color: colors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.of(ctx).pop();
                _loadPage(page - 1);
              }
            },
            child: const Text('Jump'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surfaceApp,
      appBar: AppBar(
        backgroundColor: colors.surfaceApp,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PDF Text Editor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.file.name,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Page navigation controls
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed: _currentPage > 0 ? () => _loadPage(_currentPage - 1) : null,
          ),
          TextButton(
            onPressed: _showJumpToPageDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${_currentPage + 1} / $_totalPages',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed: _currentPage < _totalPages - 1 ? () => _loadPage(_currentPage + 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find text on page',
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchController.clear();
                  _searchMatchIndices = [];
                  _currentSearchMatchIndex = -1;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy whole page text',
            onPressed: _copyWholePageText,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentPrimary,
                foregroundColor: colors.accentOnAccent,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 16),
              label: const Text('Save'),
              onPressed: _isSaving || _isLoading ? null : _saveAsNewFile,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearchActive)
            InViewerFindBar(
              controller: _searchController,
              matchCount: _searchMatchIndices.length,
              currentIndex: _currentSearchMatchIndex,
              onNext: () {
                if (_searchMatchIndices.isNotEmpty) {
                  setState(() {
                    _currentSearchMatchIndex =
                        (_currentSearchMatchIndex + 1) % _searchMatchIndices.length;
                    _selectedBlock = _textBlocks[_searchMatchIndices[_currentSearchMatchIndex]];
                  });
                }
              },
              onPrev: () {
                if (_searchMatchIndices.isNotEmpty) {
                  setState(() {
                    _currentSearchMatchIndex =
                        (_currentSearchMatchIndex - 1 + _searchMatchIndices.length) %
                            _searchMatchIndices.length;
                    _selectedBlock = _textBlocks[_searchMatchIndices[_currentSearchMatchIndex]];
                  });
                }
              },
              onClose: () {
                setState(() {
                  _isSearchActive = false;
                  _searchController.clear();
                  _searchMatchIndices = [];
                  _currentSearchMatchIndex = -1;
                });
              },
              onChanged: _performSearch,
            ),
          if (_isSearchActive && _searchMatchIndices.isNotEmpty && _currentSearchMatchIndex >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: colors.surfaceElevated,
              child: Row(
                children: [
                  Icon(Icons.find_in_page_outlined, size: 14, color: colors.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Match ${_currentSearchMatchIndex + 1} of ${_searchMatchIndices.length}: "${_textBlocks[_searchMatchIndices[_currentSearchMatchIndex]].text}"',
                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildCanvas(colors)),
          _buildBottomBar(colors),
        ],
      ),
    );
  }

  Widget _buildCanvas(OpenFileColors colors) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(colors.accentPrimary)),
            const SizedBox(height: 16),
            Text('Rasterizing PDF page & detecting text blocks...', style: TextStyle(color: colors.textSecondary)),
          ],
        ),
      );
    }

    if (_errorMessage != null || _renderedImagePath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.stateError),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Failed to render page', style: TextStyle(color: colors.textPrimary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadPage(_currentPage),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        if (_imageWidth <= 0 || _imageHeight <= 0) return const SizedBox.shrink();

        final scale = math.min(screenW / _imageWidth, screenH / _imageHeight);
        final renderW = _imageWidth * scale;
        final renderH = _imageHeight * scale;

        return InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 6.0,
          boundaryMargin: const EdgeInsets.all(40),
          child: Center(
            child: SizedBox(
              width: renderW,
              height: renderH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (_tapToAddTextMode) {
                    final imgX = details.localPosition.dx / scale;
                    final imgY = details.localPosition.dy / scale;
                    _addTextBlockDialog(imgX, imgY);
                  }
                },
                child: Stack(
                  children: [
                    // Rendered high-res PDF page image
                    Positioned.fill(
                      child: Image.file(
                        File(_renderedImagePath!),
                        fit: BoxFit.fill,
                      ),
                    ),
                    // Interactive text blocks & cover overlays
                    for (int i = 0; i < _textBlocks.length; i++)
                      _buildBlockOverlay(_textBlocks[i], i, scale, colors),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockOverlay(ImageTextBlock block, int index, double scale, OpenFileColors colors) {
    final left = block.rect.left * scale;
    final top = block.rect.top * scale;
    final width = math.max(16.0, block.rect.width * scale);
    final height = math.max(12.0, block.rect.height * scale);

    final isSelected = _selectedBlock == block;
    final isSearchMatch = _searchMatchIndices.contains(index);
    final isActiveSearchMatch = _searchMatchIndices.isNotEmpty &&
        _currentSearchMatchIndex >= 0 &&
        _searchMatchIndices[_currentSearchMatchIndex] == index;

    Color? overlayBg;
    Border? overlayBorder;

    if (isActiveSearchMatch) {
      overlayBg = Colors.yellow.withValues(alpha: 0.5);
      overlayBorder = Border.all(color: Colors.amber, width: 2.5);
    } else if (isSearchMatch) {
      overlayBg = Colors.yellow.withValues(alpha: 0.35);
      overlayBorder = Border.all(color: Colors.amber.withValues(alpha: 0.8), width: 1.5);
    } else if (block.isModified || block.isManual) {
      overlayBg = block.backgroundColor;
      overlayBorder = Border.all(color: colors.accentPrimary, width: 1.5);
    } else if (isSelected) {
      overlayBg = colors.accentPrimary.withValues(alpha: 0.2);
      overlayBorder = Border.all(color: colors.accentPrimary, width: 2.0);
    } else {
      // Unedited text line: subtle tap hint border
      overlayBorder = Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 0.7);
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _selectedBlock = block);
          _editTextBlockDialog(block);
        },
        child: Container(
          decoration: BoxDecoration(
            color: overlayBg,
            border: overlayBorder,
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: (block.isModified || block.isManual)
              ? Text(
                  block.text,
                  style: TextStyle(
                    color: block.textColor,
                    fontSize: (block.fontSize * scale).clamp(8.0, 72.0),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildBottomBar(OpenFileColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            FilterChip(
              avatar: Icon(
                _tapToAddTextMode ? Icons.touch_app : Icons.touch_app_outlined,
                size: 16,
                color: _tapToAddTextMode ? colors.accentOnAccent : colors.textPrimary,
              ),
              label: Text(_tapToAddTextMode ? 'Tap Spot Mode: Active' : 'Tap Spot to Add Text'),
              selected: _tapToAddTextMode,
              selectedColor: colors.accentPrimary,
              onSelected: (val) {
                setState(() => _tapToAddTextMode = val);
                if (val) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap anywhere on the PDF page to add a new text block'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const Spacer(),
            Text(
              '${_textBlocks.length} text blocks',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
