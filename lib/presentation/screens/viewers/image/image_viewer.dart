import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../../domain/entities/image_text_overlay_model.dart';
import '../../../widgets/in_viewer_find_bar.dart';
import '../../../widgets/o_bottom_sheet.dart';
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

  // Auto-OCR State
  List<ImageTextBlock> _ocrBlocks = [];
  String _pageOcrText = '';
  bool _isAutoOcrRunning = false;

  // Search State
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchMatchIndices = [];
  int _currentSearchMatchIndex = -1;

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
    _searchController.dispose();
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
        // Auto-run OCR on load in background so text is immediately recognized
        _autoRunOcr();
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

  Future<void> _autoRunOcr() async {
    if (_isAutoOcrRunning) return;
    _isAutoOcrRunning = true;
    try {
      final recognized = await OcrService.instance.recognizeImageFileDetailed(widget.file.path);
      final blocks = <ImageTextBlock>[];
      final buffer = StringBuffer();
      for (final b in recognized.blocks) {
        for (final line in b.lines) {
          final box = line.boundingBox;
          if (box.width <= 0 || box.height <= 0 || line.text.trim().isEmpty) continue;
          final estimatedFontSize = (box.height * 0.82).clamp(10.0, 120.0);
          blocks.add(ImageTextBlock(
            id: 'ocr_${line.hashCode}_${box.left.toInt()}_${box.top.toInt()}',
            rect: box,
            text: line.text,
            fontSize: estimatedFontSize,
            isCoverOriginal: false,
            isManual: false,
          ));
          buffer.writeln(line.text);
        }
      }
      if (mounted) {
        setState(() {
          _ocrBlocks = blocks;
          _pageOcrText = buffer.toString().trim();
          _isAutoOcrRunning = false;
        });
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAutoOcrRunning = false);
      }
    }
  }

  void _copyWholePage() async {
    String textToCopy = _pageOcrText;
    if (textToCopy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recognizing text on page...'), duration: Duration(seconds: 1)),
      );
      try {
        textToCopy = await OcrService.instance.recognizeImageFile(widget.file.path);
        _pageOcrText = textToCopy;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not extract text: $e')),
          );
        }
        return;
      }
    }

    if (textToCopy.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied whole page text (${textToCopy.length} chars) to clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text detected on this page')),
        );
      }
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
    for (int i = 0; i < _ocrBlocks.length; i++) {
      if (_ocrBlocks[i].text.toLowerCase().contains(lower)) {
        matches.add(i);
      }
    }

    setState(() {
      _searchMatchIndices = matches;
      _currentSearchMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
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
        icon: const Icon(Icons.search),
        tooltip: 'Find text on image',
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
        onPressed: _copyWholePage,
      ),
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit text on image',
        onPressed: () => ImageEditorScreen.open(context, widget.file, startWithOcr: true),
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
      child: Column(
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
                  });
                }
              },
              onPrev: () {
                if (_searchMatchIndices.isNotEmpty) {
                  setState(() {
                    _currentSearchMatchIndex =
                        (_currentSearchMatchIndex - 1 + _searchMatchIndices.length) %
                            _searchMatchIndices.length;
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
                      'Match ${_currentSearchMatchIndex + 1} of ${_searchMatchIndices.length}: "${_ocrBlocks[_searchMatchIndices[_currentSearchMatchIndex]].text}"',
                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
