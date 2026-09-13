import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../providers/shared_preferences_provider.dart';
import '../../../widgets/o_banner.dart';
import '../../../widgets/ocr_result_sheet.dart';
import '../../../widgets/viewer_shell.dart';

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

  @override
  void initState() {
    super.initState();
    _showLargeFileNotice = widget.file.size > _fiftyMb;
    _restoreLastPage();
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

  bool _isOcrRunning = false;

  Future<void> _runOcr({bool currentPageOnly = false, bool forceScan = false}) async {
    setState(() => _isOcrRunning = true);
    try {
      final text = await OcrService.instance.extractOrOcrPdf(
        widget.file.path,
        pageIndex: currentPageOnly ? _currentPage : null,
        forceScanOcr: forceScan,
      );
      if (!mounted) return;
      await OcrResultSheet.show(
        context,
        text: text,
        sourceFileName: widget.file.name,
        sourceFilePath: widget.file.path,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract text: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOcrRunning = false);
      }
    }
  }

  void _showOcrOptions(OpenFileColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OCR / Text Recognition',
                style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.document_scanner, color: colors.textPrimary),
                title: Text('OCR Current Page (${_currentPage + 1})', style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Scan and extract text from this book page', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _runOcr(currentPageOnly: true, forceScan: true);
                },
              ),
              ListTile(
                leading: Icon(Icons.auto_stories, color: colors.textPrimary),
                title: const Text('Extract / OCR Document'),
                subtitle: Text('Extract vector text or scan book pages with ML Kit', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _runOcr(currentPageOnly: false, forceScan: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final customActions = <Widget>[
      IconButton(
        icon: _isOcrRunning
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.document_scanner_outlined),
        tooltip: 'Extract / OCR text',
        onPressed: _isOcrRunning ? null : () => _showOcrOptions(colors),
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
      child: content,
    );
  }
}
