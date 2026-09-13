import 'package:flutter/material.dart';
import '../../core/theme/open_file_colors.dart';
import '../../domain/entities/viewer_type.dart';

class FileTypeIcon extends StatelessWidget {
  final ViewerType viewerType;
  final double size;
  final String? extension;

  const FileTypeIcon({
    super.key,
    required this.viewerType,
    this.size = 40.0,
    this.extension,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color iconColor = _getColorForType(colors);
    final IconData iconData = _getIconForType();

    return Semantics(
      label: '${viewerType.displayName} file',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _FileShapePainter(color: iconColor),
          child: Center(
            child: Icon(
              iconData,
              color: iconColor,
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForType(OpenFileColors colors) {
    switch (viewerType) {
      case ViewerType.pdf:
        return colors.filePdf;
      case ViewerType.text:
        return colors.fileText;
      case ViewerType.markdown:
        return colors.fileMarkdown;
      case ViewerType.image:
        return colors.fileImage;
      case ViewerType.video:
        return colors.fileVideo;
      case ViewerType.audio:
        return colors.fileAudio;
      case ViewerType.archive:
        return colors.fileArchive;
      case ViewerType.html:
        return colors.fileHtml;
      case ViewerType.code:
        return colors.fileCode;
      case ViewerType.office:
        return colors.fileDocument;
      case ViewerType.epub:
        return colors.fileDocument;
      case ViewerType.json:
        return colors.fileCode;
      case ViewerType.svg:
        return colors.fileImage;
      case ViewerType.hex:
      case ViewerType.unknown:
        return colors.fileUnknown;
    }
  }

  IconData _getIconForType() {
    switch (viewerType) {
      case ViewerType.pdf:
        return Icons.picture_as_pdf_outlined;
      case ViewerType.text:
        return Icons.description_outlined;
      case ViewerType.markdown:
        return Icons.article_outlined;
      case ViewerType.image:
        return Icons.image_outlined;
      case ViewerType.video:
        return Icons.videocam_outlined;
      case ViewerType.audio:
        return Icons.audiotrack_outlined;
      case ViewerType.archive:
        return Icons.folder_zip_outlined;
      case ViewerType.html:
        return Icons.html_outlined;
      case ViewerType.code:
        return Icons.code_outlined;
      case ViewerType.office:
        return Icons.feed_outlined;
      case ViewerType.epub:
        return Icons.menu_book_outlined;
      case ViewerType.json:
        return Icons.data_object_outlined;
      case ViewerType.svg:
        return Icons.polyline_outlined;
      case ViewerType.hex:
        return Icons.memory_outlined;
      case ViewerType.unknown:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class _FileShapePainter extends CustomPainter {
  final Color color;

  _FileShapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fold = size.width * 0.28;
    final r = 3.0; // corner radius

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(Offset(size.width - r, size.height), radius: Radius.circular(r))
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();

    canvas.drawPath(path, paint);

    // Draw fold flap
    final flapPath = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold)
      ..lineTo(size.width, fold);

    canvas.drawPath(flapPath, paint);
  }

  @override
  bool shouldRepaint(covariant _FileShapePainter oldDelegate) =>
      oldDelegate.color != color;
}
