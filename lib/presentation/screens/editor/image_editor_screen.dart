import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../../core/services/ocr_service.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../core/utils/text_color_detector.dart';
import '../../../domain/entities/file_entity.dart';
import '../../../domain/entities/image_text_overlay_model.dart';
import '../../providers/detection_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/recents_provider.dart';
import '../../widgets/in_viewer_find_bar.dart';
import '../../widgets/ocr_result_sheet.dart';
import '../viewer/viewer_router_screen.dart';

enum _ImageEditorTab { adjust, crop, rotate, text }

class ImageEditorScreen extends ConsumerStatefulWidget {
  final FileEntity file;
  final bool startWithOcr;

  const ImageEditorScreen({
    super.key,
    required this.file,
    this.startWithOcr = true,
  });

  static void open(BuildContext context, FileEntity file, {bool startWithOcr = true}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImageEditorScreen(file: file, startWithOcr: startWithOcr)),
    );
  }

  @override
  ConsumerState<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends ConsumerState<ImageEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Uint8List? _originalBytes;
  img.Image? _decodedImage;

  _ImageEditorTab _activeTab = _ImageEditorTab.text;

  // Adjustments
  double _brightness = 0.0; // -1.0 to 1.0 (default 0.0)
  double _contrast = 1.0;   // 0.5 to 2.0 (default 1.0)
  double _saturation = 1.0; // 0.0 to 2.0 (default 1.0)

  // Rotate & Flip
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // Crop Aspect Ratio
  double? _cropAspectRatio; // null = free, 1.0 = 1:1, 4/3, 16/9

  // Text Overlay & OCR Text Blocks
  String _overlayText = '';
  Color _overlayColor = Colors.white;
  final Alignment _overlayAlignment = Alignment.bottomCenter;

  List<ImageTextBlock> _textBlocks = [];
  ImageTextBlock? _selectedBlock;
  bool _isOcrScanning = false;
  bool _tapToAddTextMode = false;

  // Search State
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchMatchIndices = [];
  int _currentSearchMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Image file not found on disk.';
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unsupported or corrupted image format.';
        });
        return;
      }

      setState(() {
        _originalBytes = bytes;
        _decodedImage = decoded;
        _isLoading = false;
      });

      // Auto-run OCR on load so text on page is immediately recognized without needing button clicks
      _runImageOcr();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load image: $e';
      });
    }
  }

  // Golden Save Rule (§1.1): NEVER overwrite the original. Always write a new file.
  Future<void> _saveAsNewFile() async {
    if (_decodedImage == null) return;

    setState(() => _isSaving = true);

    try {
      img.Image processed = img.Image.from(_decodedImage!);

      // 1. Rotate
      if (_rotationAngle != 0) {
        processed = img.copyRotate(processed, angle: _rotationAngle);
      }
      // 2. Flips
      if (_flipHorizontal) {
        processed = img.copyFlip(processed, direction: img.FlipDirection.horizontal);
      }
      if (_flipVertical) {
        processed = img.copyFlip(processed, direction: img.FlipDirection.vertical);
      }

      // 3. Crop
      if (_cropAspectRatio != null) {
        final curAspect = processed.width / processed.height;
        int targetW = processed.width;
        int targetH = processed.height;

        if (curAspect > _cropAspectRatio!) {
          targetW = (processed.height * _cropAspectRatio!).toInt();
        } else {
          targetH = (processed.width / _cropAspectRatio!).toInt();
        }

        final startX = math.max(0, (processed.width - targetW) ~/ 2);
        final startY = math.max(0, (processed.height - targetH) ~/ 2);

        processed = img.copyCrop(
          processed,
          x: startX,
          y: startY,
          width: math.min(targetW, processed.width - startX),
          height: math.min(targetH, processed.height - startY),
        );
      }

      // 4. Color Adjustments
      if (_brightness != 0.0 || _contrast != 1.0 || _saturation != 1.0) {
        processed = img.adjustColor(
          processed,
          brightness: 1.0 + _brightness,
          contrast: _contrast,
          saturation: _saturation,
        );
      }

      // 5. Draw text overlay and ImageTextBlocks using full-resolution TextPainter
      final basePng = Uint8List.fromList(img.encodePng(processed));
      final codec = await ui.instantiateImageCodec(basePng);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(uiImage, Offset.zero, Paint());

      // 5a. Draw watermark text if present
      if (_overlayText.trim().isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: _overlayText.trim(),
            style: TextStyle(
              color: _overlayColor,
              fontSize: (processed.height * 0.035).clamp(16.0, 72.0),
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: processed.width.toDouble() - 40);
        tp.paint(canvas, Offset(20, (processed.height - tp.height - 30).clamp(0, processed.height.toDouble())));
      }

      // 5b. Draw all modified or manual ImageTextBlocks
      for (final block in _textBlocks) {
        if (block.isModified || block.isManual) {
          if (block.isCoverOriginal || block.backgroundColor != Colors.transparent) {
            final bgPaint = Paint()..color = block.backgroundColor;
            canvas.drawRect(block.rect, bgPaint);
          }

          if (block.text.trim().isNotEmpty) {
            final tp = TextPainter(
              text: TextSpan(
                text: block.text,
                style: TextStyle(
                  color: block.textColor,
                  fontSize: block.fontSize,
                  fontFamily: block.fontFamily,
                  fontWeight: block.fontWeight,
                  fontStyle: block.fontStyle,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: math.max(20.0, block.rect.width));
            tp.paint(canvas, Offset(block.rect.left, block.rect.top));
          }
        }
      }

      final picture = recorder.endRecording();
      final renderedUi = await picture.toImage(processed.width, processed.height);
      final byteData = await renderedUi.toByteData(format: ui.ImageByteFormat.png);
      final finalPngBytes = byteData!.buffer.asUint8List();

      // 6. Encode to target format
      final ext = widget.file.extension.toLowerCase();
      Uint8List encodedBytes;
      String targetExt;

      if (ext == 'png') {
        encodedBytes = finalPngBytes;
        targetExt = 'png';
      } else {
        final reDecoded = img.decodePng(finalPngBytes);
        if (reDecoded != null) {
          encodedBytes = Uint8List.fromList(img.encodeJpg(reDecoded, quality: 92));
        } else {
          encodedBytes = finalPngBytes;
        }
        targetExt = 'jpg';
      }

      // 7. Find next available safe filename
      final originalFile = File(widget.file.path);
      final parentDir = originalFile.parent.path;
      final originalNameNoExt = widget.file.name.contains('.')
          ? widget.file.name.substring(0, widget.file.name.lastIndexOf('.'))
          : widget.file.name;

      String newFileName = '$originalNameNoExt (edited).$targetExt';
      String newFilePath = '$parentDir/$newFileName';
      int counter = 2;

      while (File(newFilePath).existsSync()) {
        newFileName = '$originalNameNoExt (edited) ($counter).$targetExt';
        newFilePath = '$parentDir/$newFileName';
        counter++;
      }

      // 8. Write new file to disk
      final newFile = File(newFilePath);
      await newFile.writeAsBytes(encodedBytes);

      // 9. Update state & recents
      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final newEntity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: encodedBytes.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(newEntity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved as new file: $newFileName'),
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
        SnackBar(content: Text('Could not save image: $e')),
      );
    }
  }

  Future<void> _runImageOcr() async {
    setState(() => _isOcrScanning = true);
    try {
      final recognized = await OcrService.instance.recognizeImageFileDetailed(widget.file.path);
      final newBlocks = <ImageTextBlock>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          if (box.width <= 0 || box.height <= 0 || line.text.trim().isEmpty) continue;
          final detectedColor = _decodedImage != null
              ? TextColorDetector.detectTextColor(_decodedImage!, box)
              : Colors.black;
          final estimatedFontSize = (box.height * 0.85).clamp(8.0, 140.0);

          newBlocks.add(ImageTextBlock(
            id: 'ocr_${line.hashCode}_${box.left.toInt()}_${box.top.toInt()}',
            rect: box,
            text: line.text,
            originalText: line.text,
            fontSize: estimatedFontSize,
            isCoverOriginal: false,
            isManual: false,
            textColor: detectedColor,
            backgroundColor: Colors.transparent,
          ));
        }
      }

      setState(() {
        _textBlocks = newBlocks;
        _isOcrScanning = false;
        _activeTab = _ImageEditorTab.text;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newBlocks.isNotEmpty
                  ? 'Recognized ${newBlocks.length} text blocks. Tap any text on the image to edit it, or tap an empty area to add text.'
                  : 'No text detected in this image.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOcrScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    }
  }

  void _copyWholePageText() async {
    if (_textBlocks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text blocks detected on this image')),
        );
      }
      return;
    }
    final allText = _textBlocks.map((b) => b.text).join('\n').trim();
    await Clipboard.setData(ClipboardData(text: allText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied all text on page (${_textBlocks.length} blocks, ${allText.length} chars) to clipboard'),
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
            block.isManual ? 'Edit Text Block' : 'Edit OCR Text (Cover & Replace)',
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
                Text('Font Size: ${curFontSize.toInt()} pt', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                Slider(
                  value: curFontSize.clamp(8.0, 72.0),
                  min: 8.0,
                  max: 72.0,
                  activeColor: colors.accentPrimary,
                  onChanged: (v) => setDialogState(() => curFontSize = v),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cover Original Text', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                    Switch(
                      value: isCover,
                      activeThumbColor: colors.accentPrimary,
                      onChanged: (v) => setDialogState(() => isCover = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Theme Style', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Black on White'),
                      selected: curTextColor == Colors.black && curBgColor == Colors.white,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = Colors.black;
                        curBgColor = Colors.white;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('White on Black'),
                      selected: curTextColor == Colors.white && curBgColor == Colors.black,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = Colors.white;
                        curBgColor = Colors.black;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Gray on Transparent'),
                      selected: curBgColor == Colors.transparent,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = const Color(0xFFCCCCCC);
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
                setState(() {
                  _textBlocks.removeWhere((b) => b.id == block.id);
                  if (_selectedBlock?.id == block.id) _selectedBlock = null;
                });
                Navigator.of(ctx).pop();
              },
              child: Text('Delete', style: TextStyle(color: colors.stateError)),
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
                final newText = controller.text.trim();
                setState(() {
                  block.text = newText;
                  block.fontSize = curFontSize;
                  block.textColor = curTextColor;
                  block.backgroundColor = curBgColor;
                  block.isCoverOriginal = isCover;
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

  void _addTextBlockAtCoordinates(double imgX, double imgY) {
    final colors = context.colors;
    final controller = TextEditingController();
    double curFontSize = 24.0;
    Color curTextColor = Colors.black;
    Color curBgColor = Colors.white;
    bool isCover = false;

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
                Text('Font Size: ${curFontSize.toInt()} pt', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                Slider(
                  value: curFontSize,
                  min: 10.0,
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
                      label: const Text('White (Transparent)'),
                      selected: curTextColor == Colors.white && curBgColor == Colors.transparent,
                      onSelected: (_) => setDialogState(() {
                        curTextColor = Colors.white;
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOcrOptions() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_note, color: colors.textPrimary),
              title: Text('Scan & Edit Text on Image', style: TextStyle(color: colors.textPrimary)),
              subtitle: Text('Detect text blocks and edit them directly on the canvas', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                _runImageOcr();
              },
            ),
            ListTile(
              leading: Icon(Icons.copy, color: colors.textPrimary),
              title: Text('Extract & Copy Text', style: TextStyle(color: colors.textPrimary)),
              subtitle: Text('View recognized text in bottom sheet to copy or export', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  final text = await OcrService.instance.recognizeImageFile(widget.file.path);
                  if (!mounted) return;
                  await OcrResultSheet.show(
                    context,
                    text: text,
                    sourceFileName: widget.file.name,
                    sourceFilePath: widget.file.path,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('OCR recognition failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTextOverlayDialog() {
    final colors = context.colors;
    final controller = TextEditingController(text: _overlayText);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Text Overlay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Overlay Text',
                  hintText: 'Enter caption or watermark',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Colors.white,
                  const Color(0xFFD4D4D4),
                  const Color(0xFF8E8E93),
                  const Color(0xFF3A3A3C),
                  Colors.black,
                ].map((c) {
                  final isSelected = _overlayColor == c;
                  return GestureDetector(
                    onTap: () => setDialogState(() => _overlayColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? colors.accentPrimary : Colors.grey,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _overlayText = controller.text);
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colors.surfaceApp,
        appBar: AppBar(title: Text('Edit ${widget.file.name}'), backgroundColor: colors.surfaceApp),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: colors.surfaceApp,
        appBar: AppBar(title: const Text('Image Editor'), backgroundColor: colors.surfaceApp),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_errorMessage!, style: TextStyle(color: colors.stateError)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: colors.surfaceElevated,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit ${widget.file.name}',
          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search text on page',
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
          IconButton(
            icon: _isOcrScanning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.document_scanner_outlined),
            tooltip: 'Extract text (OCR)',
            onPressed: _isOcrScanning ? null : _showOcrOptions,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'Save New'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _isSaving ? null : _saveAsNewFile,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colors.surfaceElevated,
              child: Row(
                children: [
                  Icon(Icons.find_in_page_outlined, size: 16, color: colors.accentPrimary),
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
          // Live Preview Canvas
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (_decodedImage == null) return const SizedBox.shrink();
                    final imgW = _decodedImage!.width.toDouble();
                    final imgH = _decodedImage!.height.toDouble();

                    final availW = constraints.maxWidth;
                    final availH = constraints.maxHeight;

                    final effectiveAspect = _cropAspectRatio ?? (imgW / imgH);
                    double renderW;
                    double renderH;
                    if (availW / availH > effectiveAspect) {
                      renderH = availH;
                      renderW = availH * effectiveAspect;
                    } else {
                      renderW = availW;
                      renderH = availW / effectiveAspect;
                    }

                    final scaleX = renderW / imgW;
                    final scaleY = renderH / imgH;

                    return ColorFiltered(
                      colorFilter: _buildColorFilter(),
                      child: Transform.rotate(
                        angle: _rotationAngle * (math.pi / 180),
                        child: Transform.flip(
                          flipX: _flipHorizontal,
                          flipY: _flipVertical,
                          child: SizedBox(
                            width: renderW,
                            height: renderH,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Base Image
                                Positioned.fill(
                                  child: Image.memory(
                                    _originalBytes!,
                                    width: renderW,
                                    height: renderH,
                                    fit: _cropAspectRatio != null ? BoxFit.cover : BoxFit.contain,
                                  ),
                                ),

                                // Background Canvas Tap Handler (for adding text blocks on tap)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapUp: (details) {
                                      if (_activeTab == _ImageEditorTab.text || _tapToAddTextMode) {
                                        final touchPos = details.localPosition;
                                        final imgX = touchPos.dx / scaleX;
                                        final imgY = touchPos.dy / scaleY;

                                        // If clicked inside an existing text block, edit that block
                                        for (final b in _textBlocks.reversed) {
                                          final bRect = Rect.fromLTWH(
                                            b.rect.left * scaleX,
                                            b.rect.top * scaleY,
                                            math.max(b.rect.width * scaleX, 24.0),
                                            math.max(b.rect.height * scaleY, 16.0),
                                          );
                                          if (bRect.contains(touchPos)) {
                                            setState(() => _selectedBlock = b);
                                            _editTextBlockDialog(b);
                                            return;
                                          }
                                        }

                                        // Otherwise, add a new block at this exact tapped spot
                                        _addTextBlockAtCoordinates(imgX, imgY);
                                      }
                                    },
                                  ),
                                ),

                                // Interactive Text Blocks (OCR & Manual)
                                if (_cropAspectRatio == null)
                                  ..._textBlocks.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final block = entry.value;
                                    final screenLeft = block.rect.left * scaleX;
                                    final screenTop = block.rect.top * scaleY;
                                    final screenWidth = math.max(block.rect.width * scaleX, 24.0);
                                    final isSelected = _selectedBlock?.id == block.id;
                                    final isSearchMatch = _searchMatchIndices.contains(idx);
                                    final isActiveSearchMatch = _searchMatchIndices.isNotEmpty &&
                                        _currentSearchMatchIndex >= 0 &&
                                        _searchMatchIndices[_currentSearchMatchIndex] == idx;

                                    Color borderColor = isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.8);
                                    double borderWidth = isSelected ? 1.5 : 1.0;
                                    if (isActiveSearchMatch) {
                                      borderColor = Colors.white;
                                      borderWidth = 2.5;
                                    } else if (isSearchMatch) {
                                      borderColor = Colors.white70;
                                      borderWidth = 1.8;
                                    }

                                     return Positioned(
                                       left: screenLeft,
                                       top: screenTop,
                                       width: screenWidth,
                                       child: GestureDetector(
                                         behavior: HitTestBehavior.opaque,
                                         onTap: () {
                                           setState(() => _selectedBlock = block);
                                         },
                                         onPanUpdate: isSelected
                                             ? (details) {
                                                 setState(() {
                                                   block.rect = block.rect.shift(Offset(
                                                     details.delta.dx / scaleX,
                                                     details.delta.dy / scaleY,
                                                   ));
                                                 });
                                               }
                                             : null,
                                         child: Stack(
                                           clipBehavior: Clip.none,
                                           children: [
                                             Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 2),
                                               decoration: BoxDecoration(
                                                 color: isActiveSearchMatch
                                                     ? Colors.black
                                                     : (block.isModified || block.isManual)
                                                         ? block.backgroundColor
                                                         : Colors.transparent,
                                                 border: Border.all(
                                                   color: borderColor,
                                                   width: borderWidth,
                                                 ),
                                               ),
                                               child: (block.isModified || block.isManual || isSearchMatch)
                                                   ? Text(
                                                       block.text,
                                                       style: TextStyle(
                                                         color: isActiveSearchMatch ? Colors.white : block.textColor,
                                                         fontSize: (block.fontSize * scaleY).clamp(8.0, 100.0),
                                                         fontFamily: block.fontFamily,
                                                         fontWeight: block.fontWeight,
                                                         fontStyle: block.fontStyle,
                                                         height: 1.1,
                                                       ),
                                                       softWrap: true,
                                                       overflow: TextOverflow.visible,
                                                     )
                                                   : SizedBox(
                                                       height: math.max(16.0, block.rect.height * scaleY),
                                                     ),
                                             ),
                                             // Corner Resize Handle (bottom-right)
                                             if (isSelected)
                                               Positioned(
                                                 right: -10,
                                                 bottom: -10,
                                                 child: GestureDetector(
                                                   behavior: HitTestBehavior.opaque,
                                                   onPanUpdate: (details) {
                                                     setState(() {
                                                       final newW = math.max(30.0, block.rect.width + details.delta.dx / scaleX);
                                                       final newH = math.max(16.0, block.rect.height + details.delta.dy / scaleY);
                                                       block.rect = Rect.fromLTWH(
                                                         block.rect.left,
                                                         block.rect.top,
                                                         newW,
                                                         newH,
                                                       );
                                                       if (details.delta.dy.abs() > 0.5) {
                                                         block.fontSize = (newH * 0.85).clamp(8.0, 140.0);
                                                       }
                                                     });
                                                   },
                                                   child: Container(
                                                     width: 22,
                                                     height: 22,
                                                     decoration: BoxDecoration(
                                                       color: Colors.white,
                                                       shape: BoxShape.circle,
                                                       border: Border.all(color: Colors.black, width: 2),
                                                       boxShadow: [
                                                         BoxShadow(
                                                           color: Colors.black.withValues(alpha: 0.3),
                                                           blurRadius: 4,
                                                         ),
                                                       ],
                                                     ),
                                                     child: const Icon(Icons.crop_free, size: 12, color: Colors.black),
                                                   ),
                                                 ),
                                               ),
                                           ],
                                         ),
                                       ),
                                     );
                                   }),

                                // Optional Watermark Text
                                if (_overlayText.isNotEmpty)
                                  Align(
                                    alignment: _overlayAlignment,
                                    child: Container(
                                      margin: const EdgeInsets.all(16),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _overlayText,
                                        style: TextStyle(
                                          color: _overlayColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                // OCR Loading Overlay
                                if (_isOcrScanning)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: Colors.white),
                                            SizedBox(height: 12),
                                            Text(
                                              'Recognizing text on image...',
                                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Editor Control Panel
          Container(
            color: colors.surfaceElevated,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sub-panel controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: _buildSubControls(colors),
                  ),
                  const Divider(height: 1),
                  // Tool tabs bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ToolTabButton(
                        icon: Icons.tune_rounded,
                        label: 'Adjust',
                        isSelected: _activeTab == _ImageEditorTab.adjust,
                        onTap: () => setState(() => _activeTab = _ImageEditorTab.adjust),
                      ),
                      _ToolTabButton(
                        icon: Icons.crop_rounded,
                        label: 'Crop',
                        isSelected: _activeTab == _ImageEditorTab.crop,
                        onTap: () => setState(() => _activeTab = _ImageEditorTab.crop),
                      ),
                      _ToolTabButton(
                        icon: Icons.rotate_right_rounded,
                        label: 'Rotate',
                        isSelected: _activeTab == _ImageEditorTab.rotate,
                        onTap: () => setState(() => _activeTab = _ImageEditorTab.rotate),
                      ),
                      _ToolTabButton(
                        icon: Icons.text_fields_rounded,
                        label: 'Text',
                        isSelected: _activeTab == _ImageEditorTab.text,
                        onTap: () => setState(() => _activeTab = _ImageEditorTab.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubControls(OpenFileColors colors) {
    switch (_activeTab) {
      case _ImageEditorTab.adjust:
        return Column(
          children: [
            _SliderRow(
              icon: Icons.brightness_6_rounded,
              label: 'Brightness',
              value: _brightness,
              min: -0.5,
              max: 0.5,
              onChanged: (val) => setState(() => _brightness = val),
            ),
            _SliderRow(
              icon: Icons.contrast_rounded,
              label: 'Contrast',
              value: _contrast,
              min: 0.5,
              max: 1.8,
              onChanged: (val) => setState(() => _contrast = val),
            ),
            _SliderRow(
              icon: Icons.palette_outlined,
              label: 'Saturation',
              value: _saturation,
              min: 0.0,
              max: 2.0,
              onChanged: (val) => setState(() => _saturation = val),
            ),
          ],
        );
      case _ImageEditorTab.crop:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _CropChip(
                label: 'Original',
                isSelected: _cropAspectRatio == null,
                onSelected: () => setState(() => _cropAspectRatio = null),
              ),
              _CropChip(
                label: '1:1 Square',
                isSelected: _cropAspectRatio == 1.0,
                onSelected: () => setState(() => _cropAspectRatio = 1.0),
              ),
              _CropChip(
                label: '4:3',
                isSelected: _cropAspectRatio == 4 / 3,
                onSelected: () => setState(() => _cropAspectRatio = 4 / 3),
              ),
              _CropChip(
                label: '16:9',
                isSelected: _cropAspectRatio == 16 / 9,
                onSelected: () => setState(() => _cropAspectRatio = 16 / 9),
              ),
            ],
          ),
        );
      case _ImageEditorTab.rotate:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.rotate_left_rounded),
              tooltip: 'Rotate Left',
              onPressed: () => setState(() => _rotationAngle = (_rotationAngle - 90) % 360),
            ),
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded),
              tooltip: 'Rotate Right',
              onPressed: () => setState(() => _rotationAngle = (_rotationAngle + 90) % 360),
            ),
            IconButton(
              icon: const Icon(Icons.flip_rounded),
              tooltip: 'Flip Horizontal',
              onPressed: () => setState(() => _flipHorizontal = !_flipHorizontal),
            ),
            IconButton(
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: 'Flip Vertical',
              onPressed: () => setState(() => _flipVertical = !_flipVertical),
            ),
          ],
        );
      case _ImageEditorTab.text:
        if (_selectedBlock != null) {
          return _buildSelectedBlockControlBar(colors);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _isOcrScanning
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.document_scanner_outlined, size: 16),
                    label: Text(_isOcrScanning ? 'Scanning...' : 'OCR Scan & Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.divider),
                    ),
                    onPressed: _isOcrScanning ? null : _runImageOcr,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(_tapToAddTextMode ? Icons.touch_app : Icons.add_comment_outlined, size: 16),
                    label: Text(_tapToAddTextMode ? 'Tap Spot (Active)' : 'Tap Spot to Add'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _tapToAddTextMode ? colors.accentOnAccent : colors.textPrimary,
                      backgroundColor: _tapToAddTextMode ? colors.accentPrimary : null,
                      side: BorderSide(color: colors.divider),
                    ),
                    onPressed: () {
                      setState(() => _tapToAddTextMode = !_tapToAddTextMode);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _textBlocks.isNotEmpty
                      ? '${_textBlocks.length} text blocks on image'
                      : (_tapToAddTextMode ? 'Tap anywhere on the image to place text' : 'Tap text to edit, or tap OCR to detect'),
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
                if (_textBlocks.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _textBlocks.clear()),
                    child: Text('Clear All', style: TextStyle(color: colors.stateError, fontSize: 11)),
                  )
                else
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 20),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _showTextOverlayDialog,
                    child: Text(_overlayText.isNotEmpty ? 'Watermark: Edit' : '+ Watermark', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                  ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildSelectedBlockControlBar(OpenFileColors colors) {
    final block = _selectedBlock!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Font size slider + value label + color circle
        Row(
          children: [
            Icon(Icons.format_size, size: 18, color: colors.textPrimary),
            const SizedBox(width: 8),
            Text(
              '${block.fontSize.toInt()} pt',
              style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Slider(
                value: block.fontSize.clamp(8.0, 120.0),
                min: 8.0,
                max: 120.0,
                activeColor: colors.accentPrimary,
                onChanged: (v) {
                  setState(() {
                    block.fontSize = v;
                  });
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                final palette = [
                  Colors.black,
                  Colors.white,
                  const Color(0xFFE53935), // Red
                  const Color(0xFF1E88E5), // Blue
                  const Color(0xFF43A047), // Green
                  const Color(0xFFFFB300), // Amber
                  const Color(0xFF757575), // Gray
                ];
                final curIdx = palette.indexWhere((c) => c.toARGB32() == block.textColor.toARGB32());
                final nextIdx = (curIdx + 1) % palette.length;
                setState(() {
                  block.textColor = palette[nextIdx];
                });
              },
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: block.textColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.divider, width: 2),
                ),
              ),
            ),
          ],
        ),
        // Row 2: Actions: Edit text, Font Family, Bold, Cover Background, Delete, Done
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceElevated,
                  foregroundColor: colors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit Text', style: TextStyle(fontSize: 12)),
                onPressed: () => _editTextBlockDialog(block),
              ),
              const SizedBox(width: 8),
              // Font Family toggle
              ActionChip(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                label: Text(block.fontFamily ?? 'Sans', style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    if (block.fontFamily == null || block.fontFamily == 'sans-serif') {
                      block.fontFamily = 'serif';
                    } else if (block.fontFamily == 'serif') {
                      block.fontFamily = 'monospace';
                    } else {
                      block.fontFamily = 'sans-serif';
                    }
                  });
                },
              ),
              const SizedBox(width: 6),
              // Bold toggle
              FilterChip(
                padding: EdgeInsets.zero,
                label: const Text('B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                selected: block.fontWeight == FontWeight.bold,
                onSelected: (val) {
                  setState(() {
                    block.fontWeight = val ? FontWeight.bold : FontWeight.normal;
                  });
                },
              ),
              const SizedBox(width: 6),
              // Background Cover Toggle
              ActionChip(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                avatar: Icon(
                  block.isCoverOriginal ? Icons.layers : Icons.layers_clear,
                  size: 14,
                  color: block.isCoverOriginal ? colors.accentPrimary : colors.textSecondary,
                ),
                label: Text(block.isCoverOriginal ? 'Cover ON' : 'Transparent', style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    block.isCoverOriginal = !block.isCoverOriginal;
                    block.backgroundColor = block.isCoverOriginal ? Colors.white : Colors.transparent;
                  });
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.stateError, size: 20),
                tooltip: 'Delete text block',
                onPressed: () {
                  setState(() {
                    _textBlocks.removeWhere((b) => b.id == block.id);
                    _selectedBlock = null;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.check_circle_outline, color: colors.accentPrimary, size: 20),
                tooltip: 'Done',
                onPressed: () => setState(() => _selectedBlock = null),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ColorFilter _buildColorFilter() {
    final b = _brightness * 255;
    final c = _contrast;
    final s = _saturation;

    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;

    final sr = (1 - s) * lr;
    final sg = (1 - s) * lg;
    final sb = (1 - s) * lb;

    return ColorFilter.matrix([
      (sr + s) * c, sg * c, sb * c, 0, b,
      sr * c, (sg + s) * c, sb * c, 0, b,
      sr * c, sg * c, (sb + s) * c, 0, b,
      0, 0, 0, 1, 0,
    ]);
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 75,
          child: Text(label, style: TextStyle(color: colors.textPrimary, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: colors.accentPrimary,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _CropChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _CropChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: colors.accentPrimary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? colors.accentPrimary : colors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _ToolTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? colors.accentPrimary : colors.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.accentPrimary : colors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
