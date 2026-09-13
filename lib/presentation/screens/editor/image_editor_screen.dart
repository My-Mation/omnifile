import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../../../core/services/ocr_service.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../domain/entities/file_entity.dart';
import '../../../domain/entities/image_text_overlay_model.dart';
import '../../providers/detection_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/recents_provider.dart';
import '../../widgets/ocr_result_sheet.dart';
import '../viewer/viewer_router_screen.dart';

enum _ImageEditorTab { adjust, crop, rotate, text }

class ImageEditorScreen extends ConsumerStatefulWidget {
  final FileEntity file;
  final bool startWithOcr;

  const ImageEditorScreen({
    super.key,
    required this.file,
    this.startWithOcr = false,
  });

  static void open(BuildContext context, FileEntity file, {bool startWithOcr = false}) {
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

  _ImageEditorTab _activeTab = _ImageEditorTab.adjust;

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

  @override
  void initState() {
    super.initState();
    _loadImage();
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

      if (widget.startWithOcr) {
        _runImageOcr();
      }
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

      // 5. Draw text overlay if present
      if (_overlayText.trim().isNotEmpty) {
        final argb = _overlayColor.toARGB32();
        final textR = (argb >> 16) & 0xFF;
        final textG = (argb >> 8) & 0xFF;
        final textB = argb & 0xFF;
        img.drawString(
          processed,
          _overlayText.trim(),
          font: img.arial24,
          x: 20,
          y: math.max(10, processed.height - 50),
          color: img.ColorRgb8(textR, textG, textB),
        );
      }

      // 5b. Draw all ImageTextBlocks (OCR replacements & manual text blocks)
      for (final block in _textBlocks) {
        if (block.text.trim().isEmpty) continue;

        final x1 = block.rect.left.toInt().clamp(0, processed.width - 1);
        final y1 = block.rect.top.toInt().clamp(0, processed.height - 1);
        final x2 = block.rect.right.toInt().clamp(0, processed.width - 1);
        final y2 = block.rect.bottom.toInt().clamp(0, processed.height - 1);

        if (block.isCoverOriginal) {
          final bgArgb = block.backgroundColor.toARGB32();
          final bgR = (bgArgb >> 16) & 0xFF;
          final bgG = (bgArgb >> 8) & 0xFF;
          final bgB = bgArgb & 0xFF;
          img.fillRect(
            processed,
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            color: img.ColorRgb8(bgR, bgG, bgB),
          );
        }

        final fgArgb = block.textColor.toARGB32();
        final textR = (fgArgb >> 16) & 0xFF;
        final textG = (fgArgb >> 8) & 0xFF;
        final textB = fgArgb & 0xFF;
        final font = block.fontSize < 18
            ? img.arial14
            : (block.fontSize > 36 ? img.arial48 : img.arial24);

        img.drawString(
          processed,
          block.text,
          font: font,
          x: x1,
          y: y1,
          color: img.ColorRgb8(textR, textG, textB),
        );
      }

      // 6. Encode
      final ext = widget.file.extension.toLowerCase();
      Uint8List encodedBytes;
      String targetExt;

      if (ext == 'png') {
        encodedBytes = Uint8List.fromList(img.encodePng(processed));
        targetExt = 'png';
      } else {
        encodedBytes = Uint8List.fromList(img.encodeJpg(processed, quality: 92));
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
          final estimatedFontSize = (box.height * 0.82).clamp(10.0, 120.0);
          newBlocks.add(ImageTextBlock(
            id: 'ocr_${line.hashCode}_${box.left.toInt()}_${box.top.toInt()}',
            rect: box,
            text: line.text,
            fontSize: estimatedFontSize,
            isCoverOriginal: true,
            isManual: false,
            textColor: Colors.black,
            backgroundColor: Colors.white,
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
                                  ..._textBlocks.map((block) {
                                    final screenLeft = block.rect.left * scaleX;
                                    final screenTop = block.rect.top * scaleY;
                                    final screenWidth = math.max(block.rect.width * scaleX, 24.0);
                                    final isSelected = _selectedBlock?.id == block.id;

                                    return Positioned(
                                      left: screenLeft,
                                      top: screenTop,
                                      width: screenWidth,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          setState(() => _selectedBlock = block);
                                          _editTextBlockDialog(block);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: block.isCoverOriginal ? block.backgroundColor : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.8),
                                              width: isSelected ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Text(
                                            block.text,
                                            style: TextStyle(
                                              color: block.textColor,
                                              fontSize: (block.fontSize * scaleY).clamp(8.0, 72.0),
                                              fontWeight: FontWeight.w600,
                                              height: 1.1,
                                            ),
                                          ),
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
