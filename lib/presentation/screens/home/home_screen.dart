import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/open_file_colors.dart';
import '../../../domain/entities/file_entity.dart';
import '../../providers/detection_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/recents_provider.dart';
import '../../widgets/o_empty_state.dart';
import '../settings/settings_screen.dart';
import '../viewer/viewer_router_screen.dart';
import 'library_file_tile.dart';
import 'recents_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning 👋';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon 👋';
    } else {
      return 'Good evening 👋';
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isNotEmpty) {
        final picked = files.first;
        final path = picked.path;
        if (path == null) return;

        final file = File(path);
        int size = picked.lengthSync() ?? 0;
        if (size == 0 && await file.exists()) {
          try {
            size = await file.length();
          } catch (_) {}
        }
        DateTime modified = DateTime.now();
        if (await file.exists()) {
          try {
            modified = await file.lastModified();
          } catch (_) {}
        }

        final detector = ref.read(detectFileTypeUseCaseProvider);
        final detected = await detector(path, originalFileName: picked.name);

        final entity = FileEntity(
          path: path,
          name: picked.name,
          size: size,
          lastModified: modified,
          detectedType: detected,
        );

        await ref.read(recentsProvider.notifier).addFile(entity);
        ref.read(libraryProvider.notifier).scanLibrary();

        if (context.mounted) {
          ViewerRouterScreen.open(context, entity);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _addFolder(BuildContext context) async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        await ref.read(libraryProvider.notifier).addFolder(selectedDirectory);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Indexed folder: ${selectedDirectory.split('/').last}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add folder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final libraryState = ref.watch(libraryProvider);
    final recents = ref.watch(recentsProvider);
    final files = libraryState.filteredFiles;

    return Scaffold(
      backgroundColor: colors.surfaceApp,
      body: CustomScrollView(
        slivers: [
          // ------------------------------------------------------------------
          // 5.2 HEADER (FLAT MONOCHROME, NO GRADIENTS, NO SHADOWS)
          // ------------------------------------------------------------------
          SliverToBoxAdapter(
            child: Container(
              color: colors.surfaceApp,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Greeting + Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _getTimeGreeting(),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          // Folder Add Button
                          _CircleIconButton(
                            icon: Icons.create_new_folder_outlined,
                            tooltip: 'Add folder to library',
                            onPressed: () => _addFolder(context),
                          ),
                          const SizedBox(width: 8),
                          // Settings Button
                          _CircleIconButton(
                            icon: Icons.settings_outlined,
                            tooltip: 'Settings',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search Pill (Height 44dp, flat border, no shadows)
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.surfaceInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.divider, width: 0.5),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => ref.read(libraryProvider.notifier).setSearchQuery(val),
                          style: TextStyle(color: colors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search your documents…',
                            hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    color: colors.textSecondary,
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(libraryProvider.notifier).setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filter Chips Row (Horizontal Scroll)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: FileCategoryFilter.values.map((filter) {
                            final isSelected = filter == libraryState.activeFilter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(filter.label),
                                selected: isSelected,
                                selectedColor: colors.textPrimary,
                                backgroundColor: colors.surfaceCard,
                                labelStyle: TextStyle(
                                  color: isSelected ? colors.surfaceRoot : colors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(
                                    color: isSelected ? colors.textPrimary : colors.divider,
                                    width: 0.5,
                                  ),
                                ),
                                onSelected: (_) {
                                  ref.read(libraryProvider.notifier).setFilter(filter);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Recently Added Hero Card (Flat monochrome, 1px border, zero shadows)
                      InkWell(
                        onTap: () => RecentsScreen.open(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 88,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.divider, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.surfaceCard,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colors.divider, width: 0.5),
                                ),
                                child: Icon(
                                  Icons.history_rounded,
                                  color: colors.textPrimary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recently Added',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      recents.isNotEmpty
                                          ? '${recents.length} recent files available'
                                          : 'View your latest files in one place',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.textSecondary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ------------------------------------------------------------------
          // ALL DOCUMENTS SECTION HEADER
          // ------------------------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Documents',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        tooltip: 'Scan library',
                        color: colors.textSecondary,
                        onPressed: () => ref.read(libraryProvider.notifier).scanLibrary(),
                      ),
                      TextButton(
                        onPressed: () => _pickFile(context),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.accentPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_open, size: 16),
                            const SizedBox(width: 4),
                            Text('Open File', style: TextStyle(color: colors.accentPrimary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ------------------------------------------------------------------
          // DOCUMENT LIST / EMPTY STATE
          // ------------------------------------------------------------------
          if (libraryState.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
            )
          else if (files.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const OEMptyState(),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Add a folder to build your library'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.accentPrimary,
                        side: BorderSide(color: colors.accentPrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () => _addFolder(context),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final file = files[index];
                    return LibraryFileTile(
                      file: file,
                      onTap: () {
                        ref.read(recentsProvider.notifier).addFile(file);
                        ViewerRouterScreen.open(context, file);
                      },
                      onRefresh: () => ref.read(libraryProvider.notifier).scanLibrary(),
                    );
                  },
                  childCount: files.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceElevated,
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: colors.textPrimary),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
