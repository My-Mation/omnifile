import 'package:flutter/material.dart';
import '../../core/theme/open_file_colors.dart';

class OBanner extends StatelessWidget {
  final String text;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isWarning;

  const OBanner({
    super.key,
    required this.text,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.isWarning = false,
  });

  factory OBanner.warning({
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return OBanner(
      text: text,
      icon: Icons.warning_amber_rounded,
      actionLabel: actionLabel,
      onAction: onAction,
      isWarning: true,
    );
  }

  factory OBanner.notice({
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return OBanner(
      text: text,
      icon: Icons.info_outline,
      actionLabel: actionLabel,
      onAction: onAction,
      isWarning: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final bg = isWarning ? colors.stateWarningContainer : colors.surfaceElevated;
    final fg = isWarning ? colors.stateWarning : colors.textPrimary;

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colors.accentPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(48, 36),
              ),
              child: Text(
                actionLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
