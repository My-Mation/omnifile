import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/settings_entity.dart';
import '../../providers/recents_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/o_bottom_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _privacyExpanded = false;

  void _showThemeSheet(BuildContext context, AppThemeMode currentMode) {
    OBottomSheet.show(
      context: context,
      title: 'Theme',
      customContent: RadioGroup<AppThemeMode>(
        groupValue: currentMode,
        onChanged: (val) {
          if (val != null) {
            ref.read(settingsProvider.notifier).updateThemeMode(val);
            Navigator.of(context).pop();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(mode.displayName),
              value: mode,
              activeColor: context.colors.accentPrimary,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCodeFontSheet(BuildContext context, CodeFont currentFont) {
    OBottomSheet.show(
      context: context,
      title: 'Code Font',
      customContent: RadioGroup<CodeFont>(
        groupValue: currentFont,
        onChanged: (val) {
          if (val != null) {
            ref.read(settingsProvider.notifier).updateCodeFont(val);
            Navigator.of(context).pop();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: CodeFont.values.map((font) {
            return RadioListTile<CodeFont>(
              title: Text(
                font.displayName,
                style: TextStyle(
                  fontFamily: font.fontFamily,
                ),
              ),
              value: font,
              activeColor: context.colors.accentPrimary,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFontSizeSheet(BuildContext context, double currentSize, CodeFont currentFont) {
    double tempSize = currentSize;
    OBottomSheet.show(
      context: context,
      title: 'Default Text Size',
      customContent: StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = context.colors;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Size',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                    ),
                    Text(
                      '${tempSize.toInt()} sp',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.accentPrimary,
                          ),
                    ),
                  ],
                ),
                Slider(
                  value: tempSize,
                  min: 10,
                  max: 28,
                  divisions: 9,
                  activeColor: colors.accentPrimary,
                  onChanged: (val) {
                    setSheetState(() => tempSize = val);
                    ref.read(settingsProvider.notifier).updateDefaultFontSize(val);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceInput,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'const answer = 42;\n// OpenFile offline preview',
                    style: TextStyle(
                      fontFamily: currentFont.fontFamily,
                      fontSize: tempSize,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _clearRecents(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Clear recent files?',
      message: 'This will remove all recent files from the list.',
      confirmLabel: 'Clear',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed) {
      await ref.read(recentsProvider.notifier).clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recent files cleared'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Clear cache?',
      message: 'This will remove all temporary extracted files.',
      confirmLabel: 'Clear',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed) {
      await ref.read(cacheProvider.notifier).clearCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final cacheState = ref.watch(cacheProvider);

    final cacheSizeStr = cacheState.when(
      data: (size) => Formatters.formatFileSize(size),
      loading: () => 'Calculating…',
      error: (e, st) => '0 B',
    );

    return Scaffold(
      backgroundColor: colors.surfaceApp,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Group: Appearance
          _buildGroupHeader('Appearance', colors, theme),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Text(settings.themeMode.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeSheet(context, settings.themeMode),
          ),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: const Text('Code font'),
            subtitle: Text(settings.codeFont.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCodeFontSheet(context, settings.codeFont),
          ),
          ListTile(
            leading: const Icon(Icons.format_size_outlined),
            title: const Text('Default text size'),
            subtitle: Text('${settings.defaultFontSize.toInt()} sp'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontSizeSheet(
              context,
              settings.defaultFontSize,
              settings.codeFont,
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: colors.divider),
          const SizedBox(height: 16),

          // Group: Viewer
          _buildGroupHeader('Viewer', colors, theme),
          SwitchListTile(
            secondary: const Icon(Icons.wrap_text_outlined),
            title: const Text('Word wrap default'),
            subtitle: const Text('Applies to new text files'),
            value: settings.wordWrapDefault,
            activeTrackColor: colors.accentPrimary,
            onChanged: (val) =>
                ref.read(settingsProvider.notifier).updateWordWrapDefault(val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.subtitles_outlined),
            title: const Text('Auto-load subtitles'),
            subtitle: const Text('Load sibling subtitle files with same name'),
            value: settings.autoLoadSubtitles,
            activeTrackColor: colors.accentPrimary,
            onChanged: (val) =>
                ref.read(settingsProvider.notifier).updateAutoLoadSubtitles(val),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.restore_outlined),
            title: const Text('Remember playback position'),
            subtitle: const Text('Resume media from where you stopped'),
            value: settings.rememberPlaybackPosition,
            activeTrackColor: colors.accentPrimary,
            onChanged: (val) => ref
                .read(settingsProvider.notifier)
                .updateRememberPlaybackPosition(val),
          ),

          const SizedBox(height: 16),
          Divider(color: colors.divider),
          const SizedBox(height: 16),

          // Group: Storage
          _buildGroupHeader('Storage', colors, theme),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: colors.stateError),
            title: Text(
              'Clear recent files',
              style: TextStyle(color: colors.stateError),
            ),
            subtitle: const Text('Remove all items from recents history'),
            onTap: () => _clearRecents(context),
          ),
          ListTile(
            leading: const Icon(Icons.cached_outlined),
            title: const Text('Clear cache'),
            subtitle: Text(cacheSizeStr),
            onTap: () => _clearCache(context),
          ),

          const SizedBox(height: 16),
          Divider(color: colors.divider),
          const SizedBox(height: 16),

          // Group: Privacy
          _buildGroupHeader('Privacy', colors, theme),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('Privacy commitment'),
            subtitle: _privacyExpanded
                ? null
                : const Text('No internet, no analytics, no ads'),
            trailing: Icon(
              _privacyExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() => _privacyExpanded = !_privacyExpanded);
            },
          ),
          if (_privacyExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppConstants.privacyNotice,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, OpenFileColors colors, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: colors.accentPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
