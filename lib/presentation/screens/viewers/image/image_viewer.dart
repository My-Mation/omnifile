import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../widgets/o_bottom_sheet.dart';
import '../../../widgets/ocr_result_sheet.dart';
import '../../../widgets/viewer_shell.dart';
import '../../editor/image_editor_screen.dart';

class ImageViewer extends ConsumerStatefulWidget {
  final FileEntity file;

  const ImageViewer({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  int _rotationQuarterTurns = 0;
  bool _isLoading = true;
  String? _errorMessage;
  int? _imageWidth;
  int? _imageHeight;
  bool _isGif = false;
  bool _isGifPlaying = true;
  bool _isOcrRunning = false;

  Future<void> _runOcr() async {
    setState(() => _isOcrRunning = true);
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
    } finally {
      if (mounted) {
        setState(() => _isOcrRunning = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final ext = widget.file.extension.toLowerCase();
    _isGif = ext == 'gif' || ext == 'webp';
    _loadImageMetadata();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadImageMetadata() async {
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
      final descriptor = await ui.ImageDescriptor.encoded(await ui.ImmutableBuffer.fromUint8List(bytes));
      if (mounted) {
        setState(() {
          _imageWidth = descriptor.width;
          _imageHeight = descriptor.height;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to decode image ($e).';
        });
      }
    }
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final x = -position.dx * (2.5 - 1.0);
      final y = -position.dy * (2.5 - 1.0);
      final zoomed = Matrix4.identity()
        ..storage[0] = 2.5
        ..storage[5] = 2.5
        ..storage[12] = x
        ..storage[13] = y;
      _transformController.value = zoomed;
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _showImageDetails() {
    final colors = context.colors;
    OBottomSheet.show(
      context: context,
      title: 'Image details',
      customContent: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('Filename', widget.file.name, colors),
          if (_imageWidth != null && _imageHeight != null) ...[
            _detailRow('Dimensions', '$_imageWidth × $_imageHeight px', colors),
            _detailRow('Aspect ratio', '${(_imageWidth! / _imageHeight!).toStringAsFixed(2)}:1', colors),
          ],
          _detailRow('File size', Formatters.formatFileSize(widget.file.size), colors),
          _detailRow('Format', widget.file.extension.toUpperCase(), colors),
          _detailRow('Modified', Formatters.formatDate(widget.file.lastModified), colors),
          _detailRow('Path', widget.file.path, colors, isPath: true),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, OpenFileColors colors, {bool isPath = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $label'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: isPath ? 3 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final customActions = <Widget>[
      IconButton(
        icon: _isOcrRunning
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.document_scanner_outlined),
        tooltip: 'Recognize text (OCR)',
        onPressed: _isOcrRunning ? null : _runOcr,
      ),
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit Image',
        onPressed: () => ImageEditorScreen.open(context, widget.file),
      ),
      IconButton(
        icon: const Icon(Icons.rotate_right),
        tooltip: 'Rotate 90°',
        onPressed: _rotateClockwise,
      ),
      if (_isGif)
        IconButton(
          icon: Icon(_isGifPlaying ? Icons.pause : Icons.play_arrow),
          tooltip: _isGifPlaying ? 'Pause animation' : 'Play animation',
          onPressed: () {
            setState(() {
              _isGifPlaying = !_isGifPlaying;
            });
          },
        ),
      IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: 'Image details',
        onPressed: _showImageDetails,
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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 56, color: colors.stateError),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textPrimary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } else {
      Widget img = Image.file(
        File(widget.file.path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 48, color: colors.stateError),
                const SizedBox(height: 12),
                Text('Failed to render image', style: TextStyle(color: colors.textPrimary)),
              ],
            ),
          );
        },
      );

      if (_rotationQuarterTurns > 0) {
        img = RotatedBox(quarterTurns: _rotationQuarterTurns, child: img);
      }

      body = GestureDetector(
        onDoubleTapDown: (d) => _doubleTapDetails = d,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 8.0,
          boundaryMargin: const EdgeInsets.all(40),
          child: Center(child: img),
        ),
      );
    }

    return ViewerShell(
      file: widget.file,
      customActions: customActions,
      child: body,
    );
  }
}
