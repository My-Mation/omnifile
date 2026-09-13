import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/file_entity.dart';
import '../../../domain/entities/viewer_type.dart';
import '../editor/image_editor_screen.dart';
import '../editor/video_editor_screen.dart';
import '../../widgets/file_info_dialog.dart';
import '../../widgets/file_type_badge.dart';

class LibraryFileTile extends StatelessWidget {
  final FileEntity file;
  final VoidCallback onTap;
  final VoidCallback? onRefresh;

  const LibraryFileTile({
    super.key,
    required this.file,
    required this.onTap,
    this.onRefresh,
  });

  void _showFloatingMenu(BuildContext context, TapDownDetails details) {
    final colors = context.colors;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colors.surfaceElevated,
      elevation: 4,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: colors.accentPrimary),
              const SizedBox(width: 12),
              Text('Edit', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.share_outlined, size: 20, color: colors.textSecondary),
              const SizedBox(width: 12),
              Text('Share / Copy', style: TextStyle(color: colors.textPrimary, fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'info',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: colors.textSecondary),
              const SizedBox(width: 12),
              Text('File info', style: TextStyle(color: colors.textPrimary, fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: colors.stateError),
              const SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: colors.stateError, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      if (value == 'edit') {
        if (file.detectedType == ViewerType.image) {
          ImageEditorScreen.open(context, file);
        } else if (file.detectedType == ViewerType.video) {
          VideoEditorScreen.open(context, file);
        } else {
          onTap();
        }
      } else if (value == 'share') {
        SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)]),
        );
      } else if (value == 'info') {
        FileInfoDialog.show(context, file);
      } else if (value == 'delete') {
        _confirmDelete(context);
      }
    });
  }

  void _confirmDelete(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete ${file.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              try {
                final ioFile = File(file.path);
                if (ioFile.existsSync()) {
                  ioFile.deleteSync();
                }
                onRefresh?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted ${file.name}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not delete: $e')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: colors.stateError)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final sizeStr = Formatters.formatFileSize(file.size);
    final timeStr = Formatters.formatRelativeTime(file.lastModified);
    final subtitleText = '$timeStr · $sizeStr';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              FileTypeBadge(
                viewerType: file.detectedType,
                extension: file.extension,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.middleTruncate(file.name, maxLength: 30),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTapDown: (details) => _showFloatingMenu(context, details),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.more_vert, color: colors.textSecondary, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
