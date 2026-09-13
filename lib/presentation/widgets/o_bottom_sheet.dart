import 'package:flutter/material.dart';
import '../../core/theme/open_file_colors.dart';

class OBottomSheetAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const OBottomSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

class OBottomSheet extends StatelessWidget {
  final String? title;
  final List<OBottomSheetAction>? actions;
  final Widget? customContent;

  const OBottomSheet({
    super.key,
    this.title,
    this.actions,
    this.customContent,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    List<OBottomSheetAction>? actions,
    Widget? customContent,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: colors.surfaceCard,
      barrierColor: colors.overlayScrim,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => OBottomSheet(
        title: title,
        actions: actions,
        customContent: customContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            Divider(color: colors.divider, height: 1),
          ],
          ?customContent,
          ...?actions?.map((action) {
              final fgColor = action.color ?? colors.textPrimary;
              return SizedBox(
                height: 56,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      action.onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Icon(action.icon, size: 24, color: fgColor),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              action.label,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: fgColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
