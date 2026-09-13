import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/open_file_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.surfaceApp,
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      // App Logo (72dp: folded corner document + eye motif)
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CustomPaint(
                          painter: _AboutLogoPainter(color: colors.accentPrimary),
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
                      const SizedBox(height: 4),
                      Text(
                        'Version ${AppConstants.appVersion}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppConstants.appTagline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        color: colors.surfaceCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: const Text('Open-source licenses'),
                          subtitle: const Text('View licenses of third-party libraries'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            showLicensePage(
                              context: context,
                              applicationName: AppConstants.appName,
                              applicationVersion: AppConstants.appVersion,
                              applicationIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CustomPaint(
                                    painter: _AboutLogoPainter(color: colors.accentPrimary),
                                  ),
                                ),
                              ),
                              applicationLegalese: '100% Free & Open Source Offline Utility',
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: colors.surfaceCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.verified_user_outlined,
                                      color: colors.accentPrimary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '100% Offline Promise',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppConstants.privacyNotice,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                AppConstants.aboutTagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutLogoPainter extends CustomPainter {
  final Color color;

  _AboutLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fold = size.width * 0.3;
    final r = 6.0;

    // Document outline
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

    // Fold flap
    final flapPath = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold)
      ..lineTo(size.width, fold);

    canvas.drawPath(flapPath, paint);

    // Eye motif in center
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final eyeWidth = size.width * 0.44;
    final eyeHeight = size.height * 0.22;

    final eyePath = Path()
      ..moveTo(cx - eyeWidth / 2, cy)
      ..quadraticBezierTo(cx, cy - eyeHeight, cx + eyeWidth / 2, cy)
      ..quadraticBezierTo(cx, cy + eyeHeight, cx - eyeWidth / 2, cy);

    canvas.drawPath(eyePath, paint);

    // Pupil
    final pupilPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(cx, cy), size.width * 0.07, pupilPaint);
  }

  @override
  bool shouldRepaint(covariant _AboutLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
