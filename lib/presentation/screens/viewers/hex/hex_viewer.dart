import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../widgets/viewer_shell.dart';

class HexViewer extends ConsumerStatefulWidget {
  final FileEntity file;

  const HexViewer({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<HexViewer> createState() => _HexViewerState();
}

class _HexViewerState extends ConsumerState<HexViewer> {
  RandomAccessFile? _raf;
  int _fileLength = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // 64KB Chunk caching
  static const int _chunkSize = 64 * 1024;
  int _cachedChunkIndex = -1;
  Uint8List? _cachedChunkData;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _openFile();
  }

  Future<void> _openFile() async {
    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'File does not exist.';
        });
        return;
      }

      _raf = await file.open(mode: FileMode.read);
      _fileLength = await _raf!.length();

      // Read initial chunk
      await _loadChunk(0);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to open file: $e';
        });
      }
    }
  }

  Future<void> _loadChunk(int chunkIndex) async {
    if (_raf == null || chunkIndex == _cachedChunkIndex) return;
    final offset = chunkIndex * _chunkSize;
    if (offset >= _fileLength) return;

    await _raf!.setPosition(offset);
    final toRead = math.min(_chunkSize, _fileLength - offset);
    _cachedChunkData = await _raf!.read(toRead);
    _cachedChunkIndex = chunkIndex;
  }

  @override
  void dispose() {
    _raf?.close();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _totalRows => (_fileLength + 15) ~/ 16;

  void _showJumpToOffsetDialog() {
    final colors = context.colors;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Jump to Offset', style: TextStyle(color: colors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 0x1A0 or 416',
            hintStyle: TextStyle(color: colors.textDisabled),
            filled: true,
            fillColor: colors.surfaceInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
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
              final text = controller.text.trim();
              int? offset;
              if (text.startsWith('0x') || text.startsWith('0X')) {
                offset = int.tryParse(text.substring(2), radix: 16);
              } else {
                offset = int.tryParse(text);
              }

              if (offset != null && offset >= 0 && offset < _fileLength) {
                final row = offset ~/ 16;
                const rowHeight = 26.0;
                final target = row * rowHeight;
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(target.clamp(0.0, _scrollController.position.maxScrollExtent));
                }
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Jump'),
          ),
        ],
      ),
    );
  }

  String _formatOffset(int offset) {
    return offset.toRadixString(16).padLeft(8, '0').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final customActions = <Widget>[
      IconButton(
        icon: const Icon(Icons.gps_fixed),
        tooltip: 'Jump to offset',
        onPressed: _showJumpToOffsetDialog,
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
    } else if (_fileLength == 0) {
      body = Center(child: Text('Empty file (0 bytes)', style: TextStyle(color: colors.textSecondary)));
    } else {
      body = Column(
        children: [
          // Header Ruler
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceApp,
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text('OFFSET', style: TextStyle(color: colors.textDisabled, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F',
                    style: TextStyle(color: colors.textDisabled, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text('ASCII', style: TextStyle(color: colors.textDisabled, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Virtualized byte rows
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _totalRows,
              itemExtent: 26.0,
              itemBuilder: (context, index) {
                final rowOffset = index * 16;
                final chunkIdx = rowOffset ~/ _chunkSize;
                final chunkOffset = rowOffset % _chunkSize;

                // Sync read from cached chunk if available
                Uint8List? data = (chunkIdx == _cachedChunkIndex) ? _cachedChunkData : null;
                if (data == null) {
                  // Trigger chunk read
                  _loadChunk(chunkIdx).then((_) {
                    if (mounted) setState(() {});
                  });
                }

                final hexParts = <String>[];
                final asciiChars = StringBuffer();

                for (int b = 0; b < 16; b++) {
                  final bytePos = rowOffset + b;
                  if (bytePos < _fileLength && data != null && (chunkOffset + b) < data.length) {
                    final val = data[chunkOffset + b];
                    hexParts.add(val.toRadixString(16).padLeft(2, '0').toUpperCase());
                    if (val >= 32 && val <= 126) {
                      asciiChars.write(String.fromCharCode(val));
                    } else {
                      asciiChars.write('·');
                    }
                  } else if (bytePos < _fileLength) {
                    hexParts.add('..');
                    asciiChars.write('.');
                  } else {
                    hexParts.add('  ');
                    asciiChars.write(' ');
                  }
                }

                // Group 8 bytes with extra space
                final hexStr = '${hexParts.sublist(0, 8).join(' ')}  ${hexParts.sublist(8).join(' ')}';

                final isEven = index % 2 == 0;
                return Container(
                  color: isEven ? colors.surfaceRoot : colors.surfaceCard.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          _formatOffset(rowOffset),
                          style: TextStyle(color: colors.accentPrimary, fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          hexStr,
                          style: TextStyle(color: colors.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          asciiChars.toString(),
                          style: TextStyle(color: colors.textSecondary, fontSize: 12, fontFamily: 'monospace'),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return ViewerShell(
      file: widget.file,
      customActions: customActions,
      child: body,
    );
  }
}
