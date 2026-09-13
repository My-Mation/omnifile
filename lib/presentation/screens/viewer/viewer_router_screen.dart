import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/file_entity.dart';
import '../../../domain/entities/viewer_type.dart';
import '../../providers/detection_provider.dart';
import '../../providers/recents_provider.dart';
import '../viewers/archive/archive_viewer.dart';
import '../viewers/audio/audio_player_screen.dart';
import '../viewers/hex/hex_viewer.dart';
import '../viewers/html/html_viewer.dart';
import '../viewers/image/image_viewer.dart';
import '../viewers/office/office_viewer.dart';
import '../viewers/pdf/pdf_viewer.dart';
import '../viewers/text_code/text_code_viewer.dart';
import '../viewers/video/video_player_screen.dart';

class ViewerRouterScreen extends ConsumerStatefulWidget {
  final FileEntity file;

  const ViewerRouterScreen({
    super.key,
    required this.file,
  });

  static Future<void> open(BuildContext context, FileEntity file) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ViewerRouterScreen(file: file),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // ui_rules.txt §7.1: Page push slide up 24dp + fade (250ms easeOutCubic)
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  ConsumerState<ViewerRouterScreen> createState() => _ViewerRouterScreenState();
}

class _ViewerRouterScreenState extends ConsumerState<ViewerRouterScreen> {
  late FileEntity _currentFile;
  late bool _isDetecting;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _isDetecting = widget.file.detectedType == ViewerType.unknown;
    _runDetection();
  }

  Future<void> _runDetection() async {
    final detector = ref.read(detectFileTypeUseCaseProvider);
    final detected = await detector(_currentFile.path, originalFileName: _currentFile.name);

    final updated = _currentFile.copyWith(detectedType: detected);

    // Update recents with real detected type in background
    ref.read(recentsProvider.notifier).addFile(updated);

    if (mounted) {
      setState(() {
        _currentFile = updated;
        _isDetecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    if (_isDetecting) {
      return Scaffold(
        backgroundColor: colors.surfaceRoot,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Opening ${Formatters.formatFileSize(_currentFile.size)}…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Route based on detection result
    switch (_currentFile.detectedType) {
      case ViewerType.text:
      case ViewerType.code:
      case ViewerType.markdown:
      case ViewerType.json:
        return TextCodeViewer(file: _currentFile);

      case ViewerType.pdf:
        return PdfViewer(file: _currentFile);

      case ViewerType.image:
        return ImageViewer(file: _currentFile);

      case ViewerType.video:
        return VideoPlayerScreen(file: _currentFile);

      case ViewerType.audio:
        return AudioPlayerScreen(file: _currentFile);

      case ViewerType.archive:
        return ArchiveViewer(file: _currentFile);

      case ViewerType.html:
      case ViewerType.svg:
        return HtmlViewer(file: _currentFile);

      case ViewerType.epub:
        return ArchiveViewer(file: _currentFile);

      case ViewerType.office:
        return OfficeViewer(file: _currentFile);

      case ViewerType.hex:
      case ViewerType.unknown:
        return HexViewer(file: _currentFile);
    }
  }
}
