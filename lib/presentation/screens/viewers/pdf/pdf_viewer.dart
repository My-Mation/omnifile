import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../providers/shared_preferences_provider.dart';
import '../../../widgets/in_viewer_find_bar.dart';
import '../../../widgets/o_banner.dart';
import '../../../widgets/viewer_shell.dart';
import '../../editor/pdf_editor_screen.dart';

class _PdfSearchMatch {
  final int pageIndex;
  final String snippet;
  const _PdfSearchMatch({required this.pageIndex, required this.snippet});
}

class PdfViewer extends ConsumerStatefulWidget {
  final FileEntity file;

  const PdfViewer({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends ConsumerState<PdfViewer> {
  PDFViewController? _pdfViewController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;
  String? _errorMessage;
  String _password = '';
  int _passwordAttempts = 0;
  bool _isVertical = true;

  static const int _fiftyMb = 50 * 1024 * 1024;
  bool _showLargeFileNotice = false;

  // Search State
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<_PdfSearchMatch> _searchMatches = [];
  int _currentSearchIndex = -1;
  Map<int, String> _pageTextCache = {};

  @override
  void initState() {
    super.initState();
    _showLargeFileNotice = widget.file.size > _fiftyMb;
    _restoreLastPage();
    _startIndexing();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startIndexing() async {
    try {
      final map = await OcrService.instance.indexPdfAllPages(widget.file.path);
      if (mounted) {
        setState(() {
          _pageTextCache = map;
        });
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      }
    } catch (_) {}
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchMatches = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    final lower = query.toLowerCase();
    final matches = <_PdfSearchMatch>[];
    for (final entry in _pageTextCache.entries) {
      final pageIdx = entry.key;
      final text = entry.value;
      int start = 0;
      while (true) {
        final pos = text.toLowerCase().indexOf(lower, start);
        if (pos == -1) break;
        final snippetStart = (pos - 20).clamp(0, text.length);
        final snippetEnd = (pos + query.length + 30).clamp(0, text.length);
        final snippet = text.substring(snippetStart, snippetEnd).replaceAll('\n', ' ');
        matches.add(_PdfSearchMatch(pageIndex: pageIdx, snippet: '...$snippet...'));
        start = pos + query.length;
      }
    }

    setState(() {
      _searchMatches = matches;
      _currentSearchIndex = matches.isNotEmpty ? 0 : -1;
    });

    if (matches.isNotEmpty) {
      _pdfViewController?.setPage(matches[0].pageIndex);
    }
  }

  void _jumpToMatch(int index) {
    if (index >= 0 && index < _searchMatches.length) {
      setState(() => _currentSearchIndex = index);
      _pdfViewController?.setPage(_searchMatches[index].pageIndex);
    }
  }

  Future<void> _copyWholePage() async {
    String? text = _pageTextCache[_currentPage];
    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reading text on page...'), duration: Duration(seconds: 1)),
      );
      try {
        text = await OcrService.instance.extractOrOcrPdf(widget.file.path, pageIndex: _currentPage);
        if (text.isNotEmpty && !text.startsWith('No readable text')) {
          _pageTextCache[_currentPage] = text;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not extract text: $e')),
          );
        }
        return;
      }
    }

    if (text.isNotEmpty && !text.startsWith('No readable text')) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied page ${_currentPage + 1} text (${text.length} chars) to clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No readable text found on page ${_currentPage + 1}')),
        );
      }
    }
  }

  String get _prefKey => 'pdf_last_page_${widget.file.path.hashCode}';

  void _restoreLastPage() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedPage = prefs.getInt(_prefKey);
    if (savedPage != null && savedPage > 0) {
      _currentPage = savedPage;
    }
  }

  void _saveLastPage(int page) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_prefKey, page);
  }

  Future<void> _promptPassword({bool isRetry = false}) async {
    final colors = context.colors;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isRetry ? 'Incorrect password' : 'Password protected PDF',
          style: TextStyle(color: colors.textPrimary, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attempt ${_passwordAttempts + 1} of 3. Enter password to decrypt:',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: colors.textDisabled),
                filled: true,
                fillColor: colors.surfaceInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _passwordAttempts++;
      setState(() {
        _password = result;
        _errorMessage = null;
        _isReady = false;
      });
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showJumpToPageDialog() {
    final colors = context.colors;
    final controller = TextEditingController(text: '${_currentPage + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Jump to page', style: TextStyle(color: colors.textPrimary)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Page ', style: TextStyle(color: colors.textSecondary)),
            SizedBox(
              width: 60,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surfaceInput,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            Text(' of $_totalPages', style: TextStyle(color: colors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _pdfViewController?.setPage(page - 1);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Jump'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final customActions = <Widget>[
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Search in document',
        onPressed: () {
          setState(() {
            _isSearchActive = !_isSearchActive;
            if (!_isSearchActive) {
              _searchController.clear();
              _searchMatches = [];
              _currentSearchIndex = -1;
            }
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.copy_all),
        tooltip: 'Copy current page text',
        onPressed: _copyWholePage,
      ),
      IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit text in PDF',
        onPressed: () => PdfEditorScreen.open(context, widget.file, initialPage: _currentPage),
      ),
      IconButton(
        icon: Icon(_isVertical ? Icons.swap_horiz : Icons.swap_vert),
        tooltip: _isVertical ? 'Horizontal paging' : 'Vertical paging',
        onPressed: () {
          setState(() {
            _isVertical = !_isVertical;
          });
        },
      ),
      if (_isReady && _totalPages > 0)
        TextButton(
          onPressed: _showJumpToPageDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${_currentPage + 1} / $_totalPages',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
    ];

    Widget? warningBanner;
    if (_showLargeFileNotice) {
      warningBanner = OBanner.warning(
        text: 'Large PDF (${Formatters.formatFileSize(widget.file.size)}). Rendering may take a moment.',
        actionLabel: 'Dismiss',
        onAction: () => setState(() => _showLargeFileNotice = false),
      );
    }

    Widget content;
    if (_errorMessage != null) {
      content = Center(
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
                style: TextStyle(color: colors.textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 20),
              if (_passwordAttempts < 3)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentPrimary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _promptPassword(isRetry: true),
                  child: const Text('Enter password'),
                ),
            ],
          ),
        ),
      );
    } else {
      content = Stack(
        children: [
          PDFView(
            key: ValueKey('${widget.file.path}_${_isVertical}_$_password'),
            filePath: widget.file.path,
            password: _password.isNotEmpty ? _password : null,
            enableSwipe: true,
            swipeHorizontal: !_isVertical,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: _currentPage,
            fitPolicy: FitPolicy.BOTH,
            onRender: (pages) {
              setState(() {
                _totalPages = pages ?? 0;
                _isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                _errorMessage = error.toString();
              });
            },
            onPageError: (page, error) {
              setState(() {
                _errorMessage = 'Error on page $page: $error';
              });
            },
            onViewCreated: (PDFViewController controller) {
              _pdfViewController = controller;
            },
            onPageChanged: (int? page, int? total) {
              if (page != null) {
                setState(() {
                  _currentPage = page;
                });
                _saveLastPage(page);
              }
            },
          ),
          if (!_isReady)
            Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
              ),
            ),
        ],
      );
    }

    return ViewerShell(
      file: widget.file,
      warningBanner: warningBanner,
      customActions: customActions,
      child: Column(
        children: [
          if (_isSearchActive)
            InViewerFindBar(
              controller: _searchController,
              matchCount: _searchMatches.length,
              currentIndex: _currentSearchIndex,
              onNext: () {
                if (_searchMatches.isNotEmpty) {
                  _jumpToMatch((_currentSearchIndex + 1) % _searchMatches.length);
                }
              },
              onPrev: () {
                if (_searchMatches.isNotEmpty) {
                  _jumpToMatch(
                      (_currentSearchIndex - 1 + _searchMatches.length) % _searchMatches.length);
                }
              },
              onClose: () {
                setState(() {
                  _isSearchActive = false;
                  _searchController.clear();
                  _searchMatches = [];
                  _currentSearchIndex = -1;
                });
              },
              onChanged: _performSearch,
            ),
          if (_isSearchActive && _searchMatches.isNotEmpty && _currentSearchIndex >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colors.surfaceElevated,
              child: Row(
                children: [
                  Icon(Icons.find_in_page_outlined, size: 16, color: colors.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Match ${_currentSearchIndex + 1} of ${_searchMatches.length} (Page ${_searchMatches[_currentSearchIndex].pageIndex + 1}): "${_searchMatches[_currentSearchIndex].snippet}"',
                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(Icons.edit_outlined, size: 14, color: colors.accentPrimary),
                    label: Text('Highlight & Edit', style: TextStyle(color: colors.accentPrimary, fontSize: 11)),
                    onPressed: () {
                      PdfEditorScreen.open(
                        context,
                        widget.file,
                        initialPage: _searchMatches[_currentSearchIndex].pageIndex,
                        initialSearchQuery: _searchController.text,
                      );
                    },
                  ),
                ],
              ),
            ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
