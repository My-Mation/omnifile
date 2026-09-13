import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/theme/open_file_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/file_entity.dart';
import '../../domain/entities/viewer_type.dart';
import 'file_type_icon.dart';
import 'o_filled_button.dart';
import '../screens/viewers/hex/hex_viewer.dart';
import '../screens/viewers/text_code/text_code_viewer.dart';

class UnsupportedScreen extends StatelessWidget {
  final FileEntity file;

  const UnsupportedScreen({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final sizeStr = Formatters.formatFileSize(file.size);
    final dateStr = Formatters.formatFullDateTime(file.lastModified);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileTypeIcon(
              viewerType: file.detectedType,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Preview not available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No native preview for this format (${file.detectedType.displayName}).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // File summary card
            Card(
              color: colors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCardRow('Name', file.name, colors, theme),
                    const SizedBox(height: 6),
                    _buildCardRow('Type', file.detectedType.displayName, colors, theme),
                    const SizedBox(height: 6),
                    _buildCardRow('Size', sizeStr, colors, theme),
                    const SizedBox(height: 6),
                    _buildCardRow('Modified', dateStr, colors, theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TextCodeViewer(
                          file: file.copyWith(detectedType: ViewerType.text),
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accentPrimary,
                    side: BorderSide(color: colors.accentPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Open as text'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => HexViewer(file: file)),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accentPrimary,
                    side: BorderSide(color: colors.accentPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Open as hex'),
                ),
                OFilledButton(
                  label: 'Open with another app',
                  icon: Icons.open_in_new,
                  onPressed: () => OpenFilex.open(file.path),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                final details = 'File: ${file.name}\nType: ${file.detectedType.name}\nSize: ${file.size}\nPath: ${file.path}';
                Clipboard.setData(ClipboardData(text: details));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File details copied to clipboard'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
                minimumSize: const Size(48, 36),
              ),
              child: Text(
                'Copy details',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardRow(
    String label,
    String value,
    OpenFileColors colors,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
