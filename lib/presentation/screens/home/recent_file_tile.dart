import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/file_entity.dart';
import '../../widgets/file_info_dialog.dart';
import '../../widgets/file_type_icon.dart';
import '../../widgets/o_bottom_sheet.dart';

class RecentFileTile extends StatelessWidget {
  final FileEntity file;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const RecentFileTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.onRemove,
  });

  void _showFileActions(BuildContext context) {
    OBottomSheet.show(
      context: context,
      title: Formatters.middleTruncate(file.name, maxLength: 28),
      actions: [
        OBottomSheetAction(
          icon: Icons.info_outline,
          label: 'File info',
          onTap: () => FileInfoDialog.show(context, file),
        ),
        OBottomSheetAction(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {
            SharePlus.instance.share(
              ShareParams(
                files: [XFile(file.path)],
              ),
            );
          },
        ),
        OBottomSheetAction(
          icon: Icons.delete_outline,
          label: 'Remove from recents',
          color: context.colors.stateError,
          onTap: onRemove,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final sizeStr = Formatters.formatFileSize(file.size);
    final timeStr = Formatters.formatRelativeTime(file.lastModified);
    final subtitleText = '$sizeStr · $timeStr';

    return Dismissible(
      key: ValueKey('recent_${file.path}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.35, // ~120dp commit on standard width
      },
      onDismissed: (_) => onRemove(),
      background: Container(
        color: colors.stateError,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: SizedBox(
        height: 72,
        child: Material(
          color: colors.surfaceCard,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FileTypeIcon(
                    viewerType: file.detectedType,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.middleTruncate(file.name, maxLength: 28),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: colors.textSecondary,
                    tooltip: 'More actions',
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: () => _showFileActions(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
