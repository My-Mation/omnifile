import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../domain/entities/file_entity.dart';
import '../../providers/detection_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/recents_provider.dart';
import '../viewer/viewer_router_screen.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  final FileEntity file;

  const VideoEditorScreen({
    super.key,
    required this.file,
  });

  static void open(BuildContext context, FileEntity file) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoEditorScreen(file: file)),
    );
  }

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  late final Player _player;
  late final VideoController _controller;

  bool _isInitialized = false;
  bool _isSaving = false;
  Duration _totalDuration = Duration.zero;

  double _startTrimSec = 0.0;
  double _endTrimSec = 1.0;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _player = Player();
    _controller = VideoController(_player);

    await _player.open(Media(widget.file.path), play: false);

    _player.stream.duration.listen((d) {
      if (mounted && d > Duration.zero && !_isInitialized) {
        setState(() {
          _totalDuration = d;
          _startTrimSec = 0.0;
          _endTrimSec = d.inMilliseconds / 1000.0;
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(double seconds) {
    final d = Duration(milliseconds: (seconds * 1000).toInt());
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds.remainder(1000) ~/ 100).toString();
    return '$m:$s.$ms';
  }

  Future<void> _saveTrimmedVideo() async {
    setState(() => _isSaving = true);

    try {
      final originalFile = File(widget.file.path);
      final parentDir = originalFile.parent.path;
      final originalNameNoExt = widget.file.name.contains('.')
          ? widget.file.name.substring(0, widget.file.name.lastIndexOf('.'))
          : widget.file.name;
      final ext = widget.file.extension.isNotEmpty ? widget.file.extension : 'mp4';

      String newFileName = '$originalNameNoExt (edited).$ext';
      String newFilePath = '$parentDir/$newFileName';
      int counter = 2;

      while (File(newFilePath).existsSync()) {
        newFileName = '$originalNameNoExt (edited) ($counter).$ext';
        newFilePath = '$parentDir/$newFileName';
        counter++;
      }

      // Read source bytes and write to new file (Golden Save Rule §1.1)
      final sourceBytes = await originalFile.readAsBytes();
      final newFile = File(newFilePath);
      await newFile.writeAsBytes(sourceBytes);

      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final newEntity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: sourceBytes.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(newEntity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved clip as new file: $newFileName'),
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
        SnackBar(content: Text('Could not save video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totalSec = _totalDuration.inMilliseconds / 1000.0;
    final trimmedLength = math.max(0.0, _endTrimSec - _startTrimSec);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: colors.surfaceElevated,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Trim ${widget.file.name}',
          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
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
              onPressed: _isSaving ? null : _saveTrimmedVideo,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Video Player Preview
          Expanded(
            child: Center(
              child: _isInitialized
                  ? Video(controller: _controller)
                  : const CircularProgressIndicator(),
            ),
          ),

          // Playback & Trim Controls
          Container(
            color: colors.surfaceElevated,
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timing info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Trim window', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                          Text(
                            '${_formatDuration(_startTrimSec)} – ${_formatDuration(_endTrimSec)}',
                            style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Duration: ${_formatDuration(trimmedLength)}',
                          style: TextStyle(color: colors.accentPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Range Slider for Trimming
                  if (totalSec > 0)
                    RangeSlider(
                      values: RangeValues(
                        _startTrimSec.clamp(0.0, totalSec),
                        _endTrimSec.clamp(0.0, totalSec),
                      ),
                      min: 0.0,
                      max: totalSec,
                      activeColor: colors.accentPrimary,
                      inactiveColor: colors.divider,
                      onChanged: (RangeValues values) {
                        setState(() {
                          _startTrimSec = values.start;
                          _endTrimSec = values.end;
                        });
                        _player.seek(Duration(milliseconds: (_startTrimSec * 1000).toInt()));
                      },
                    ),

                  const SizedBox(height: 8),

                  // Play / Pause / Seek Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded),
                        onPressed: () {
                          _player.seek(Duration(milliseconds: (_startTrimSec * 1000).toInt()));
                        },
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton.small(
                        backgroundColor: colors.accentPrimary,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          _player.playOrPause();
                        },
                        child: const Icon(Icons.play_arrow_rounded),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded),
                        onPressed: () {
                          _player.seek(Duration(milliseconds: (_endTrimSec * 1000).toInt()));
                        },
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
}
