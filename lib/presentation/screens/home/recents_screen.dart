import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../providers/recents_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/o_empty_state.dart';
import '../viewer/viewer_router_screen.dart';
import 'recent_file_tile.dart';

class RecentsScreen extends ConsumerWidget {
  const RecentsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecentsScreen()),
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Clear recent files?',
      message: 'This will remove all recent files from the list.',
      confirmLabel: 'Clear all',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed) {
      await ref.read(recentsProvider.notifier).clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recent files cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final recents = ref.watch(recentsProvider);

    return Scaffold(
      backgroundColor: colors.surfaceApp,
      appBar: AppBar(
        title: const Text('Recently Added', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: colors.surfaceApp,
        elevation: 0,
        actions: [
          if (recents.isNotEmpty)
            TextButton(
              onPressed: () => _clearAll(context, ref),
              child: Text('Clear all', style: TextStyle(color: colors.stateError)),
            ),
        ],
      ),
      body: recents.isEmpty
          ? const OEMptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: recents.length,
              itemBuilder: (context, index) {
                final file = recents[index];
                return RecentFileTile(
                  file: file,
                  onTap: () => ViewerRouterScreen.open(context, file),
                  onRemove: () => ref.read(recentsProvider.notifier).removeFile(file.path),
                );
              },
            ),
    );
  }
}
