import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/open_file_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/file_entity.dart';
import '../../domain/entities/settings_entity.dart';
import '../providers/settings_provider.dart';
import 'confirm_dialog.dart';
import 'file_info_dialog.dart';

class ViewerShell extends ConsumerStatefulWidget {
  final FileEntity file;
  final Widget child;
  final Widget? warningBanner;
  final Widget? noticeBanner;
  final List<Widget>? customActions;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final bool isEditable;
  final bool isEditing;
  final ValueChanged<bool>? onToggleEdit;
  final bool isDirty;
  final Future<bool> Function()? onSave;

  const ViewerShell({
    super.key,
    required this.file,
    required this.child,
    this.warningBanner,
    this.noticeBanner,
    this.customActions,
    this.isFullscreen = false,
    this.onToggleFullscreen,
    this.isEditable = false,
    this.isEditing = false,
    this.onToggleEdit,
    this.isDirty = false,
    this.onSave,
  });

  @override
  ConsumerState<ViewerShell> createState() => _ViewerShellState();
}

class _ViewerShellState extends ConsumerState<ViewerShell> {
  late bool _isFullscreen;

  @override
  void initState() {
    super.initState();
    _isFullscreen = widget.isFullscreen;
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    widget.onToggleFullscreen?.call();
  }

  void _shareFile() {
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(widget.file.path)],
      ),
    );
  }

  void _openWithAnotherApp() {
    OpenFilex.open(widget.file.path);
  }

  void _toggleTheme() {
    final current = ref.read(settingsProvider).themeMode;
    final next = current == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
    ref.read(settingsProvider.notifier).updateThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final title = Formatters.middleTruncate(widget.file.name, maxLength: 22);

    return PopScope(
      canPop: !_isFullscreen && !widget.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isFullscreen) {
          _toggleFullscreen();
          return;
        }
        if (widget.isDirty) {
          final discard = await ConfirmDialog.show(
            context: context,
            title: 'Discard changes?',
            message: 'You have unsaved changes. Discarding will lose your edits.',
            confirmLabel: 'Discard',
            cancelLabel: 'Keep editing',
            isDestructive: true,
          );
          if (discard && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: colors.surfaceRoot,
        appBar: _isFullscreen
            ? null
            : AppBar(
                backgroundColor: colors.surfaceApp,
                title: Text(title),
                actions: [
                  if (widget.isEditable)
                    IconButton(
                      icon: Icon(widget.isEditing ? Icons.edit : Icons.edit_outlined),
                      color: widget.isEditing ? colors.accentPrimary : colors.textPrimary,
                      tooltip: widget.isEditing ? 'Exit edit mode' : 'Edit document',
                      onPressed: () async {
                        if (widget.isEditing && widget.isDirty) {
                          final discard = await ConfirmDialog.show(
                            context: context,
                            title: 'Discard changes?',
                            message: 'You have unsaved changes. Discarding will lose your edits.',
                            confirmLabel: 'Discard',
                            cancelLabel: 'Keep editing',
                            isDestructive: true,
                          );
                          if (discard) {
                            widget.onToggleEdit?.call(false);
                          }
                        } else {
                          widget.onToggleEdit?.call(!widget.isEditing);
                        }
                      },
                    ),
                  if (widget.isEditable && widget.isEditing)
                    TextButton.icon(
                      icon: Icon(
                        Icons.save_outlined,
                        size: 18,
                        color: widget.isDirty ? colors.accentPrimary : colors.textDisabled,
                      ),
                      label: Text(
                        'Save',
                        style: TextStyle(
                          color: widget.isDirty ? colors.accentPrimary : colors.textDisabled,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: widget.isDirty ? widget.onSave : null,
                    ),
                  ...?widget.customActions,
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    color: colors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'info':
                          FileInfoDialog.show(context, widget.file);
                          break;
                        case 'share':
                          _shareFile();
                          break;
                        case 'open_with':
                          _openWithAnotherApp();
                          break;
                        case 'theme':
                          _toggleTheme();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'info',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 12),
                            Text('File info'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'open_with',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new, size: 20),
                            SizedBox(width: 12),
                            Text('Open with…'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'theme',
                        child: Row(
                          children: [
                            Icon(Icons.brightness_6_outlined, size: 20),
                            SizedBox(width: 12),
                            Text('Toggle theme'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        body: Column(
          children: [
            if (!_isFullscreen && widget.warningBanner != null)
              widget.warningBanner!,
            if (!_isFullscreen && widget.noticeBanner != null)
              widget.noticeBanner!,
            Expanded(
              child: GestureDetector(
                onDoubleTap: _toggleFullscreen,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
