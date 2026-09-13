import 'package:flutter/material.dart';
import '../../core/theme/open_file_colors.dart';

class OEMptyState extends StatelessWidget {
  const OEMptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _FannedFilesPainter(strokeColor: colors.textDisabled),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No recent files',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Open something to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FannedFilesPainter extends CustomPainter {
  final Color strokeColor;

  _FannedFilesPainter({required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final cy = size.height * 0.55;

    final angles = [-0.35, -0.17, 0.0, 0.17, 0.35];
    const cardWidth = 36.0;
    const cardHeight = 48.0;

    for (final angle in angles) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: const Offset(0, -8),
        width: cardWidth,
        height: cardHeight,
      );

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, paint);

      // Simple horizontal fold line at top right
      final foldSize = 8.0;
      final right = rect.right;
      final top = rect.top;
      canvas.drawLine(
        Offset(right - foldSize, top),
        Offset(right, top + foldSize),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FannedFilesPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor;
}
