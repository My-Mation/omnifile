import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/open_file_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../../domain/entities/settings_entity.dart';
import '../../../../domain/entities/viewer_type.dart';
import '../../../providers/detection_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/recents_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/in_viewer_find_bar.dart';
import '../../../widgets/o_banner.dart';
import '../../../widgets/o_bottom_sheet.dart';
import '../../../widgets/viewer_shell.dart';
import 'encoding_helper.dart';
import 'highlight_map.dart';
import 'syntax_highlighting_controller.dart';

class TextCodeViewer extends ConsumerStatefulWidget {
  final FileEntity file;

  const TextCodeViewer({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<TextCodeViewer> createState() => _TextCodeViewerState();
}

class _TextCodeViewerState extends ConsumerState<TextCodeViewer> {
  Uint8List? _rawBytes;
  String _initialContent = '';
  bool _isLoading = true;
  String? _errorMessage;

  // Edit mode & Dirty state
  bool _isEditing = false;
  bool _isDirty = false;
  late SyntaxHighlightingController _codeController;
  final FocusNode _codeFocusNode = FocusNode();

  // Encodings
  FileEncoding _currentEncoding = FileEncoding.utf8;

  // Large file handling
  bool _isTruncated = false;
  static const int _oneMb = 1024 * 1024;
  static const int _twoMb = 2 * 1024 * 1024;
  static const int _fiftyMb = 50 * 1024 * 1024;

  // Word wrap
  late bool _wordWrap;

  // Markdown Rendered vs Source toggle
  bool _isMarkdownRendered = false;

  // Find & Replace in file
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  List<_SearchMatch> _matches = [];
  int _currentMatchIndex = -1;

  // Scroll controllers
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  // Scale tracking for font size pinch
  double _baseScaleFontSize = 14.0;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    final ext = _getExtension(widget.file.name);
    final isLogOrTxt = ext == 'txt' || ext == 'log' || ext == 'csv' || ext == 'tsv';
    _wordWrap = isLogOrTxt ? true : settings.wordWrapDefault;
    final isMarkdown = widget.file.detectedType == ViewerType.markdown ||
        ext == 'md' ||
        ext == 'markdown' ||
        widget.file.name.toLowerCase().startsWith('readme');
    _isMarkdownRendered = isMarkdown;

    _codeController = SyntaxHighlightingController(
      colors: OpenFileColors.dark,
      language: HighlightMap.getLanguageForFilename(widget.file.name) ??
          HighlightMap.getLanguageForExtension(ext),
    );
    _codeController.addListener(_onCodeChanged);

    _loadFile();
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _codeFocusNode.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    final currentText = _codeController.text;
    final dirty = currentText != _initialContent;
    if (dirty != _isDirty) {
      setState(() => _isDirty = dirty);
    }
  }

  String _getExtension(String path) {
    final slashIndex = path.lastIndexOf('/');
    final backslashIndex = path.lastIndexOf('\\');
    final lastSep = slashIndex > backslashIndex ? slashIndex : backslashIndex;
    final filename = lastSep != -1 ? path.substring(lastSep + 1) : path;

    if (filename.startsWith('.') && filename.indexOf('.', 1) == -1) {
      return '';
    }

    final dot = filename.lastIndexOf('.');
    return (dot != -1 && dot < filename.length - 1)
        ? filename.substring(dot + 1).toLowerCase()
        : '';
  }

  Future<void> _loadFile({bool forceFull = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'File not found on device.';
        });
        return;
      }

      final fileSize = widget.file.size;

      // 50MB check
      if (fileSize > _fiftyMb && !forceFull) {
        if (!mounted) return;
        final confirmed = await ConfirmDialog.show(
          context: context,
          title: 'Large file confirmation',
          message:
              'This file is ${Formatters.formatFileSize(fileSize)}. Opening large text files may consume considerable memory. Continue?',
          confirmLabel: 'Open anyway',
          cancelLabel: 'Cancel',
          isDestructive: false,
        );
        if (!confirmed) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }

      // If >2MB and not forced, read first 1MB
      if (fileSize > _twoMb && !forceFull) {
        final raf = await file.open(mode: FileMode.read);
        try {
          _rawBytes = await raf.read(_oneMb);
          _isTruncated = true;
        } finally {
          await raf.close();
        }
      } else {
        _rawBytes = await file.readAsBytes();
        _isTruncated = false;
      }

      _currentEncoding = EncodingHelper.detectEncoding(_rawBytes!);
      _initialContent = EncodingHelper.decode(_rawBytes!, _currentEncoding);

      _codeController.text = _initialContent;
      _isDirty = false;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to read file: $e';
        });
      }
    }
  }

  void _switchEncoding(FileEncoding encoding) {
    if (_rawBytes == null) return;
    setState(() {
      _currentEncoding = encoding;
      _initialContent = EncodingHelper.decode(_rawBytes!, encoding);
      _codeController.text = _initialContent;
      _isDirty = false;
    });
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _showEncodingPicker() {
    OBottomSheet.show(
      context: context,
      title: 'Character Encoding',
      customContent: RadioGroup<FileEncoding>(
        groupValue: _currentEncoding,
        onChanged: (val) {
          if (val != null) {
            _switchEncoding(val);
            Navigator.of(context).pop();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: FileEncoding.values.map((enc) {
            return RadioListTile<FileEncoding>(
              title: Text(enc.displayName),
              value: enc,
              activeColor: context.colors.accentPrimary,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _matches = [];
        _currentMatchIndex = -1;
      });
      _codeController.updateSettings(
        newColors: context.colors,
        newSearchQuery: '',
        newMatchIndex: -1,
      );
      return;
    }

    final lowerText = _codeController.text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final newMatches = <_SearchMatch>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      newMatches.add(_SearchMatch(charOffset: index, length: query.length));
      start = index + query.length;
    }

    final newMatchIndex = newMatches.isNotEmpty ? 0 : -1;
    setState(() {
      _matches = newMatches;
      _currentMatchIndex = newMatchIndex;
    });

    _codeController.updateSettings(
      newColors: context.colors,
      newSearchQuery: query,
      newMatchIndex: newMatchIndex,
    );

    if (newMatches.isNotEmpty) {
      _scrollToMatch(0);
    }
  }

  void _scrollToMatch(int index) {
    if (index < 0 || index >= _matches.length) return;
    final match = _matches[index];
    setState(() {
      _currentMatchIndex = index;
    });

    _codeController.updateSettings(
      newColors: context.colors,
      newMatchIndex: index,
    );

    // Select match in text field so it scrolls into view
    _codeController.selection = TextSelection(
      baseOffset: match.charOffset,
      extentOffset: match.charOffset + match.length,
    );
  }

  void _replaceCurrent() {
    if (_matches.isEmpty || _currentMatchIndex < 0 || _currentMatchIndex >= _matches.length) return;
    final query = _searchController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;

    final match = _matches[_currentMatchIndex];
    final text = _codeController.text;
    final newText = text.substring(0, match.charOffset) + replacement + text.substring(match.charOffset + match.length);

    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: match.charOffset + replacement.length),
    );

    _performSearch(query);
  }

  void _replaceAll() {
    final query = _searchController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;

    final text = _codeController.text;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final sb = StringBuffer();
    int start = 0;
    int count = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        sb.write(text.substring(start));
        break;
      }
      sb.write(text.substring(start, index));
      sb.write(replacement);
      count++;
      start = idxOrBreak(index, query.length);
    }

    if (count > 0) {
      _codeController.text = sb.toString();
      _performSearch(query);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Replaced $count occurrences'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  int idxOrBreak(int index, int len) => index + len;

  Future<bool> _saveFile() async {
    try {
      final originalFile = File(widget.file.path);
      final parentDir = originalFile.parent.path;
      final ext = _getExtension(widget.file.name);
      final originalName = widget.file.name;
      String nameWithoutExt;
      if (originalName.startsWith('.') && originalName.indexOf('.', 1) == -1) {
        nameWithoutExt = originalName;
      } else if (originalName.contains('.')) {
        nameWithoutExt = originalName.substring(0, originalName.lastIndexOf('.'));
      } else {
        nameWithoutExt = originalName;
      }

      String newFileName = ext.isNotEmpty ? '$nameWithoutExt (edited).$ext' : '$nameWithoutExt (edited)';
      String newFilePath = p.join(parentDir, newFileName);
      int counter = 2;
      while (await File(newFilePath).exists()) {
        newFileName = ext.isNotEmpty ? '$nameWithoutExt (edited) ($counter).$ext' : '$nameWithoutExt (edited) ($counter)';
        newFilePath = p.join(parentDir, newFileName);
        counter++;
      }

      final encodedBytes = EncodingHelper.encode(_codeController.text, _currentEncoding);
      await File(newFilePath).writeAsBytes(encodedBytes);

      _initialContent = _codeController.text;
      setState(() {
        _isDirty = false;
      });

      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final newEntity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: encodedBytes.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(newEntity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $newFileName'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    final ext = _getExtension(widget.file.name);
    final language = HighlightMap.getLanguageForFilename(widget.file.name) ??
        HighlightMap.getLanguageForExtension(ext);
    final isMarkdown = widget.file.detectedType == ViewerType.markdown ||
        ext == 'md' ||
        ext == 'markdown' ||
        widget.file.name.toLowerCase().startsWith('readme');

    // Update code controller colors and language if needed
    _codeController.colors = colors;
    _codeController.language = language;

    if (_isLoading) {
      return ViewerShell(
        file: widget.file,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Opening ${Formatters.formatFileSize(widget.file.size)}…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return ViewerShell(
        file: widget.file,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: colors.stateError),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget? warningBanner;
    if (_isTruncated) {
      final totalStr = Formatters.formatFileSize(widget.file.size);
      warningBanner = OBanner.warning(
        text: 'Large file — $totalStr. Loaded first 1 MB.',
        actionLabel: 'Load more',
        onAction: () => _loadFile(forceFull: true),
      );
    }

    final customActions = <Widget>[
      if (isMarkdown && !_isEditing)
        IconButton(
          icon: Icon(
            _isMarkdownRendered ? Icons.code : Icons.visibility,
          ),
          tooltip: _isMarkdownRendered ? 'View Source' : 'View Rendered',
          onPressed: () {
            setState(() => _isMarkdownRendered = !_isMarkdownRendered);
          },
        ),
      IconButton(
        icon: const Icon(Icons.copy_all),
        tooltip: 'Copy whole file',
        onPressed: () async {
          final content = _codeController.text;
          if (content.isNotEmpty) {
            await Clipboard.setData(ClipboardData(text: content));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied entire file (${content.length} chars) to clipboard'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Find in file',
        onPressed: () {
          setState(() {
            _isSearchActive = !_isSearchActive;
            if (!_isSearchActive) {
              _searchController.clear();
              _replaceController.clear();
              _matches = [];
              _currentMatchIndex = -1;
              _codeController.updateSettings(
                newColors: colors,
                newSearchQuery: '',
                newMatchIndex: -1,
              );
            }
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.text_increase),
        tooltip: 'Increase font size',
        onPressed: () {
          final newSize = (settings.defaultFontSize + 2).clamp(10.0, 28.0);
          ref.read(settingsProvider.notifier).updateDefaultFontSize(newSize);
        },
      ),
      IconButton(
        icon: const Icon(Icons.text_decrease),
        tooltip: 'Decrease font size',
        onPressed: () {
          final newSize = (settings.defaultFontSize - 2).clamp(10.0, 28.0);
          ref.read(settingsProvider.notifier).updateDefaultFontSize(newSize);
        },
      ),
      IconButton(
        icon: Icon(_wordWrap ? Icons.wrap_text : Icons.format_align_left),
        tooltip: _wordWrap ? 'Word wrap ON' : 'Word wrap OFF',
        onPressed: () {
          setState(() => _wordWrap = !_wordWrap);
        },
      ),
      IconButton(
        icon: const Icon(Icons.text_format),
        tooltip: 'Encoding: ${_currentEncoding.displayName}',
        onPressed: _showEncodingPicker,
      ),
    ];

    Widget bodyContent;
    if (isMarkdown && _isMarkdownRendered && !_isEditing) {
      bodyContent = AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Markdown(
          key: const ValueKey('markdown_rendered'),
          data: _codeController.text,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge?.copyWith(color: colors.textPrimary),
            h1: theme.textTheme.displaySmall?.copyWith(color: colors.textPrimary),
            h2: theme.textTheme.headlineSmall?.copyWith(color: colors.textPrimary),
            h3: theme.textTheme.titleLarge?.copyWith(color: colors.textPrimary),
            code: TextStyle(
              fontFamily: settings.codeFont.fontFamily,
              color: colors.accentPrimary,
              backgroundColor: colors.surfaceCard,
            ),
            codeblockDecoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    } else {
      bodyContent = GestureDetector(
        onScaleStart: (_) {
          _baseScaleFontSize = settings.defaultFontSize;
        },
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            final newSize = (_baseScaleFontSize * details.scale).clamp(10.0, 28.0);
            final rounded = (newSize / 2).round() * 2.0;
            if (rounded != settings.defaultFontSize) {
              ref.read(settingsProvider.notifier).updateDefaultFontSize(rounded);
            }
          }
        },
        child: _buildCodeView(colors, settings, language),
      );
    }

    return ViewerShell(
      file: widget.file,
      warningBanner: warningBanner,
      customActions: customActions,
      isEditable: true,
      isEditing: _isEditing,
      isDirty: _isDirty,
      onToggleEdit: (editing) {
        setState(() {
          _isEditing = editing;
          if (editing && isMarkdown && _isMarkdownRendered) {
            _isMarkdownRendered = false; // Switch to source mode when editing
          }
        });
        if (editing) {
          _codeFocusNode.requestFocus();
        }
      },
      onSave: _saveFile,
      child: Column(
        children: [
          if (_isSearchActive)
            InViewerFindBar(
              controller: _searchController,
              matchCount: _matches.length,
              currentIndex: _currentMatchIndex,
              showReplace: _isEditing,
              replaceController: _replaceController,
              onReplace: _replaceCurrent,
              onReplaceAll: _replaceAll,
              onNext: () {
                if (_matches.isNotEmpty) {
                  final next = (_currentMatchIndex + 1) % _matches.length;
                  _scrollToMatch(next);
                }
              },
              onPrev: () {
                if (_matches.isNotEmpty) {
                  final prev = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
                  _scrollToMatch(prev);
                }
              },
              onClose: () {
                setState(() {
                  _isSearchActive = false;
                  _searchController.clear();
                  _replaceController.clear();
                  _matches = [];
                  _currentMatchIndex = -1;
                });
                _codeController.updateSettings(
                  newColors: colors,
                  newSearchQuery: '',
                  newMatchIndex: -1,
                );
              },
              onChanged: _performSearch,
            ),
          if (_isSearchActive && _matches.isNotEmpty && _currentMatchIndex >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colors.surfaceElevated,
              child: Row(
                children: [
                  Icon(Icons.find_in_page_outlined, size: 16, color: colors.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Match ${_currentMatchIndex + 1} of ${_matches.length}',
                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  Widget _buildCodeView(
    OpenFileColors colors,
    SettingsEntity settings,
    String? language,
  ) {
    final fontStyle = TextStyle(
      fontFamily: settings.codeFont.fontFamily,
      fontSize: settings.defaultFontSize,
      height: 1.5,
      color: colors.textPrimary,
    );

    final lineCount = '\n'.allMatches(_codeController.text).length + 1;
    final digits = lineCount.toString().length;
    final gutterWidth = (digits * 9.0 + 24.0).clamp(44.0, 80.0);

    // Gutter text for line numbers
    final gutterLines = List.generate(lineCount, (i) => '${i + 1}').join('\n');

    Widget editorField = TextField(
      controller: _codeController,
      focusNode: _codeFocusNode,
      readOnly: !_isEditing,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      style: fontStyle,
      cursorColor: colors.accentPrimary,
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );

    if (!_wordWrap) {
      editorField = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _horizontalController,
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 400),
            child: editorField,
          ),
        ),
      );
    }

    return Container(
      color: colors.surfaceRoot,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line Number Gutter
            Container(
              width: gutterWidth,
              padding: const EdgeInsets.only(top: 8, right: 8, left: 4),
              color: colors.surfaceApp.withValues(alpha: 0.5),
              child: Text(
                gutterLines,
                textAlign: TextAlign.right,
                style: fontStyle.copyWith(
                  fontSize: (settings.defaultFontSize * 0.85).clamp(10.0, 20.0),
                  color: colors.textDisabled,
                ),
              ),
            ),
            Container(width: 1, color: colors.divider),
            // Code / Text Field
            Expanded(child: editorField),
          ],
        ),
      ),
    );
  }
}

class _SearchMatch {
  final int charOffset;
  final int length;

  _SearchMatch({
    required this.charOffset,
    required this.length,
  });
}
