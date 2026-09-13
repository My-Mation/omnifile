import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/open_file_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/file_entity.dart';

class FileInfoDialog extends StatefulWidget {
  final FileEntity file;

  const FileInfoDialog({
    super.key,
    required this.file,
  });

  static Future<void> show(BuildContext context, FileEntity file) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => FileInfoDialog(file: file),
    );
  }

  @override
  State<FileInfoDialog> createState() => _FileInfoDialogState();
}

class _FileInfoDialogState extends State<FileInfoDialog> {
  String? _sha256;
  bool _calculatingSha = true;

  @override
  void initState() {
    super.initState();
    _computeHash();
  }

  Future<void> _computeHash() async {
    final hash = await FileUtils.computeSha256(widget.file.path);
    if (mounted) {
      setState(() {
        _sha256 = hash;
        _calculatingSha = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    final rows = <_InfoRowData>[
      _InfoRowData('Name', widget.file.name),
      _InfoRowData('Type', widget.file.detectedType.displayName),
      _InfoRowData(
        'Size',
        '${Formatters.formatFileSize(widget.file.size)} (${widget.file.size} bytes)',
      ),
      _InfoRowData('Path', widget.file.path),
      _InfoRowData(
        'Modified',
        Formatters.formatFullDateTime(widget.file.lastModified),
      ),
    ];

    return Dialog(
      backgroundColor: colors.surfaceElevated,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File Info',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              ...rows.map((row) => _buildRow(context, row.key, row.value)),
              _buildSha256Row(context),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accentPrimary,
                    minimumSize: const Size(48, 40),
                  ),
                  child: Text(
                    'Close',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.accentPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String key, String value) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              key,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSha256Row(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    Widget valueWidget;
    if (_calculatingSha) {
      valueWidget = Text(
        'Calculating…',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      );
    } else if (_sha256 == null) {
      valueWidget = Text(
        'Not available',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textDisabled,
        ),
      );
    } else {
      final truncatedHash = _sha256!.length >= 16
          ? '${_sha256!.substring(0, 16)}…'
          : _sha256!;
      valueWidget = Row(
        children: [
          Expanded(
            child: Text(
              truncatedHash,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            color: colors.accentPrimary,
            tooltip: 'Copy SHA-256',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _sha256!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SHA-256 copied to clipboard'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'SHA-256',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}

class _InfoRowData {
  final String key;
  final String value;
  _InfoRowData(this.key, this.value);
}
