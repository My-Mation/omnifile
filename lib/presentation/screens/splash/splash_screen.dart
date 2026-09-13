import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/open_file_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceRoot,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: SplashScreenLogoPainter(color: colors.accentPrimary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashScreenLogoPainter extends CustomPainter {
  final Color color;

  SplashScreenLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fold = size.width * 0.3;
    final r = 6.0;

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

    final flapPath = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold)
      ..lineTo(size.width, fold);

    canvas.drawPath(flapPath, paint);

    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final eyeWidth = size.width * 0.44;
    final eyeHeight = size.height * 0.22;

    final eyePath = Path()
      ..moveTo(cx - eyeWidth / 2, cy)
      ..quadraticBezierTo(cx, cy - eyeHeight, cx + eyeWidth / 2, cy)
      ..quadraticBezierTo(cx, cy + eyeHeight, cx - eyeWidth / 2, cy);

    canvas.drawPath(eyePath, paint);

    final pupilPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), size.width * 0.07, pupilPaint);
  }

  @override
  bool shouldRepaint(covariant SplashScreenLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
