import 'package:flutter_test/flutter_test.dart';
import 'package:openfile/presentation/screens/viewers/office/docx_xml_editor.dart';

void main() {
  const sampleDocxXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1"/>
      </w:pPr>
      <w:r>
        <w:rPr><w:b/></w:rPr>
        <w:t>Project Title</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:t>First paragraph content.</w:t>
      </w:r>
    </w:p>
    <w:p>
      <w:r>
        <w:t>Second paragraph content.</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>''';

  group('DocxXmlEditor', () {
    test('parses paragraphs correctly', () {
      final editor = DocxXmlEditor.fromXmlString(sampleDocxXml);
      expect(editor.paragraphs.length, 3);
      expect(editor.paragraphs[0].text, 'Project Title');
      expect(editor.paragraphs[0].isHeading, true);
      expect(editor.paragraphs[1].text, 'First paragraph content.');
      expect(editor.paragraphs[2].text, 'Second paragraph content.');
    });

    test('updates paragraph text while preserving surrounding nodes', () {
      final editor = DocxXmlEditor.fromXmlString(sampleDocxXml);
      editor.updateParagraphText(1, 'Modified first paragraph.');
      expect(editor.paragraphs[1].text, 'Modified first paragraph.');

      // Check XML output contains modified text and retains heading
      final xml = editor.buildXml();
      expect(xml.contains('Modified first paragraph.'), true);
      expect(xml.contains('Project Title'), true);
      expect(xml.contains('Heading1'), true);
    });

    test('splits paragraph into two adjacent paragraphs', () {
      final editor = DocxXmlEditor.fromXmlString(sampleDocxXml);
      // Split paragraph 1 ("First paragraph content.") at index 6 ("First ")
      editor.splitParagraph(1, 6);

      expect(editor.paragraphs.length, 4);
      expect(editor.paragraphs[1].text, 'First ');
      expect(editor.paragraphs[2].text, 'paragraph content.');
      expect(editor.paragraphs[3].text, 'Second paragraph content.');

      final xml = editor.buildXml();
      expect(xml.contains('First '), true);
      expect(xml.contains('paragraph content.'), true);
    });

    test('merges paragraph with previous paragraph', () {
      final editor = DocxXmlEditor.fromXmlString(sampleDocxXml);
      // Merge paragraph 2 into paragraph 1
      editor.mergeWithPrevious(2);

      expect(editor.paragraphs.length, 2);
      expect(editor.paragraphs[0].text, 'Project Title');
      expect(editor.paragraphs[1].text, 'First paragraph content.Second paragraph content.');
    });

    test('inserts paragraph after given index', () {
      final editor = DocxXmlEditor.fromXmlString(sampleDocxXml);
      editor.insertParagraphAfter(0, initialText: 'Sub-heading paragraph');

      expect(editor.paragraphs.length, 4);
      expect(editor.paragraphs[0].text, 'Project Title');
      expect(editor.paragraphs[1].text, 'Sub-heading paragraph');
      expect(editor.paragraphs[2].text, 'First paragraph content.');
    });
  });
}
