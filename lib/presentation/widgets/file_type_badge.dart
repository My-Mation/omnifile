import 'package:flutter/material.dart';
import '../../core/theme/open_file_colors.dart';
import '../../domain/entities/viewer_type.dart';

class FileTypeBadge extends StatelessWidget {
  final ViewerType viewerType;
  final String? extension;
  final double size;

  const FileTypeBadge({
    super.key,
    required this.viewerType,
    this.extension,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = _getBadgeLabel();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      alignment: Alignment.center,
      child: _buildBadgeContent(label, colors),
    );
  }

  String _getBadgeLabel() {
    final ext = (extension ?? '').toLowerCase();
    if (ext.isNotEmpty) {
      if (ext == 'docx' || ext == 'doc') return 'DOC';
      if (ext == 'xlsx' || ext == 'xls') return 'XLS';
      if (ext == 'pptx' || ext == 'ppt') return 'PPT';
      if (ext == 'pdf') return 'PDF';
      if (ext == 'zip' || ext == 'tar' || ext == 'gz') return 'ZIP';
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp') return 'IMG';
      if (ext == 'mp4' || ext == 'mkv' || ext == 'avi') return 'VID';
      if (ext == 'mp3' || ext == 'wav' || ext == 'flac') return '♪';
    }

    switch (viewerType) {
      case ViewerType.pdf:
        return 'PDF';
      case ViewerType.office:
        return 'DOC';
      case ViewerType.code:
      case ViewerType.html:
      case ViewerType.json:
        return '</>';
      case ViewerType.audio:
        return '♪';
      case ViewerType.video:
        return 'VID';
      case ViewerType.image:
      case ViewerType.svg:
        return 'IMG';
      case ViewerType.archive:
        return 'ZIP';
      case ViewerType.text:
      case ViewerType.markdown:
        return 'TXT';
      case ViewerType.epub:
        return 'EPUB';
      case ViewerType.hex:
      case ViewerType.unknown:
        return '?';
    }
  }

  Widget _buildBadgeContent(String label, OpenFileColors colors) {
    if (label == '♪') {
      return Text(
        label,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Text(
      label,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: label.length > 3 ? 10 : 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        fontFamily: 'monospace',
      ),
    );
  }
}
