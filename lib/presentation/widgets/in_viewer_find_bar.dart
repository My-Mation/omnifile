import 'package:flutter/material.dart';
import '../../core/theme/open_file_colors.dart';

class InViewerFindBar extends StatelessWidget {
  final TextEditingController controller;
  final int matchCount;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;
  final bool showReplace;
  final TextEditingController? replaceController;
  final VoidCallback? onReplace;
  final VoidCallback? onReplaceAll;

  const InViewerFindBar({
    super.key,
    required this.controller,
    required this.matchCount,
    required this.currentIndex,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
    required this.onChanged,
    this.showReplace = false,
    this.replaceController,
    this.onReplace,
    this.onReplaceAll,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final countText = matchCount > 0 ? '${currentIndex + 1}/$matchCount' : '0/0';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceApp,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Search field + Nav + Close
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.surfaceInput,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 20, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          onChanged: onChanged,
                          autofocus: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Find in file…',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textDisabled,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (controller.text.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            countText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: matchCount > 0 ? colors.textPrimary : colors.stateError,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          color: colors.textSecondary,
                          tooltip: 'Clear',
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 22),
                color: matchCount > 0 ? colors.textPrimary : colors.textDisabled,
                tooltip: 'Previous match',
                onPressed: matchCount > 0 ? onPrev : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                color: matchCount > 0 ? colors.textPrimary : colors.textDisabled,
                tooltip: 'Next match',
                onPressed: matchCount > 0 ? onNext : null,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: colors.textSecondary,
                tooltip: 'Close search',
                onPressed: onClose,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),

          // Row 2: Replace controls (when showReplace is true)
          if (showReplace && replaceController != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceInput,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.find_replace, size: 18, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: replaceController,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Replace with…',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textDisabled,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: matchCount > 0 ? onReplace : null,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accentPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Replace', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: matchCount > 0 ? onReplaceAll : null,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accentPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Replace all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
