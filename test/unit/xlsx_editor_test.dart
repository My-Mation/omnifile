import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfile/presentation/screens/viewers/office/xlsx_xml_editor.dart';

void main() {
  group('XlsxXmlEditor Tests', () {
    late Uint8List testXlsxBytes;

    setUp(() {
      final archive = Archive();
      archive.add(ArchiveFile.string(
        'xl/workbook.xml',
        '<?xml version="1.0" encoding="UTF-8"?><workbook><sheets><sheet name="Sheet 1" sheetId="1" r:id="rId1"/></sheets></workbook>',
      ));
      archive.add(ArchiveFile.string(
        'xl/worksheets/sheet1.xml',
        '<?xml version="1.0" encoding="UTF-8"?><worksheet><sheetData>'
            '<row r="1">'
            '<c r="A1" t="inlineStr"><is><t>First Name</t></is></c>'
            '<c r="B1" t="inlineStr"><is><t>Last Name</t></is></c>'
            '<c r="C1"><v>100</v></c>'
            '</row>'
            '<row r="2">'
            '<c r="A2" t="inlineStr"><is><t>John</t></is></c>'
            '<c r="B2" t="inlineStr"><is><t>Doe</t></is></c>'
            '<c r="C2"><v>200</v></c>'
            '</row>'
            '</sheetData></worksheet>',
      ));
      final encoded = ZipEncoder().encode(archive);
      testXlsxBytes = Uint8List.fromList(encoded);
    });

    test('parses XLSX sheets and cells correctly', () {
      final editor = XlsxXmlEditor.fromBytes(testXlsxBytes);
      expect(editor.sheets.length, 1);
      final sheet = editor.sheets[0];
      expect(sheet.name, 'Sheet 1');
      expect(sheet.rowCount, 2);
      expect(sheet.grid[0][0], 'First Name');
      expect(sheet.grid[0][1], 'Last Name');
      expect(sheet.grid[0][2], '100');
      expect(sheet.grid[1][0], 'John');
      expect(sheet.grid[1][1], 'Doe');
      expect(sheet.grid[1][2], '200');
    });

    test('updates cell content correctly', () {
      final editor = XlsxXmlEditor.fromBytes(testXlsxBytes);
      editor.updateCell(0, 1, 1, 'Smith');
      expect(editor.sheets[0].grid[1][1], 'Smith');
      expect(editor.isDirty, isTrue);

      final newBytes = editor.buildArchiveBytes();
      final reloaded = XlsxXmlEditor.fromBytes(newBytes);
      expect(reloaded.sheets[0].grid[1][1], 'Smith');
    });

    test('inserts and appends rows correctly', () {
      final editor = XlsxXmlEditor.fromBytes(testXlsxBytes);
      // Insert row at 1 (between header and John)
      editor.insertRow(0, 1);
      expect(editor.sheets[0].rowCount, 3);
      expect(editor.sheets[0].grid[1][0], '');
      expect(editor.sheets[0].grid[2][0], 'John');

      // Append 2 rows
      editor.appendRows(0, 2);
      expect(editor.sheets[0].rowCount, 5);

      final newBytes = editor.buildArchiveBytes();
      final reloaded = XlsxXmlEditor.fromBytes(newBytes);
      expect(reloaded.sheets[0].rowCount, 5);
    });

    test('deletes rows correctly', () {
      final editor = XlsxXmlEditor.fromBytes(testXlsxBytes);
      editor.deleteRow(0, 1); // delete John Doe row
      expect(editor.sheets[0].rowCount, 1);
      expect(editor.sheets[0].grid[0][0], 'First Name');

      final newBytes = editor.buildArchiveBytes();
      final reloaded = XlsxXmlEditor.fromBytes(newBytes);
      expect(reloaded.sheets[0].rowCount, 1);
      expect(reloaded.sheets[0].grid[0][0], 'First Name');
    });

    test('inserts and deletes columns correctly', () {
      final editor = XlsxXmlEditor.fromBytes(testXlsxBytes);
      editor.insertColumn(0, 1); // Insert between First Name and Last Name
      expect(editor.sheets[0].grid[0][0], 'First Name');
      expect(editor.sheets[0].grid[0][1], '');
      expect(editor.sheets[0].grid[0][2], 'Last Name');

      editor.deleteColumn(0, 1); // Delete inserted column
      expect(editor.sheets[0].grid[0][1], 'Last Name');
    });
  });
}
