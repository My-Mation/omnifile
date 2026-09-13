import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../widgets/file_type_icon.dart';
import '../../../widgets/viewer_shell.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  final FileEntity file;

  const AudioPlayerScreen({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  late final Player _player;
  double _playbackSpeed = 1.0;
  bool _isLooping = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _player = Player();

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
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Playback error: $e');
    }
  }

  @override
  void dispose() {
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
        itemBuilder: (context) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
            .map((s) => PopupMenuItem(value: s, child: Text('${s}x')))
            .toList(),
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
      body = Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative Audio Card
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider, width: 1.0),
              ),
              child: Center(
                child: FileTypeIcon(
                  viewerType: widget.file.detectedType,
                  extension: widget.file.extension,
                  size: 96,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Title and format
            Text(
              widget.file.name,
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.file.extension.toUpperCase()} • ${Formatters.formatFileSize(widget.file.size)}',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 32),
            // Seekbar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: colors.accentPrimary,
                inactiveTrackColor: colors.surfaceElevated,
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
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position), style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  Text(_formatDuration(_duration), style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  color: colors.textPrimary,
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => _player.seek(_position - const Duration(seconds: 10)),
                ),
                const SizedBox(width: 24),
                IconButton(
                  iconSize: 64,
                  color: colors.accentPrimary,
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: () => _player.playOrPause(),
                ),
                const SizedBox(width: 24),
                IconButton(
                  iconSize: 36,
                  color: colors.textPrimary,
                  icon: const Icon(Icons.forward_10),
                  onPressed: () => _player.seek(_position + const Duration(seconds: 10)),
                ),
              ],
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
