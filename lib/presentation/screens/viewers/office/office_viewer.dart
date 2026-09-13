import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../providers/detection_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/recents_provider.dart';
import 'package:flutter/services.dart';
import '../../../widgets/in_viewer_find_bar.dart';
import '../../../widgets/o_banner.dart';
import '../../../widgets/viewer_shell.dart';
import '../../viewer/viewer_router_screen.dart';
import 'docx_xml_editor.dart';
import 'xlsx_xml_editor.dart';

enum _OfficeSubtype { docx, xlsx, pptx, legacy }

class _OfficeSearchMatch {
  final String location;
  final String snippet;
  final VoidCallback onJump;
  const _OfficeSearchMatch({required this.location, required this.snippet, required this.onJump});
}

// ---------------------------------------------------------------------------
// DATA MODELS
// ---------------------------------------------------------------------------

class _XlsxSheet {
  final String name;
  final List<List<String>> rows;
  final int maxCols;

  const _XlsxSheet({
    required this.name,
    required this.rows,
    required this.maxCols,
  });
}

class _PptxSlide {
  final int index;
  final String title;
  final List<String> textBlocks;
  final List<Uint8List> images;

  const _PptxSlide({
    required this.index,
    required this.title,
    required this.textBlocks,
    this.images = const [],
  });
}

class _ParsedOfficeData {
  final _OfficeSubtype subtype;
  final List<dynamic> docxElements;
  final List<_XlsxSheet> xlsxSheets;
  final List<_PptxSlide> pptxSlides;
  final List<String> legacyParagraphs;
  final String? documentXml;
  final String? error;

  const _ParsedOfficeData({
    required this.subtype,
    this.docxElements = const [],
    this.xlsxSheets = const [],
    this.pptxSlides = const [],
    this.legacyParagraphs = const [],
    this.documentXml,
    this.error,
  });
}

// ---------------------------------------------------------------------------
// MAIN WIDGET
// ---------------------------------------------------------------------------

class OfficeViewer extends ConsumerStatefulWidget {
  final FileEntity file;

  const OfficeViewer({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<OfficeViewer> createState() => _OfficeViewerState();
}

class _OfficeViewerState extends ConsumerState<OfficeViewer> {
  bool _isLoading = true;
  String? _errorMessage;
  _OfficeSubtype _detectedSubtype = _OfficeSubtype.docx;

  List<dynamic> _docxElements = [];
  DocxXmlEditor? _docxXmlEditor;
  Uint8List _rawFileBytes = Uint8List(0);
  bool _isEditingDocx = false;
  bool _isDocxDirty = false;
  int? _activeParagraphIndex;
  final Map<int, TextEditingController> _docxControllers = {};

  List<_XlsxSheet> _xlsxSheets = [];
  XlsxXmlEditor? _xlsxXmlEditor;
  bool _isEditingXlsx = false;
  bool _isXlsxDirty = false;
  int _selectedSheetIndex = 0;
  int _selectedRowIndex = 0;
  int _selectedColIndex = 0;
  final TextEditingController _cellEditorController = TextEditingController();

  List<_PptxSlide> _pptxSlides = [];
  int _currentSlideIndex = 0;
  final PageController _slideController = PageController();

  List<String> _legacyParagraphs = [];

  // Search State
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<_OfficeSearchMatch> _searchMatches = [];
  int _currentSearchMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _cellEditorController.dispose();
    _searchController.dispose();
    for (final c in _docxControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDocument() async {
    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Document file not found on disk.';
          });
        }
        return;
      }

      final bytes = await file.readAsBytes();
      _rawFileBytes = bytes;
      if (bytes.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'File is empty (0 bytes).';
          });
        }
        return;
      }

      final ext = widget.file.extension.toLowerCase();
      // Parse document in background isolate to keep UI thread 100% responsive
      final parsed = await compute(_parseOfficeBytesEntry, _OfficeParseParams(bytes, ext));

      if (!mounted) return;

      if (parsed.error != null) {
        setState(() {
          _isLoading = false;
          _errorMessage = parsed.error;
        });
      } else {
        if (parsed.documentXml != null) {
          _docxXmlEditor = DocxXmlEditor.fromXmlString(parsed.documentXml!);
          _docxElements = _docxXmlEditor!.elements;
        } else {
          _docxElements = parsed.docxElements;
        }
        var sheets = parsed.xlsxSheets;
        if (parsed.subtype == _OfficeSubtype.xlsx) {
          if (ext == 'csv' || ext == 'tsv') {
            sheets = parsed.xlsxSheets;
            _selectedRowIndex = 0;
            _selectedColIndex = 0;
            if (sheets.isNotEmpty && sheets[0].rows.isNotEmpty && sheets[0].rows[0].isNotEmpty) {
              _cellEditorController.text = sheets[0].rows[0][0];
            }
          } else {
            try {
              _xlsxXmlEditor = XlsxXmlEditor.fromBytes(bytes);
              sheets = _xlsxXmlEditor!.sheets
                  .map((s) => _XlsxSheet(name: s.name, rows: s.grid, maxCols: s.colCount))
                  .toList();
              _selectedRowIndex = 0;
              _selectedColIndex = 0;
              if (sheets.isNotEmpty && sheets[0].rows.isNotEmpty && sheets[0].rows[0].isNotEmpty) {
                _cellEditorController.text = sheets[0].rows[0][0];
              }
            } catch (_) {
              sheets = parsed.xlsxSheets;
            }
          }
        }
        setState(() {
          _isLoading = false;
          _detectedSubtype = parsed.subtype;
          _xlsxSheets = sheets;
          _pptxSlides = parsed.pptxSlides;
          _legacyParagraphs = parsed.legacyParagraphs;
          _isDocxDirty = false;
          _isXlsxDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not open document: $e';
        });
      }
    }
  }

  List<InlineSpan> _buildHighlightedSpans(
    String text,
    String query,
    TextStyle normalStyle,
    TextStyle highlightStyle,
  ) {
    if (query.trim().isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return [TextSpan(text: text, style: normalStyle)];
    }

    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: normalStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: normalStyle));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle,
      ));

      start = index + query.length;
    }

    return spans;
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchMatches = [];
        _currentSearchMatchIndex = -1;
      });
      return;
    }

    final lower = query.toLowerCase();
    final matches = <_OfficeSearchMatch>[];

    if (_detectedSubtype == _OfficeSubtype.docx) {
      for (int i = 0; i < _docxElements.length; i++) {
        final elem = _docxElements[i];
        if (elem is DocxParagraphModel && elem.text.toLowerCase().contains(lower)) {
          final text = elem.text;
          final pos = text.toLowerCase().indexOf(lower);
          final snippet = text.substring(math.max(0, pos - 15), math.min(text.length, pos + query.length + 20)).replaceAll('\n', ' ');
          matches.add(_OfficeSearchMatch(
            location: 'Paragraph ${i + 1}',
            snippet: snippet,
            onJump: () {
              setState(() {
                _activeParagraphIndex = i;
              });
            },
          ));
        } else if (elem is DocxTableModel) {
          for (int r = 0; r < elem.rows.length; r++) {
            for (int c = 0; c < elem.rows[r].length; c++) {
              final cell = elem.rows[r][c];
              if (cell.text.toLowerCase().contains(lower)) {
                matches.add(_OfficeSearchMatch(
                  location: 'Table (Row ${r + 1}, Col ${c + 1})',
                  snippet: cell.text,
                  onJump: () {
                    _openDocxTableCellEditor(cell, context.colors);
                  },
                ));
              }
            }
          }
        }
      }
    } else if (_detectedSubtype == _OfficeSubtype.xlsx) {
      for (int sIdx = 0; sIdx < _xlsxSheets.length; sIdx++) {
        final sheet = _xlsxSheets[sIdx];
        for (int r = 0; r < sheet.rows.length; r++) {
          for (int c = 0; c < sheet.rows[r].length; c++) {
            final cellText = sheet.rows[r][c];
            if (cellText.toLowerCase().contains(lower)) {
              final colLetters = XlsxXmlEditor.indexToColLetters(c);
              matches.add(_OfficeSearchMatch(
                location: '${sheet.name} ($colLetters${r + 1})',
                snippet: cellText,
                onJump: () {
                  setState(() {
                    _selectedSheetIndex = sIdx;
                    _selectedRowIndex = r;
                    _selectedColIndex = c;
                    _cellEditorController.text = cellText;
                  });
                },
              ));
            }
          }
        }
      }
    } else if (_detectedSubtype == _OfficeSubtype.pptx) {
      for (int sIdx = 0; sIdx < _pptxSlides.length; sIdx++) {
        final slide = _pptxSlides[sIdx];
        if (slide.title.toLowerCase().contains(lower)) {
          matches.add(_OfficeSearchMatch(
            location: 'Slide ${sIdx + 1} (Title)',
            snippet: slide.title,
            onJump: () {
              setState(() => _currentSlideIndex = sIdx);
              _slideController.jumpToPage(sIdx);
            },
          ));
        }
        for (final block in slide.textBlocks) {
          if (block.toLowerCase().contains(lower)) {
            matches.add(_OfficeSearchMatch(
              location: 'Slide ${sIdx + 1}',
              snippet: block,
              onJump: () {
                setState(() => _currentSlideIndex = sIdx);
                _slideController.jumpToPage(sIdx);
              },
            ));
          }
        }
      }
    } else if (_detectedSubtype == _OfficeSubtype.legacy) {
      for (int i = 0; i < _legacyParagraphs.length; i++) {
        final p = _legacyParagraphs[i];
        if (p.toLowerCase().contains(lower)) {
          matches.add(_OfficeSearchMatch(
            location: 'Paragraph ${i + 1}',
            snippet: p,
            onJump: () {},
          ));
        }
      }
    }

    setState(() {
      _searchMatches = matches;
      _currentSearchMatchIndex = matches.isNotEmpty ? 0 : -1;
    });

    if (matches.isNotEmpty) {
      matches[0].onJump();
    }
  }

  void _copyWholeOfficeContent() async {
    final sb = StringBuffer();
    if (_detectedSubtype == _OfficeSubtype.docx) {
      for (final elem in _docxElements) {
        if (elem is DocxParagraphModel) {
          sb.writeln(elem.text);
        } else if (elem is DocxTableModel) {
          for (final row in elem.rows) {
            sb.writeln(row.map((c) => c.text).join('\t'));
          }
          sb.writeln();
        }
      }
    } else if (_detectedSubtype == _OfficeSubtype.xlsx) {
      if (_xlsxSheets.isNotEmpty) {
        final currentSheet = _xlsxSheets[_selectedSheetIndex];
        for (final row in currentSheet.rows) {
          sb.writeln(row.join('\t'));
        }
      }
    } else if (_detectedSubtype == _OfficeSubtype.pptx) {
      for (final slide in _pptxSlides) {
        sb.writeln('[Slide ${slide.index}] ${slide.title}');
        for (final block in slide.textBlocks) {
          sb.writeln('• $block');
        }
        sb.writeln();
      }
    } else if (_detectedSubtype == _OfficeSubtype.legacy) {
      for (final p in _legacyParagraphs) {
        sb.writeln(p);
      }
    }

    final allText = sb.toString().trim();
    if (allText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: allText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied document content (${allText.length} chars) to clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text to copy')),
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // UI BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget body;
    if (_isLoading) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
            ),
            const SizedBox(height: 16),
            Text('Rendering document offline...', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 56, color: colors.stateError),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary, fontSize: 15)),
            ],
          ),
        ),
      );
    } else {
      switch (_detectedSubtype) {
        case _OfficeSubtype.docx:
          body = _buildDocxView(colors);
          break;
        case _OfficeSubtype.xlsx:
          body = _buildXlsxView(colors);
          break;
        case _OfficeSubtype.pptx:
          body = _buildPptxView(colors);
          break;
        case _OfficeSubtype.legacy:
          body = _buildLegacyView(colors);
          break;
      }
    }

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
              _currentSearchMatchIndex = -1;
            }
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.copy_all),
        tooltip: 'Copy whole document',
        onPressed: _copyWholeOfficeContent,
      ),
    ];

    final isDocx = _detectedSubtype == _OfficeSubtype.docx;
    final isXlsx = _detectedSubtype == _OfficeSubtype.xlsx;
    final isEditable = isDocx || isXlsx;
    final isEditing = isDocx ? _isEditingDocx : (isXlsx ? _isEditingXlsx : false);
    final isDirty = isDocx ? _isDocxDirty : (isXlsx ? _isXlsxDirty : false);

    return ViewerShell(
      file: widget.file,
      customActions: customActions,
      isEditable: isEditable,
      isEditing: isEditing,
      isDirty: isDirty,
      onToggleEdit: (val) {
        setState(() {
          if (isDocx) {
            _isEditingDocx = val;
            if (!val) _activeParagraphIndex = null;
          } else if (isXlsx) {
            _isEditingXlsx = val;
          }
        });
      },
      onSave: () async {
        if (isDocx) return await _saveEditedDocx();
        if (isXlsx) return await _saveEditedXlsx();
        return false;
      },
      noticeBanner: OBanner.notice(
        text: 'Document Preview — formatted offline.',
      ),
      child: Column(
        children: [
          if (_isSearchActive)
            InViewerFindBar(
              controller: _searchController,
              matchCount: _searchMatches.length,
              currentIndex: _currentSearchMatchIndex,
              onNext: () {
                if (_searchMatches.isNotEmpty) {
                  final nextIdx = (_currentSearchMatchIndex + 1) % _searchMatches.length;
                  setState(() => _currentSearchMatchIndex = nextIdx);
                  _searchMatches[nextIdx].onJump();
                }
              },
              onPrev: () {
                if (_searchMatches.isNotEmpty) {
                  final prevIdx =
                      (_currentSearchMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
                  setState(() => _currentSearchMatchIndex = prevIdx);
                  _searchMatches[prevIdx].onJump();
                }
              },
              onClose: () {
                setState(() {
                  _isSearchActive = false;
                  _searchController.clear();
                  _searchMatches = [];
                  _currentSearchMatchIndex = -1;
                });
              },
              onChanged: _performSearch,
            ),
          if (_isSearchActive && _searchMatches.isNotEmpty && _currentSearchMatchIndex >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colors.surfaceElevated,
              child: Row(
                children: [
                  Icon(Icons.find_in_page_outlined, size: 16, color: colors.accentPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Match ${_currentSearchMatchIndex + 1} of ${_searchMatches.length} (${_searchMatches[_currentSearchMatchIndex].location}): "${_searchMatches[_currentSearchMatchIndex].snippet}"',
                      style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  void _syncXlsxState() {
    if (_xlsxXmlEditor == null) return;
    setState(() {
      _xlsxSheets = _xlsxXmlEditor!.sheets
          .map((s) => _XlsxSheet(name: s.name, rows: s.grid, maxCols: s.colCount))
          .toList();
      _isXlsxDirty = _xlsxXmlEditor!.isDirty;
    });
  }

  Future<bool> _saveEditedXlsx() async {
    try {
      final ext = widget.file.extension.toLowerCase();
      Uint8List newBytes;
      String targetExt;
      if (ext == 'csv' || ext == 'tsv') {
        targetExt = ext;
        final separator = ext == 'tsv' ? '\t' : ',';
        final sb = StringBuffer();
        if (_xlsxSheets.isNotEmpty) {
          final targetSheet = _xlsxSheets.length > _selectedSheetIndex ? _xlsxSheets[_selectedSheetIndex] : _xlsxSheets[0];
          for (final row in targetSheet.rows) {
            final formattedRow = row.map((cell) {
              if (cell.contains(separator) || cell.contains('"') || cell.contains('\n')) {
                return '"${cell.replaceAll('"', '""')}"';
              }
              return cell;
            }).join(separator);
            sb.writeln(formattedRow);
          }
        }
        newBytes = Uint8List.fromList(utf8.encode(sb.toString()));
      } else {
        if (_xlsxXmlEditor == null) return false;
        targetExt = 'xlsx';
        newBytes = _xlsxXmlEditor!.buildArchiveBytes();
      }

      final originalFile = File(widget.file.path);
      final parentDir = originalFile.parent.path;
      final originalName = widget.file.name;
      final nameWithoutExt = originalName.contains('.')
          ? originalName.substring(0, originalName.lastIndexOf('.'))
          : originalName;

      String newFileName = '$nameWithoutExt (edited).$targetExt';
      String newFilePath = p.join(parentDir, newFileName);
      int counter = 2;
      while (await File(newFilePath).exists()) {
        newFileName = '$nameWithoutExt (edited) ($counter).$targetExt';
        newFilePath = p.join(parentDir, newFileName);
        counter++;
      }

      await File(newFilePath).writeAsBytes(newBytes);

      setState(() {
        _isXlsxDirty = false;
        _rawFileBytes = newBytes;
      });

      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final newEntity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: newBytes.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(newEntity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $newFileName'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () {
                ViewerRouterScreen.open(context, newEntity);
              },
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save XLSX: $e')),
        );
      }
      return false;
    }
  }

  void _insertDocxParagraphAfter(int index) {
    if (_docxXmlEditor == null) return;
    _docxXmlEditor!.insertParagraphAfter(index, initialText: 'New paragraph');
    setState(() {
      _docxElements = List.from(_docxXmlEditor!.paragraphs);
      _isDocxDirty = true;
      _activeParagraphIndex = index + 1;
    });
  }

  void _mergeDocxWithPrevious(int index) {
    if (_docxXmlEditor == null || index <= 0) return;
    _docxXmlEditor!.mergeWithPrevious(index);
    setState(() {
      _docxElements = List.from(_docxXmlEditor!.paragraphs);
      _isDocxDirty = true;
      _activeParagraphIndex = index - 1;
    });
  }

  Future<bool> _saveEditedDocx() async {
    try {
      if (_docxXmlEditor == null) return false;
      final updatedXml = _docxXmlEditor!.buildXml();

      final originalArchive = ZipDecoder().decodeBytes(_rawFileBytes);
      final newArchive = Archive();
      for (final f in originalArchive.files) {
        if (f.name.toLowerCase() != 'word/document.xml' && !f.name.toLowerCase().endsWith('document.xml')) {
          newArchive.addFile(f);
        }
      }
      newArchive.addFile(ArchiveFile.string('word/document.xml', updatedXml));

      final newBytes = Uint8List.fromList(ZipEncoder().encode(newArchive));

      final originalFile = File(widget.file.path);
      final parentDir = originalFile.parent.path;
      final originalName = widget.file.name;
      final nameWithoutExt = originalName.contains('.')
          ? originalName.substring(0, originalName.lastIndexOf('.'))
          : originalName;

      String newFileName = '$nameWithoutExt (edited).docx';
      String newFilePath = p.join(parentDir, newFileName);
      int counter = 2;
      while (await File(newFilePath).exists()) {
        newFileName = '$nameWithoutExt (edited) ($counter).docx';
        newFilePath = p.join(parentDir, newFileName);
        counter++;
      }

      await File(newFilePath).writeAsBytes(newBytes);

      setState(() {
        _isDocxDirty = false;
        _rawFileBytes = newBytes;
      });

      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final newEntity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: newBytes.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(newEntity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $newFileName'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () {
                ViewerRouterScreen.open(context, newEntity);
              },
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save DOCX: $e')),
        );
      }
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // DOCX VIEW
  // --------------------------------------------------------------------------
  Widget _buildDocxView(OpenFileColors colors) {
    if (_docxElements.isEmpty) {
      return Center(
        child: Text('Document has no readable text', style: TextStyle(color: colors.textSecondary)),
      );
    }

    return Container(
      color: colors.surfaceRoot,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: _docxElements.length,
        itemBuilder: (context, index) {
          final elem = _docxElements[index];

          if (elem is DocxParagraphModel) {
            final isCurrentActive = _isEditingDocx && _activeParagraphIndex == index;

            if (isCurrentActive) {
              final controller = _docxControllers.putIfAbsent(
                index,
                () => TextEditingController(text: elem.text),
              );
              if (controller.text != elem.text) {
                controller.text = elem.text;
              }

              return Card(
                key: ValueKey('docx_p_edit_$index'),
                color: colors.surfaceElevated,
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.accentPrimary, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.accentPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              elem.isHeading
                                  ? 'Heading ${elem.headingLevel}'
                                  : (elem.isBullet ? 'Bullet point' : 'Paragraph ${index + 1}'),
                              style: TextStyle(
                                color: colors.accentPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add, size: 20),
                            tooltip: 'Insert paragraph after',
                            onPressed: () => _insertDocxParagraphAfter(index),
                          ),
                          if (index > 0)
                            IconButton(
                              icon: const Icon(Icons.merge_type, size: 20),
                              tooltip: 'Merge with previous',
                              onPressed: () => _mergeDocxWithPrevious(index),
                            ),
                          IconButton(
                            icon: const Icon(Icons.check, size: 20),
                            tooltip: 'Done editing',
                            color: colors.accentPrimary,
                            onPressed: () {
                              setState(() => _activeParagraphIndex = null);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        maxLines: null,
                        autofocus: true,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: elem.isHeading
                              ? (elem.headingLevel == 1 ? 22.0 : 18.0)
                              : 15.0,
                          fontWeight: elem.isBold || elem.isHeading
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
                          height: 1.5,
                        ),
                        cursorColor: colors.accentPrimary,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Type paragraph content…',
                        ),
                        onChanged: (val) {
                          elem.text = val;
                          _docxXmlEditor?.updateParagraphText(index, val);
                          _isDocxDirty = true;
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            // Normal preview item (tap to edit inline)
            final searchQuery = _isSearchActive ? _searchController.text : '';
            final hlStyle = TextStyle(
              backgroundColor: colors.surfaceElevated,
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            );

            Widget content;
            if (elem.isHeading) {
              final fontSize = elem.headingLevel == 1 ? 22.0 : (elem.headingLevel == 2 ? 18.0 : 16.0);
              final baseStyle = TextStyle(
                color: colors.accentPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                height: 1.3,
              );
              content = RichText(
                text: TextSpan(
                  children: _buildHighlightedSpans(
                    elem.text,
                    searchQuery,
                    baseStyle,
                    hlStyle.copyWith(fontSize: fontSize, color: colors.accentPrimary),
                  ),
                ),
              );
            } else if (elem.isBullet) {
              final baseStyle = TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                height: 1.5,
                fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
              );
              content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: colors.accentPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: _buildHighlightedSpans(elem.text, searchQuery, baseStyle, hlStyle),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              final baseStyle = TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                height: 1.6,
                fontWeight: elem.isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: elem.isItalic ? FontStyle.italic : FontStyle.normal,
              );
              content = RichText(
                text: TextSpan(
                  children: _buildHighlightedSpans(elem.text, searchQuery, baseStyle, hlStyle),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() {
                    _isEditingDocx = true;
                    _activeParagraphIndex = index;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: content,
                ),
              ),
            );
          } else if (elem is DocxTableModel) {
            final searchQuery = _isSearchActive ? _searchController.text.trim().toLowerCase() : '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  border: TableBorder.all(color: colors.divider, width: 0.8, borderRadius: BorderRadius.circular(6)),
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: elem.rows.map((row) {
                    return TableRow(
                      decoration: BoxDecoration(color: colors.surfaceCard),
                      children: row.map((cell) {
                        final isMatch = searchQuery.isNotEmpty && cell.text.toLowerCase().contains(searchQuery);
                        return InkWell(
                          onTap: () => _openDocxTableCellEditor(cell, colors),
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 64, minHeight: 40),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: isMatch
                                ? BoxDecoration(
                                    color: colors.surfaceElevated,
                                    border: Border.all(color: colors.accentPrimary, width: 1.5),
                                  )
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    cell.text.isNotEmpty ? cell.text : ' ',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: isMatch ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.edit_outlined, size: 13, color: colors.textSecondary.withValues(alpha: 0.6)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _openDocxTableCellEditor(DocxTableCellModel cell, OpenFileColors colors) {
    final controller = TextEditingController(text: cell.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Edit Table Cell (Row ${cell.rowIndex + 1}, Col ${cell.colIndex + 1})',
          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Cell text...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentPrimary,
              foregroundColor: colors.accentOnAccent,
            ),
            onPressed: () {
              final newText = controller.text.trim();
              setState(() {
                cell.text = newText;
                _docxXmlEditor?.updateTableCell(cell, newText);
                _isDocxDirty = true;
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // XLSX VIEW (VIRTUALIZED HIGH-PERFORMANCE GRID)
  // --------------------------------------------------------------------------
  Widget _buildXlsxView(OpenFileColors colors) {
    if (_xlsxSheets.isEmpty) {
      return Center(child: Text('No spreadsheet data found', style: TextStyle(color: colors.textSecondary)));
    }

    final currentSheet = _xlsxSheets[_selectedSheetIndex];
    const double colWidth = 120.0;
    const double indexWidth = 48.0;
    const double rowHeight = 40.0;
    final totalWidth = indexWidth + (currentSheet.maxCols * colWidth);
    final activeColName = XlsxXmlEditor.indexToColLetters(_selectedColIndex);
    final activeRowName = '${_selectedRowIndex + 1}';

    return Column(
      children: [
        // Sheet selector tabs
        if (_xlsxSheets.length > 1)
          Container(
            height: 44,
            color: colors.surfaceApp,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _xlsxSheets.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedSheetIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_xlsxSheets[index].name),
                    selected: isSelected,
                    selectedColor: colors.surfaceElevated,
                    backgroundColor: colors.surfaceCard,
                    labelStyle: TextStyle(
                      color: isSelected ? colors.textPrimary : colors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: isSelected ? colors.textPrimary : colors.divider, width: 0.5),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedSheetIndex = index;
                          _selectedRowIndex = 0;
                          _selectedColIndex = 0;
                          final s = _xlsxSheets[index];
                          _cellEditorController.text = (s.rows.isNotEmpty && s.rows[0].isNotEmpty) ? s.rows[0][0] : '';
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),

        // Formula / Active Cell Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
          ),
          child: Row(
            children: [
              // Coordinate Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.divider, width: 0.5),
                ),
                child: Text(
                  '$activeColName$activeRowName',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Cell Value Live Input Field
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceInput,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.divider, width: 0.5),
                  ),
                  child: TextField(
                    controller: _cellEditorController,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Edit cell value...',
                      hintStyle: TextStyle(color: colors.textDisabled, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (val) {
                      _xlsxXmlEditor?.updateCell(_selectedSheetIndex, _selectedRowIndex, _selectedColIndex, val);
                      if (_selectedRowIndex < currentSheet.rows.length &&
                          _selectedColIndex < currentSheet.rows[_selectedRowIndex].length) {
                        currentSheet.rows[_selectedRowIndex][_selectedColIndex] = val;
                      }
                      _isXlsxDirty = true;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Clear Cell Button
              IconButton(
                icon: const Icon(Icons.backspace_outlined, size: 16),
                tooltip: 'Clear Cell',
                color: colors.textSecondary,
                onPressed: () {
                  _cellEditorController.clear();
                  _xlsxXmlEditor?.clearCell(_selectedSheetIndex, _selectedRowIndex, _selectedColIndex);
                  if (_selectedRowIndex < currentSheet.rows.length &&
                      _selectedColIndex < currentSheet.rows[_selectedRowIndex].length) {
                    currentSheet.rows[_selectedRowIndex][_selectedColIndex] = '';
                  }
                  _isXlsxDirty = true;
                  setState(() {});
                },
              ),
              // Expand Full Dialog
              IconButton(
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                tooltip: 'Expand Cell Editor',
                color: colors.textSecondary,
                onPressed: () => _openCellEditorDialog(colors),
              ),
            ],
          ),
        ),

        // Spreadsheet Structural Action Bar
        Container(
          height: 38,
          color: colors.surfaceApp,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildSpreadsheetBtn(
                label: '+ Row',
                icon: Icons.add,
                colors: colors,
                onPressed: () {
                  _xlsxXmlEditor?.insertRow(_selectedSheetIndex, _selectedRowIndex + 1);
                  _syncXlsxState();
                },
              ),
              _buildSpreadsheetBtn(
                label: '- Row',
                icon: Icons.remove,
                colors: colors,
                onPressed: () {
                  _xlsxXmlEditor?.deleteRow(_selectedSheetIndex, _selectedRowIndex);
                  _syncXlsxState();
                },
              ),
              _buildSpreadsheetBtn(
                label: '+ Col',
                icon: Icons.add,
                colors: colors,
                onPressed: () {
                  _xlsxXmlEditor?.insertColumn(_selectedSheetIndex, _selectedColIndex + 1);
                  _syncXlsxState();
                },
              ),
              _buildSpreadsheetBtn(
                label: '- Col',
                icon: Icons.remove,
                colors: colors,
                onPressed: () {
                  _xlsxXmlEditor?.deleteColumn(_selectedSheetIndex, _selectedColIndex);
                  _syncXlsxState();
                },
              ),
              _buildSpreadsheetBtn(
                label: '+ 5 Rows',
                icon: Icons.playlist_add,
                colors: colors,
                onPressed: () {
                  _xlsxXmlEditor?.appendRows(_selectedSheetIndex, 5);
                  _syncXlsxState();
                },
              ),
            ],
          ),
        ),

        // Horizontal Scroll wrapper containing sticky header + virtualized row list
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Column(
                children: [
                  // Sticky Column Header (A, B, C, ...)
                  Container(
                    height: 34,
                    color: colors.surfaceElevated,
                    child: Row(
                      children: [
                        Container(
                          width: indexWidth,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: colors.divider, width: 0.5),
                              bottom: BorderSide(color: colors.divider, width: 1.0),
                            ),
                          ),
                          child: Text('#', style: TextStyle(color: colors.textDisabled, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        ...List.generate(currentSheet.maxCols, (colIdx) {
                          final isColSelected = colIdx == _selectedColIndex;
                          return Container(
                            width: colWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isColSelected ? colors.surfaceCard : Colors.transparent,
                              border: Border(
                                right: BorderSide(color: colors.divider, width: 0.5),
                                bottom: BorderSide(
                                  color: isColSelected ? colors.textPrimary : colors.divider,
                                  width: isColSelected ? 2.0 : 1.0,
                                ),
                              ),
                            ),
                            child: Text(
                              XlsxXmlEditor.indexToColLetters(colIdx),
                              style: TextStyle(
                                color: isColSelected ? colors.textPrimary : colors.textSecondary,
                                fontSize: 12,
                                fontWeight: isColSelected ? FontWeight.bold : FontWeight.w600,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  // Virtualized Row List (60fps on 1,000+ rows)
                  Expanded(
                    child: ListView.builder(
                      itemCount: currentSheet.rows.length,
                      itemExtent: rowHeight,
                      itemBuilder: (context, rowIdx) {
                        final rowData = currentSheet.rows[rowIdx];
                        final isRowSelected = rowIdx == _selectedRowIndex;
                        final isEven = rowIdx % 2 == 0;
                        final rowColor = isEven ? colors.surfaceApp : colors.surfaceCard;

                        return Container(
                          height: rowHeight,
                          color: rowColor,
                          child: Row(
                            children: [
                              // Row number index
                              Container(
                                width: indexWidth,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isRowSelected ? colors.surfaceElevated : Colors.transparent,
                                  border: Border(
                                    right: BorderSide(
                                      color: isRowSelected ? colors.textPrimary : colors.divider,
                                      width: isRowSelected ? 1.5 : 0.5,
                                    ),
                                    bottom: BorderSide(color: colors.divider, width: 0.5),
                                  ),
                                ),
                                child: Text(
                                  '${rowIdx + 1}',
                                  style: TextStyle(
                                    color: isRowSelected ? colors.textPrimary : colors.textDisabled,
                                    fontSize: 11,
                                    fontWeight: isRowSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              // Cells
                              ...List.generate(currentSheet.maxCols, (colIdx) {
                                final text = colIdx < rowData.length ? rowData[colIdx] : '';
                                final isCellSelected = rowIdx == _selectedRowIndex && colIdx == _selectedColIndex;
                                final searchQuery = _isSearchActive ? _searchController.text.trim().toLowerCase() : '';
                                final isSearchMatch = searchQuery.isNotEmpty && text.toLowerCase().contains(searchQuery);

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedRowIndex = rowIdx;
                                      _selectedColIndex = colIdx;
                                      _cellEditorController.text = text;
                                    });
                                  },
                                  onDoubleTap: () => _openCellEditorDialog(colors),
                                  child: Container(
                                    width: colWidth,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      color: isCellSelected
                                          ? colors.surfaceElevated
                                          : (isSearchMatch ? colors.surfaceElevated.withValues(alpha: 0.5) : Colors.transparent),
                                      border: Border.all(
                                        color: isCellSelected
                                            ? colors.textPrimary
                                            : (isSearchMatch ? colors.accentPrimary : colors.divider),
                                        width: (isCellSelected || isSearchMatch) ? 1.5 : 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: (isCellSelected || isSearchMatch) ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpreadsheetBtn({
    required String label,
    required IconData icon,
    required OpenFileColors colors,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 13),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.divider, width: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          minimumSize: const Size(0, 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _openCellEditorDialog(OpenFileColors colors) {
    if (_xlsxSheets.isEmpty || _selectedSheetIndex >= _xlsxSheets.length) return;
    final currentSheet = _xlsxSheets[_selectedSheetIndex];
    final colName = XlsxXmlEditor.indexToColLetters(_selectedColIndex);
    final rowName = '${_selectedRowIndex + 1}';
    final dialogController = TextEditingController(text: _cellEditorController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Cell $colName$rowName', style: TextStyle(color: colors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: dialogController,
          maxLines: 4,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter cell text or formula...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.textPrimary,
              foregroundColor: colors.surfaceRoot,
            ),
            onPressed: () {
              final newText = dialogController.text;
              _cellEditorController.text = newText;
              _xlsxXmlEditor?.updateCell(_selectedSheetIndex, _selectedRowIndex, _selectedColIndex, newText);
              if (_selectedRowIndex < currentSheet.rows.length &&
                  _selectedColIndex < currentSheet.rows[_selectedRowIndex].length) {
                currentSheet.rows[_selectedRowIndex][_selectedColIndex] = newText;
              }
              _isXlsxDirty = true;
              setState(() {});
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PPTX VIEW (FULL SLIDE DECK WITH IMAGES & TEXT)
  // --------------------------------------------------------------------------
  Widget _buildPptxView(OpenFileColors colors) {
    if (_pptxSlides.isEmpty) {
      return Center(child: Text('No presentation slides found', style: TextStyle(color: colors.textSecondary)));
    }

    return Column(
      children: [
        // Slide carousel
        Expanded(
          child: PageView.builder(
            controller: _slideController,
            itemCount: _pptxSlides.length,
            onPageChanged: (page) => setState(() => _currentSlideIndex = page),
            itemBuilder: (context, index) {
              final slide = _pptxSlides[index];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.divider, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Slide Header Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                          border: Border(bottom: BorderSide(color: colors.divider)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colors.accentPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'SLIDE ${slide.index} OF ${_pptxSlides.length}',
                                style: TextStyle(
                                  color: colors.accentPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Edit Slide'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.accentPrimary,
                                side: BorderSide(color: colors.accentPrimary.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: const Size(0, 32),
                              ),
                              onPressed: () => _editPptxSlide(slide),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.slideshow_rounded, size: 20, color: colors.textSecondary),
                          ],
                        ),
                      ),
                      // Slide Content (Scrollable card content)
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Slide Title
                            if (slide.title.isNotEmpty) ...[
                              SelectableText(
                                slide.title,
                                style: TextStyle(
                                  color: colors.accentPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                            ],
                            // Embedded Slide Images
                            if (slide.images.isNotEmpty) ...[
                              ...slide.images.map((imgBytes) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      imgBytes,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                            // Text Blocks & Paragraphs
                            ...slide.textBlocks.map((text) {
                              final isBullet = text.startsWith('•') || text.startsWith('-');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isBullet) ...[
                                      Text('• ', style: TextStyle(color: colors.accentPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                    Expanded(
                                      child: SelectableText(
                                        text,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 15,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (slide.textBlocks.isEmpty && slide.images.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Center(
                                  child: Text('(Slide has no textual or graphic content)', style: TextStyle(color: colors.textDisabled, fontSize: 13)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Slide Navigation Bottom Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: colors.surfaceApp,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                onPressed: _currentSlideIndex > 0
                    ? () {
                        _slideController.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.divider),
                ),
                child: Text(
                  '${_currentSlideIndex + 1} / ${_pptxSlides.length}',
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                onPressed: _currentSlideIndex < _pptxSlides.length - 1
                    ? () {
                        _slideController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // LEGACY OLE VIEW (.doc, .xls, .ppt)
  // --------------------------------------------------------------------------
  Widget _buildLegacyView(OpenFileColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _legacyParagraphs.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SelectableText(
            _legacyParagraphs[index],
            style: TextStyle(color: colors.textPrimary, fontSize: 14, height: 1.5),
          ),
        );
      },
    );
  }

  Future<void> _editPptxSlide(_PptxSlide slide) async {
    final titleController = TextEditingController(text: slide.title);
    final bulletControllers = slide.textBlocks.map((t) => TextEditingController(text: t)).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Slide ${slide.index}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Slide Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bullet Points / Text:', style: TextStyle(fontWeight: FontWeight.w600)),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Point'),
                          onPressed: () {
                            setSheetState(() {
                              bulletControllers.add(TextEditingController());
                            });
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: bulletControllers.length,
                        itemBuilder: (ctx, idx) {
                          final colors = Theme.of(ctx).extension<OpenFileColors>() ?? OpenFileColors.dark;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: bulletControllers[idx],
                                    decoration: InputDecoration(
                                      hintText: 'Point ${idx + 1}',
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: colors.textSecondary),
                                  onPressed: () {
                                    setSheetState(() {
                                      bulletControllers.removeAt(idx);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save as New PPTX'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.accentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _saveEditedPptx(
                            slideIndex: slide.index,
                            newTitle: titleController.text,
                            newBullets: bulletControllers.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveEditedPptx({
    required int slideIndex,
    required String newTitle,
    required List<String> newBullets,
  }) async {
    try {
      final file = File(widget.file.path);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find the slide file in the archive
      final slideTargetName = 'ppt/slides/slide$slideIndex.xml';
      final slideFile = archive.files.firstWhere(
        (f) => f.name.replaceAll('\\', '/').toLowerCase() == slideTargetName,
        orElse: () => archive.files.firstWhere((f) => f.name.contains('slide$slideIndex.xml')),
      );

      final xmlStr = utf8.decode(slideFile.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(xmlStr);

      // Update text nodes
      final tNodes = _findLocalElements(doc, 't').toList();
      if (tNodes.isNotEmpty) {
        tNodes.first.innerText = newTitle;
      }
      for (int i = 0; i < newBullets.length; i++) {
        if (i + 1 < tNodes.length) {
          tNodes[i + 1].innerText = newBullets[i];
        }
      }

      // Re-encode slide XML and replace in archive
      archive.add(ArchiveFile.string(slideFile.name, doc.toXmlString()));

      // Re-zip entire archive with pure Dart ZipEncoder
      final newArchiveBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      // Golden Save Rule (§1.1): Write to new file
      final originalFile = File(widget.file.path);
      final parentDir = originalFile.parent.path;
      final originalNameNoExt = widget.file.name.contains('.')
          ? widget.file.name.substring(0, widget.file.name.lastIndexOf('.'))
          : widget.file.name;

      String newFileName = '$originalNameNoExt (edited).pptx';
      String newFilePath = '$parentDir/$newFileName';
      int counter = 2;
      while (File(newFilePath).existsSync()) {
        newFileName = '$originalNameNoExt (edited) ($counter).pptx';
        newFilePath = '$parentDir/$newFileName';
        counter++;
      }

      final newFile = File(newFilePath);
      await newFile.writeAsBytes(newArchiveBytes);

      final detector = ref.read(detectFileTypeUseCaseProvider);
      final detected = await detector(newFilePath, originalFileName: newFileName);

      final newEntity = FileEntity(
        path: newFilePath,
        name: newFileName,
        size: newArchiveBytes.length,
        lastModified: DateTime.now(),
        detectedType: detected,
      );

      await ref.read(recentsProvider.notifier).addFile(newEntity);
      ref.read(libraryProvider.notifier).scanLibrary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as new PPTX: $newFileName'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () {
                ViewerRouterScreen.open(context, newEntity);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save edited PPTX: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// BACKGROUND PARSER FUNCTIONS (RUNS IN ISOLATE)
// ---------------------------------------------------------------------------

class _OfficeParseParams {
  final Uint8List bytes;
  final String extension;
  const _OfficeParseParams(this.bytes, this.extension);
}

_ParsedOfficeData _parseOfficeBytesEntry(_OfficeParseParams params) {
  return _parseOfficeBytes(params.bytes, params.extension);
}

Iterable<XmlElement> _findLocalElements(XmlNode node, String localName) {
  return node.descendantElements.where((e) => e.name.local.toLowerCase() == localName.toLowerCase());
}

_ParsedOfficeData _parseCsv(Uint8List bytes, {bool isTsv = false}) {
  try {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = latin1.decode(bytes);
    }
    final separator = isTsv ? '\t' : (text.contains(';') && !text.contains(',') ? ';' : ',');
    final lines = const LineSplitter().convert(text);
    final rows = <List<String>>[];
    int maxCols = 1;

    for (final line in lines) {
      if (line.isEmpty && rows.isEmpty) continue;
      final row = <String>[];
      final sb = StringBuffer();
      bool insideQuote = false;

      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          if (insideQuote && i + 1 < line.length && line[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            insideQuote = !insideQuote;
          }
        } else if (char == separator && !insideQuote) {
          row.add(sb.toString());
          sb.clear();
        } else {
          sb.write(char);
        }
      }
      row.add(sb.toString());
      if (row.length > maxCols) maxCols = row.length;
      rows.add(row);
    }

    if (rows.isEmpty) {
      rows.add(['']);
    }

    for (int r = 0; r < rows.length; r++) {
      while (rows[r].length < maxCols) {
        rows[r].add('');
      }
    }

    final sheet = _XlsxSheet(
      name: isTsv ? 'TSV Data' : 'CSV Data',
      rows: rows,
      maxCols: maxCols,
    );

    return _ParsedOfficeData(
      subtype: _OfficeSubtype.xlsx,
      xlsxSheets: [sheet],
    );
  } catch (e) {
    return _ParsedOfficeData(
      subtype: _OfficeSubtype.legacy,
      error: 'Failed to parse CSV spreadsheet: $e',
    );
  }
}

_ParsedOfficeData _parseOfficeBytes(Uint8List bytes, String extension) {
  try {
    final ext = extension.toLowerCase();
    // 0. CSV / TSV handling
    if (ext == 'csv' || ext == 'tsv') {
      return _parseCsv(bytes, isTsv: ext == 'tsv');
    }

    // 1. OLE Compound File Header (.doc, .xls, .ppt)
    if (bytes.length >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      final legacyText = _extractLegacyStrings(bytes);
      return _ParsedOfficeData(
        subtype: _OfficeSubtype.legacy,
        legacyParagraphs: legacyText,
      );
    }

    // 2. Try decoding as ZIP archive
    Archive? archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      final legacyText = _extractLegacyStrings(bytes);
      return _ParsedOfficeData(
        subtype: _OfficeSubtype.legacy,
        legacyParagraphs: legacyText,
      );
    }

    final normalizedArchive = <String, ArchiveFile>{};
    for (final f in archive.files) {
      final norm = f.name.replaceAll('\\', '/').toLowerCase();
      normalizedArchive[norm] = f;
    }

    if (ext == 'xlsx' || normalizedArchive.keys.any((k) => k.contains('xl/'))) {
      return _parseXlsx(normalizedArchive);
    } else if (ext == 'pptx' || normalizedArchive.keys.any((k) => k.contains('ppt/'))) {
      return _parsePptx(normalizedArchive);
    } else if (ext == 'docx' || normalizedArchive.keys.any((k) => k.contains('word/'))) {
      return _parseDocx(normalizedArchive);
    } else if (normalizedArchive.containsKey('content.xml')) {
      return _parseOdf(normalizedArchive);
    } else {
      // General fallbacks
      if (normalizedArchive.keys.any((k) => k.contains('sheet'))) {
        return _parseXlsx(normalizedArchive);
      } else if (normalizedArchive.keys.any((k) => k.contains('slide'))) {
        return _parsePptx(normalizedArchive);
      } else if (normalizedArchive.keys.any((k) => k.contains('document'))) {
        return _parseDocx(normalizedArchive);
      } else {
        final legacyText = _extractLegacyStrings(bytes);
        return _ParsedOfficeData(
          subtype: _OfficeSubtype.legacy,
          legacyParagraphs: legacyText,
        );
      }
    }
  } catch (e) {
    return _ParsedOfficeData(
      subtype: _OfficeSubtype.docx,
      error: 'Failed to preview document: $e',
    );
  }
}

// DOCX
_ParsedOfficeData _parseDocx(Map<String, ArchiveFile> archive) {
  final docFile = archive['word/document.xml'] ??
      archive.values.firstWhere(
        (f) => f.name.toLowerCase().endsWith('document.xml'),
        orElse: () => throw Exception('word/document.xml not found in archive'),
      );

  final xmlString = utf8.decode(docFile.content as List<int>, allowMalformed: true);
  return _ParsedOfficeData(
    subtype: _OfficeSubtype.docx,
    docxElements: const [],
    documentXml: xmlString,
  );
}

// ODF
_ParsedOfficeData _parseOdf(Map<String, ArchiveFile> archive) {
  final contentFile = archive['content.xml']!;
  final xmlString = utf8.decode(contentFile.content as List<int>, allowMalformed: true);
  final document = XmlDocument.parse(xmlString);
  final docxElements = <dynamic>[];

  for (final h in _findLocalElements(document, 'h')) {
    final t = h.innerText.trim();
    if (t.isNotEmpty) {
      docxElements.add(DocxParagraphModel(
        index: docxElements.length,
        element: h,
        text: t,
        isHeading: true,
        headingLevel: 1,
      ));
    }
  }

  for (final p in _findLocalElements(document, 'p')) {
    final t = p.innerText.trim();
    if (t.isNotEmpty) {
      docxElements.add(DocxParagraphModel(
        index: docxElements.length,
        element: p,
        text: t,
      ));
    }
  }

  if (docxElements.isEmpty) {
    docxElements.add(DocxParagraphModel(
      index: 0,
      element: document.rootElement,
      text: '(Document has no readable text)',
    ));
  }

  return _ParsedOfficeData(subtype: _OfficeSubtype.docx, docxElements: docxElements);
}

// XLSX
_ParsedOfficeData _parseXlsx(Map<String, ArchiveFile> archive) {
  final xlsxSheets = <_XlsxSheet>[];

  // 1. Shared Strings Table (handles both <si><t> and rich text <si><r><t>)
  final sharedStrings = <String>[];
  final ssEntry = archive.entries.firstWhere(
    (e) => e.key.endsWith('sharedstrings.xml'),
    orElse: () => MapEntry('', ArchiveFile('', 0, [])),
  );

  if (ssEntry.value.content.isNotEmpty) {
    try {
      final ssXmlStr = utf8.decode(ssEntry.value.content as List<int>, allowMalformed: true);
      final ssXml = XmlDocument.parse(ssXmlStr);
      for (final si in _findLocalElements(ssXml, 'si')) {
        final text = _findLocalElements(si, 't').map((n) => n.innerText).join();
        sharedStrings.add(text);
      }
    } catch (_) {}
  }

  // 2. Sheet Names from Workbook
  final sheetNames = <String>[];
  final wbEntry = archive.entries.firstWhere(
    (e) => e.key.endsWith('workbook.xml') && !e.key.contains('.rels'),
    orElse: () => MapEntry('', ArchiveFile('', 0, [])),
  );

  if (wbEntry.value.content.isNotEmpty) {
    try {
      final wbXmlStr = utf8.decode(wbEntry.value.content as List<int>, allowMalformed: true);
      final wbXml = XmlDocument.parse(wbXmlStr);
      for (final sheet in _findLocalElements(wbXml, 'sheet')) {
        final name = sheet.getAttribute('name');
        if (name != null && name.isNotEmpty) {
          sheetNames.add(name);
        }
      }
    } catch (_) {}
  }

  // 3. Find and Parse Worksheet XMLs
  final sheetFiles = archive.entries
      .where((e) => (e.key.contains('worksheets/sheet') || e.key.contains('/sheet')) && e.key.endsWith('.xml') && !e.key.contains('_rels'))
      .toList();

  sheetFiles.sort((a, b) {
    final na = int.tryParse(RegExp(r'\d+').firstMatch(a.key.split('/').last)?.group(0) ?? '0') ?? 0;
    final nb = int.tryParse(RegExp(r'\d+').firstMatch(b.key.split('/').last)?.group(0) ?? '0') ?? 0;
    return na.compareTo(nb);
  });

  int sheetIdx = 0;
  for (final entry in sheetFiles) {
    final xmlStr = utf8.decode(entry.value.content as List<int>, allowMalformed: true);
    final sheetXml = XmlDocument.parse(xmlStr);

    final grid = <List<String>>[];
    int maxCols = 0;

    for (final rowNode in _findLocalElements(sheetXml, 'row')) {
      final rowCells = <String>[];
      int colIndex = 0;

      for (final c in _findLocalElements(rowNode, 'c')) {
        final cellRef = c.getAttribute('r') ?? '';
        final targetCol = _colNameToIdx(cellRef);

        while (colIndex < targetCol) {
          rowCells.add('');
          colIndex++;
        }

        final t = c.getAttribute('t') ?? '';
        String val = '';

        if (t == 's') {
          final v = _findLocalElements(c, 'v').firstOrNull?.innerText ?? '';
          final idx = int.tryParse(v);
          if (idx != null && idx >= 0 && idx < sharedStrings.length) {
            val = sharedStrings[idx];
          } else {
            val = v;
          }
        } else if (t == 'inlineStr') {
          val = _findLocalElements(c, 't').map((n) => n.innerText).join();
        } else {
          val = _findLocalElements(c, 'v').firstOrNull?.innerText ?? '';
        }

        rowCells.add(val);
        colIndex++;
      }

      if (rowCells.any((cell) => cell.trim().isNotEmpty)) {
        grid.add(rowCells);
        if (rowCells.length > maxCols) {
          maxCols = rowCells.length;
        }
      }
    }

    final sheetName = sheetIdx < sheetNames.length ? sheetNames[sheetIdx] : 'Sheet ${sheetIdx + 1}';
    xlsxSheets.add(_XlsxSheet(
      name: sheetName,
      rows: grid.isNotEmpty ? grid : [const ['(Empty sheet)']],
      maxCols: math.max(maxCols, 1),
    ));
    sheetIdx++;
  }

  if (xlsxSheets.isEmpty) {
    xlsxSheets.add(const _XlsxSheet(name: 'Sheet 1', rows: [['(No worksheets found)']], maxCols: 1));
  }

  return _ParsedOfficeData(subtype: _OfficeSubtype.xlsx, xlsxSheets: xlsxSheets);
}

int _colNameToIdx(String cellRef) {
  final letters = RegExp(r'^[A-Za-z]+').firstMatch(cellRef)?.group(0)?.toUpperCase();
  if (letters == null || letters.isEmpty) return 0;
  int col = 0;
  for (int i = 0; i < letters.length; i++) {
    col = col * 26 + (letters.codeUnitAt(i) - 65 + 1);
  }
  return math.max(col - 1, 0);
}

// PPTX
_ParsedOfficeData _parsePptx(Map<String, ArchiveFile> archive) {
  final pptxSlides = <_PptxSlide>[];

  // Match only slide files: ppt/slides/slideX.xml (exclude .rels!)
  final slideFiles = archive.entries
      .where((e) => RegExp(r'ppt/slides/slide\d+\.xml$').hasMatch(e.key))
      .toList();

  slideFiles.sort((a, b) {
    final na = int.tryParse(RegExp(r'\d+').firstMatch(a.key.split('/').last)?.group(0) ?? '0') ?? 0;
    final nb = int.tryParse(RegExp(r'\d+').firstMatch(b.key.split('/').last)?.group(0) ?? '0') ?? 0;
    return na.compareTo(nb);
  });

  int slideNum = 1;
  for (final entry in slideFiles) {
    final xmlStr = utf8.decode(entry.value.content as List<int>, allowMalformed: true);
    final slideXml = XmlDocument.parse(xmlStr);

    String slideTitle = '';
    final textBlocks = <String>[];

    // Find relationships for this slide to extract embedded images
    final slideFileName = entry.key.split('/').last; // e.g. slide1.xml
    final relsKey = 'ppt/slides/_rels/$slideFileName.rels';
    final slideImages = <Uint8List>[];

    if (archive.containsKey(relsKey)) {
      try {
        final relsXmlStr = utf8.decode(archive[relsKey]!.content as List<int>, allowMalformed: true);
        final relsXml = XmlDocument.parse(relsXmlStr);
        for (final rel in _findLocalElements(relsXml, 'Relationship')) {
          final target = rel.getAttribute('Target') ?? '';
          final type = rel.getAttribute('Type') ?? '';
          if (type.contains('image') || target.contains('media/')) {
            final clean = target.replaceAll('../', '').replaceFirst(RegExp(r'^/+'), '').toLowerCase();
            final mediaKey = clean.startsWith('ppt/') ? clean : 'ppt/$clean';
            if (archive.containsKey(mediaKey)) {
              slideImages.add(Uint8List.fromList(archive[mediaKey]!.content as List<int>));
            }
          }
        }
      } catch (_) {}
    }

    // Extract shapes and text
    for (final sp in _findLocalElements(slideXml, 'sp')) {
      final ph = _findLocalElements(sp, 'ph').firstOrNull;
      final phType = ph?.getAttribute('type') ?? '';
      final isTitleShape = phType == 'title' || phType == 'ctrTitle';

      final paras = _findLocalElements(sp, 'p');
      for (final p in paras) {
        final line = _findLocalElements(p, 't').map((n) => n.innerText).join().trim();
        if (line.isEmpty) continue;

        if (isTitleShape && slideTitle.isEmpty) {
          slideTitle = line;
        } else if (slideTitle.isEmpty && textBlocks.isEmpty && line.length < 60) {
          slideTitle = line;
        } else {
          textBlocks.add(line);
        }
      }
    }

    // Fallback if title still empty
    if (slideTitle.isEmpty && textBlocks.isNotEmpty) {
      slideTitle = textBlocks.removeAt(0);
    }

    pptxSlides.add(_PptxSlide(
      index: slideNum,
      title: slideTitle.isNotEmpty ? slideTitle : 'Slide $slideNum',
      textBlocks: textBlocks,
      images: slideImages,
    ));
    slideNum++;
  }

  if (pptxSlides.isEmpty) {
    pptxSlides.add(const _PptxSlide(index: 1, title: 'Slide 1', textBlocks: ['(No presentation content found)']));
  }

  return _ParsedOfficeData(subtype: _OfficeSubtype.pptx, pptxSlides: pptxSlides);
}

// LEGACY STRINGS
List<String> _extractLegacyStrings(Uint8List bytes) {
  final utf16Paragraphs = <String>[];
  final sb16 = StringBuffer();
  for (int i = 0; i < bytes.length - 1; i += 2) {
    final low = bytes[i];
    final high = bytes[i + 1];
    if (high == 0x00 && ((low >= 32 && low <= 126) || low == 10 || low == 13)) {
      if (low == 10 || low == 13) {
        if (sb16.length > 5) utf16Paragraphs.add(sb16.toString().trim());
        sb16.clear();
      } else {
        sb16.writeCharCode(low);
      }
    } else {
      if (sb16.length > 8) utf16Paragraphs.add(sb16.toString().trim());
      sb16.clear();
    }
  }
  if (sb16.length > 5) utf16Paragraphs.add(sb16.toString().trim());

  final asciiParagraphs = <String>[];
  final sbAscii = StringBuffer();
  for (final b in bytes) {
    if ((b >= 32 && b <= 126) || b == 10 || b == 13) {
      if (b == 10 || b == 13) {
        if (sbAscii.length > 5) asciiParagraphs.add(sbAscii.toString().trim());
        sbAscii.clear();
      } else {
        sbAscii.writeCharCode(b);
      }
    } else {
      if (sbAscii.length > 8) asciiParagraphs.add(sbAscii.toString().trim());
      sbAscii.clear();
    }
  }
  if (sbAscii.length > 5) asciiParagraphs.add(sbAscii.toString().trim());

  final combined = utf16Paragraphs.length >= asciiParagraphs.length ? utf16Paragraphs : asciiParagraphs;
  final filtered = combined.where((s) => s.length > 3).toList();
  return filtered.isNotEmpty ? filtered : const ['(Binary document structure. No plain text extracted)'];
}
