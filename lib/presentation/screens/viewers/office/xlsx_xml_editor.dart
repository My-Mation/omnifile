import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class XlsxSheetModel {
  final String name;
  final String archivePath;
  List<List<String>> grid;

  XlsxSheetModel({
    required this.name,
    required this.archivePath,
    required this.grid,
  });

  int get rowCount => grid.length;

  int get colCount {
    int maxCols = 0;
    for (final r in grid) {
      if (r.length > maxCols) maxCols = r.length;
    }
    return math.max(maxCols, 1);
  }

  void ensureDimensions(int minRows, int minCols) {
    while (grid.length < minRows) {
      grid.add(List.filled(minCols, '', growable: true));
    }
    for (int r = 0; r < grid.length; r++) {
      while (grid[r].length < minCols) {
        grid[r].add('');
      }
    }
  }
}

class XlsxXmlEditor {
  final Archive _archive;
  final List<XlsxSheetModel> sheets = [];
  bool isDirty = false;

  XlsxXmlEditor._(this._archive);

  static XlsxXmlEditor fromBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final editor = XlsxXmlEditor._(archive);
    editor._init();
    return editor;
  }

  void _init() {
    sheets.clear();
    final normalizedArchive = <String, ArchiveFile>{};
    for (final f in _archive.files) {
      normalizedArchive[f.name.replaceAll('\\', '/').toLowerCase()] = f;
    }

    // 1. Shared Strings Table
    final sharedStrings = <String>[];
    final ssEntry = normalizedArchive['xl/sharedstrings.xml'];
    if (ssEntry != null && ssEntry.content.isNotEmpty) {
      try {
        final ssXmlStr = utf8.decode(ssEntry.content as List<int>, allowMalformed: true);
        final ssXml = XmlDocument.parse(ssXmlStr);
        for (final si in ssXml.descendantElements.where((e) => e.name.local == 'si')) {
          final text = si.descendantElements
              .where((e) => e.name.local == 't')
              .map((n) => n.innerText)
              .join();
          sharedStrings.add(text);
        }
      } catch (_) {}
    }

    // 2. Sheet Names from Workbook
    final sheetNames = <String>[];
    final wbEntry = normalizedArchive['xl/workbook.xml'];
    if (wbEntry != null && wbEntry.content.isNotEmpty) {
      try {
        final wbXmlStr = utf8.decode(wbEntry.content as List<int>, allowMalformed: true);
        final wbXml = XmlDocument.parse(wbXmlStr);
        for (final sheet in wbXml.descendantElements.where((e) => e.name.local == 'sheet')) {
          final name = sheet.getAttribute('name');
          if (name != null && name.isNotEmpty) {
            sheetNames.add(name);
          }
        }
      } catch (_) {}
    }

    // 3. Worksheet entries
    final sheetFiles = normalizedArchive.entries
        .where((e) =>
            (e.key.contains('worksheets/sheet') || e.key.contains('/sheet')) &&
            e.key.endsWith('.xml') &&
            !e.key.contains('_rels'))
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

      // Extract existing rows in 1-based order
      final rowNodes = sheetXml.descendantElements.where((e) => e.name.local == 'row').toList();
      rowNodes.sort((a, b) {
        final rA = int.tryParse(a.getAttribute('r') ?? '0') ?? 0;
        final rB = int.tryParse(b.getAttribute('r') ?? '0') ?? 0;
        return rA.compareTo(rB);
      });

      int expectedRow = 1;
      for (final rowNode in rowNodes) {
        final rowNum = int.tryParse(rowNode.getAttribute('r') ?? '$expectedRow') ?? expectedRow;
        while (grid.length < rowNum - 1) {
          grid.add(List.empty(growable: true));
        }

        final rowCells = <String>[];
        int colIndex = 0;

        for (final c in rowNode.descendantElements.where((e) => e.name.local == 'c')) {
          final cellRef = c.getAttribute('r') ?? '';
          final targetCol = colRefToIndex(cellRef);

          while (colIndex < targetCol) {
            rowCells.add('');
            colIndex++;
          }

          final t = c.getAttribute('t') ?? '';
          String val = '';

          if (t == 's') {
            final v = c.descendantElements.where((e) => e.name.local == 'v').firstOrNull?.innerText ?? '';
            final idx = int.tryParse(v);
            if (idx != null && idx >= 0 && idx < sharedStrings.length) {
              val = sharedStrings[idx];
            } else {
              val = v;
            }
          } else if (t == 'inlineStr') {
            val = c.descendantElements.where((e) => e.name.local == 't').map((n) => n.innerText).join();
          } else {
            val = c.descendantElements.where((e) => e.name.local == 'v').firstOrNull?.innerText ?? '';
          }

          rowCells.add(val);
          colIndex++;
        }

        grid.add(rowCells);
        if (rowCells.length > maxCols) {
          maxCols = rowCells.length;
        }
        expectedRow = grid.length + 1;
      }

      if (grid.isEmpty) {
        grid.add(['']);
      }

      // Standardize rectangular grid
      final normalizedCols = math.max(maxCols, 1);
      for (final r in grid) {
        while (r.length < normalizedCols) {
          r.add('');
        }
      }

      final sheetName = sheetIdx < sheetNames.length ? sheetNames[sheetIdx] : 'Sheet ${sheetIdx + 1}';
      sheets.add(XlsxSheetModel(
        name: sheetName,
        archivePath: entry.value.name,
        grid: grid,
      ));
      sheetIdx++;
    }

    if (sheets.isEmpty) {
      sheets.add(XlsxSheetModel(
        name: 'Sheet 1',
        archivePath: 'xl/worksheets/sheet1.xml',
        grid: [
          ['']
        ],
      ));
    }
  }

  // Cell Coordinates
  static int colRefToIndex(String cellRef) {
    final letters = RegExp(r'^[A-Za-z]+').firstMatch(cellRef)?.group(0)?.toUpperCase();
    if (letters == null || letters.isEmpty) return 0;
    int col = 0;
    for (int i = 0; i < letters.length; i++) {
      col = col * 26 + (letters.codeUnitAt(i) - 65 + 1);
    }
    return math.max(col - 1, 0);
  }

  static String indexToColLetters(int index) {
    int quotient = index;
    String name = '';
    while (quotient >= 0) {
      name = String.fromCharCode(65 + (quotient % 26)) + name;
      quotient = (quotient ~/ 26) - 1;
    }
    return name;
  }

  // Editing operations
  void updateCell(int sheetIndex, int row, int col, String value) {
    if (sheetIndex < 0 || sheetIndex >= sheets.length) return;
    final sheet = sheets[sheetIndex];
    sheet.ensureDimensions(row + 1, col + 1);
    sheet.grid[row][col] = value;
    isDirty = true;
  }

  void insertRow(int sheetIndex, int row) {
    if (sheetIndex < 0 || sheetIndex >= sheets.length) return;
    final sheet = sheets[sheetIndex];
    final cols = sheet.colCount;
    final targetRow = row.clamp(0, sheet.grid.length);
    sheet.grid.insert(targetRow, List.filled(cols, '', growable: true));
    isDirty = true;
  }

  void appendRow(int sheetIndex) {
    if (sheetIndex < 0 || sheetIndex >= sheets.length) return;
    final sheet = sheets[sheetIndex];
    final cols = sheet.colCount;
    sheet.grid.add(List.filled(cols, '', growable: true));
    isDirty = true;
  }

  void appendRows(int sheetIndex, int count) {
    if (sheetIndex < 0 || sheetIndex >= sheets.length || count <= 0) return;
    final sheet = sheets[sheetIndex];
    final cols = sheet.colCount;
    for (int i = 0; i < count; i++) {
      sheet.grid.add(List.filled(cols, '', growable: true));
    }
    isDirty = true;
  }

  void deleteRow(int sheetIndex, int row) {
    if (sheetIndex < 0 || sheetIndex >= sheets.length) return;
    final sheet = sheets[sheetIndex];
    if (sheet.grid.length <= 1) {
      // Clear instead of removing last row
      sheet.grid[0] = List.filled(sheet.colCount, '', growable: true);
    } else if (row >= 0 && row < sheet.grid.length) {
      sheet.grid.removeAt(row);
    }
    isDirty = true;
  }

  void insertColumn(int sheetIndex, int col) {
    if (sheetIndex < 0 || sheetIndex >= sheets.length) return;
    final sheet = sheets[sheetIndex];
    for (final r in sheet.grid) {
      final targetCol = col.clamp(0, r.length);
      r.insert(targetCol, '');
    }
    isDirty = true;
  }

  void deleteColumn(int sheetIndex, int col) {
    if (sheetIndex < 0 || sheetIndex >= sheets.length) return;
    final sheet = sheets[sheetIndex];
    if (sheet.colCount <= 1) {
      for (final r in sheet.grid) {
        if (r.isNotEmpty) r[0] = '';
      }
    } else {
      for (final r in sheet.grid) {
        if (col >= 0 && col < r.length) {
          r.removeAt(col);
        }
      }
    }
    isDirty = true;
  }

  void clearCell(int sheetIndex, int row, int col) {
    updateCell(sheetIndex, row, col, '');
  }

  // Serialization to OpenXML XLSX
  String _buildSheetXml(XlsxSheetModel sheet) {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sb.writeln('  <sheetData>');

    for (int r = 0; r < sheet.grid.length; r++) {
      final rowCells = sheet.grid[r];
      final rowNum = r + 1;
      bool rowHasData = false;

      final rowBuffer = StringBuffer();
      for (int c = 0; c < rowCells.length; c++) {
        final text = rowCells[c];
        if (text.isEmpty) continue;
        rowHasData = true;

        final cellRef = '${indexToColLetters(c)}$rowNum';
        final escaped = _escapeXml(text);

        // Check if pure numeric
        final numVal = double.tryParse(text);
        if (numVal != null && (!text.startsWith('0') || text == '0' || text.startsWith('0.')) && !text.startsWith('+')) {
          rowBuffer.writeln('      <c r="$cellRef"><v>$text</v></c>');
        } else {
          rowBuffer.writeln('      <c r="$cellRef" t="inlineStr"><is><t>$escaped</t></is></c>');
        }
      }

      sb.writeln('    <row r="$rowNum">');
      if (rowHasData) {
        sb.write(rowBuffer.toString());
      }
      sb.writeln('    </row>');
    }

    sb.writeln('  </sheetData>');
    sb.writeln('</worksheet>');
    return sb.toString();
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  Uint8List buildArchiveBytes() {
    for (final sheet in sheets) {
      final sheetXml = _buildSheetXml(sheet);
      // Replace or add in archive
      _archive.add(ArchiveFile.string(sheet.archivePath, sheetXml));
    }

    final encoded = ZipEncoder().encode(_archive);
    return Uint8List.fromList(encoded);
  }
}
