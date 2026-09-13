import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/open_file_colors.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../widgets/viewer_shell.dart';
import '../../editor/video_editor_screen.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final FileEntity file;

  const VideoPlayerScreen({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _showControls = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  bool _isLooping = false;

  // Track streams
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  String? _errorMessage;

  // Subtitle auto-detect
  String? _detectedSubtitlePath;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _scanSiblingSubtitles();
  }

  Future<void> _initPlayer() async {
    _player = Player();
    _controller = VideoController(_player);

    _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _player.stream.error.listen((err) {
      if (mounted && err.isNotEmpty) {
        setState(() => _errorMessage = err);
      }
    });

    try {
      await _player.open(Media(widget.file.path));
      _startHideTimer();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Playback error: $e');
    }
  }

  void _scanSiblingSubtitles() {
    try {
      final dir = File(widget.file.path).parent;
      final base = p.basenameWithoutExtension(widget.file.path);
      final exts = ['.srt', '.vtt', '.ass', '.sub'];
      for (final ext in exts) {
        final subFile = File(p.join(dir.path, '$base$ext'));
        if (subFile.existsSync()) {
          _detectedSubtitlePath = subFile.path;
          _player.setSubtitleTrack(SubtitleTrack.uri(subFile.path));
          break;
        }
      }
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _player.setRate(speed);
  }

  void _toggleLoop() {
    setState(() => _isLooping = !_isLooping);
    _player.setPlaylistMode(_isLooping ? PlaylistMode.single : PlaylistMode.none);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final customActions = <Widget>[
      PopupMenuButton<double>(
        icon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${_playbackSpeed}x',
            style: TextStyle(color: colors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        tooltip: 'Playback speed',
        onSelected: _changeSpeed,
        itemBuilder: (context) => [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
            .map((s) => PopupMenuItem(value: s, child: Text('${s}x')))
            .toList(),
      ),
      IconButton(
        icon: const Icon(Icons.content_cut_rounded),
        tooltip: 'Trim / Edit',
        onPressed: () {
          _player.pause();
          VideoEditorScreen.open(context, widget.file);
        },
      ),
      IconButton(
        icon: Icon(_isLooping ? Icons.repeat_one : Icons.repeat),
        tooltip: _isLooping ? 'Looping enabled' : 'Looping disabled',
        color: _isLooping ? colors.accentPrimary : colors.textSecondary,
        onPressed: _toggleLoop,
      ),
    ];

    Widget body;
    if (_errorMessage != null) {
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
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          final dx = details.localPosition.dx;
          if (dx < width * 0.35) {
            // Left double tap: -10s
            _player.seek(_position - const Duration(seconds: 10));
          } else if (dx > width * 0.65) {
            // Right double tap: +10s
            _player.seek(_position + const Duration(seconds: 10));
          } else {
            // Center double tap: play/pause
            _player.playOrPause();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(color: Colors.black),
            Video(controller: _controller, controls: NoVideoControls),
            if (_showControls)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 20),
                      // Center play/pause & skips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 36,
                            color: Colors.white,
                            icon: const Icon(Icons.replay_10),
                            onPressed: () {
                              _player.seek(_position - const Duration(seconds: 10));
                              _startHideTimer();
                            },
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 56,
                            color: Colors.white,
                            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                            onPressed: () {
                              _player.playOrPause();
                              _startHideTimer();
                            },
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 36,
                            color: Colors.white,
                            icon: const Icon(Icons.forward_10),
                            onPressed: () {
                              _player.seek(_position + const Duration(seconds: 10));
                              _startHideTimer();
                            },
                          ),
                        ],
                      ),
                      // Bottom seekbar and duration
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: colors.accentPrimary,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: colors.accentPrimary,
                              ),
                              child: Slider(
                                min: 0.0,
                                max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                value: _position.inMilliseconds.toDouble().clamp(
                                      0.0,
                                      _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                    ),
                                onChanged: (val) {
                                  _player.seek(Duration(milliseconds: val.toInt()));
                                  _startHideTimer();
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                if (_detectedSubtitlePath != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('SUB', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
