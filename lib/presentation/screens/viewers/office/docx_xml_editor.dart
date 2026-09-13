import 'package:xml/xml.dart';

class DocxParagraphModel {
  final int index;
  final XmlElement element;
  String text;
  final bool isHeading;
  final int headingLevel;
  final bool isBullet;
  final bool isBold;
  final bool isItalic;

  DocxParagraphModel({
    required this.index,
    required this.element,
    required this.text,
    this.isHeading = false,
    this.headingLevel = 1,
    this.isBullet = false,
    this.isBold = false,
    this.isItalic = false,
  });
}

class DocxTableCellModel {
  final int rowIndex;
  final int colIndex;
  final XmlElement element;
  String text;

  DocxTableCellModel({
    required this.rowIndex,
    required this.colIndex,
    required this.element,
    required this.text,
  });
}

class DocxTableModel {
  final int index;
  final XmlElement element;
  final List<List<DocxTableCellModel>> rows;

  DocxTableModel({
    required this.index,
    required this.element,
    required this.rows,
  });
}

class DocxXmlEditor {
  final XmlDocument document;
  late XmlElement body;
  List<DocxParagraphModel> paragraphs = [];
  List<dynamic> elements = [];

  DocxXmlEditor._(this.document) {
    _init();
  }

  factory DocxXmlEditor.fromXmlString(String xmlString) {
    final doc = XmlDocument.parse(xmlString);
    return DocxXmlEditor._(doc);
  }

  void _init() {
    body = _findLocalElements(document, 'body').firstOrNull ?? document.rootElement;
    _refreshElements();
  }

  static Iterable<XmlElement> _findLocalElements(XmlNode node, String localName) {
    return node.descendantElements.where((e) => e.name.local == localName);
  }

  void _refreshElements() {
    elements.clear();
    paragraphs.clear();
    int pIdx = 0;
    int tblIdx = 0;
    for (final child in body.children) {
      if (child is! XmlElement) continue;

      if (child.name.local == 'p') {
        final pStyle = _findLocalElements(child, 'pStyle').firstOrNull?.getAttribute('w:val') ?? '';
        final isHeading = pStyle.toLowerCase().contains('heading') || pStyle.toLowerCase().contains('title');
        int headingLevel = 1;
        if (pStyle.toLowerCase().contains('heading')) {
          final digit = RegExp(r'\d').firstMatch(pStyle)?.group(0);
          if (digit != null) headingLevel = int.tryParse(digit) ?? 1;
        }

        final isBullet = _findLocalElements(child, 'numPr').isNotEmpty;

        final fullText = StringBuffer();
        bool isBold = false;
        bool isItalic = false;

        for (final r in _findLocalElements(child, 'r')) {
          if (_findLocalElements(r, 'b').isNotEmpty) isBold = true;
          if (_findLocalElements(r, 'i').isNotEmpty) isItalic = true;

          for (final t in _findLocalElements(r, 't')) {
            fullText.write(t.innerText);
          }
        }

        final pModel = DocxParagraphModel(
          index: pIdx++,
          element: child,
          text: fullText.toString(),
          isHeading: isHeading,
          headingLevel: headingLevel,
          isBullet: isBullet,
          isBold: isBold,
          isItalic: isItalic,
        );
        paragraphs.add(pModel);
        elements.add(pModel);
      } else if (child.name.local == 'tbl') {
        final rows = <List<DocxTableCellModel>>[];
        int rIdx = 0;
        for (final tr in _findLocalElements(child, 'tr')) {
          final rowCells = <DocxTableCellModel>[];
          int cIdx = 0;
          for (final tc in _findLocalElements(tr, 'tc')) {
            final cellText = _findLocalElements(tc, 't').map((e) => e.innerText).join(' ').trim();
            rowCells.add(DocxTableCellModel(
              rowIndex: rIdx,
              colIndex: cIdx++,
              element: tc,
              text: cellText,
            ));
          }
          if (rowCells.isNotEmpty) {
            rows.add(rowCells);
            rIdx++;
          }
        }
        if (rows.isNotEmpty) {
          elements.add(DocxTableModel(
            index: tblIdx++,
            element: child,
            rows: rows,
          ));
        }
      }
    }
  }

  void _refreshParagraphs() {
    _refreshElements();
  }

  /// Updates the text of a table cell while preserving cell properties and formatting.
  void updateTableCell(DocxTableCellModel cell, String newText) {
    cell.text = newText;
    final tcElem = cell.element;
    // Preserve cell properties (w:tcPr) if present
    final tcPr = _findLocalElements(tcElem, 'tcPr').firstOrNull?.copy();
    tcElem.children.removeWhere((c) => c is XmlElement && (c.name.local == 'p' || c.name.local == 'tbl'));
    if (tcPr != null) {
      tcElem.children.add(tcPr);
    }
    tcElem.children.add(XmlElement(XmlName.qualified('w:p'), [], [
      XmlElement(XmlName.qualified('w:r'), [], [
        XmlElement(XmlName.qualified('w:t'), [], [XmlText(newText)]),
      ]),
    ]));
  }

  /// Updates the text of the paragraph at [paragraphIndex].
  /// Preserves paragraph properties (`<w:pPr>`) and run properties (`<w:rPr>`).
  void updateParagraphText(int paragraphIndex, String newText) {
    if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) return;
    final model = paragraphs[paragraphIndex];
    final pElem = model.element;

    final runs = _findLocalElements(pElem, 'r').toList();
    if (runs.isEmpty) {
      // Create a default run
      final newRun = XmlElement(XmlName.qualified('w:r'), [], [
        XmlElement(XmlName.qualified('w:t'), [], [XmlText(newText)]),
      ]);
      pElem.children.add(newRun);
    } else {
      // Put updated text in the first run's text node, clear subsequent text nodes
      final firstRun = runs.first;
      final tNodesFirst = _findLocalElements(firstRun, 't').toList();
      if (tNodesFirst.isNotEmpty) {
        tNodesFirst.first.innerText = newText;
        for (int i = 1; i < tNodesFirst.length; i++) {
          tNodesFirst[i].innerText = '';
        }
      } else {
        firstRun.children.add(XmlElement(XmlName.qualified('w:t'), [], [XmlText(newText)]));
      }

      // Clear text from subsequent runs to avoid duplication
      for (int r = 1; r < runs.length; r++) {
        for (final t in _findLocalElements(runs[r], 't')) {
          t.innerText = '';
        }
      }
    }

    model.text = newText;
  }

  /// Splits paragraph at [paragraphIndex] at [charOffset].
  /// Text before offset remains in the paragraph; text after offset forms a new paragraph.
  void splitParagraph(int paragraphIndex, int charOffset) {
    if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) return;
    final model = paragraphs[paragraphIndex];
    final originalText = model.text;

    final safeOffset = charOffset.clamp(0, originalText.length);
    final textBefore = originalText.substring(0, safeOffset);
    final textAfter = originalText.substring(safeOffset);

    // Update current paragraph
    updateParagraphText(paragraphIndex, textBefore);

    // Clone element to inherit pPr and rPr
    final cloned = XmlElement(
      model.element.name,
      model.element.attributes.map((a) => XmlAttribute(a.name, a.value)),
      model.element.children.map((c) => c.copy()),
    );

    // Update cloned element's text to textAfter
    final runs = _findLocalElements(cloned, 'r').toList();
    if (runs.isNotEmpty) {
      final tNodes = _findLocalElements(runs.first, 't').toList();
      if (tNodes.isNotEmpty) {
        tNodes.first.innerText = textAfter;
      }
      for (int r = 1; r < runs.length; r++) {
        for (final t in _findLocalElements(runs[r], 't')) {
          t.innerText = '';
        }
      }
    }

    // Insert cloned element directly after original in body
    final currentXmlIndex = body.children.indexOf(model.element);
    if (currentXmlIndex != -1) {
      body.children.insert(currentXmlIndex + 1, cloned);
    } else {
      body.children.add(cloned);
    }

    _refreshParagraphs();
  }

  /// Merges paragraph at [paragraphIndex] into the previous paragraph [paragraphIndex - 1].
  void mergeWithPrevious(int paragraphIndex) {
    if (paragraphIndex <= 0 || paragraphIndex >= paragraphs.length) return;
    final currentModel = paragraphs[paragraphIndex];
    final prevModel = paragraphs[paragraphIndex - 1];

    final combinedText = prevModel.text + currentModel.text;
    updateParagraphText(paragraphIndex - 1, combinedText);

    // Remove current paragraph from body
    body.children.remove(currentModel.element);

    _refreshParagraphs();
  }

  /// Inserts a new paragraph after [paragraphIndex] with inherited styles.
  void insertParagraphAfter(int paragraphIndex, {String initialText = ''}) {
    if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) {
      // Append at end
      final newP = XmlElement(XmlName.qualified('w:p'), [], [
        XmlElement(XmlName.qualified('w:r'), [], [
          XmlElement(XmlName.qualified('w:t'), [], [XmlText(initialText)]),
        ]),
      ]);
      body.children.add(newP);
    } else {
      final model = paragraphs[paragraphIndex];
      // Clone pPr if present
      final pPr = _findLocalElements(model.element, 'pPr').firstOrNull?.copy();
      final children = <XmlNode>[];
      if (pPr != null) children.add(pPr);
      children.add(XmlElement(XmlName.qualified('w:r'), [], [
        XmlElement(XmlName.qualified('w:t'), [], [XmlText(initialText)]),
      ]));

      final newP = XmlElement(XmlName.qualified('w:p'), [], children);
      final currentXmlIndex = body.children.indexOf(model.element);
      if (currentXmlIndex != -1) {
        body.children.insert(currentXmlIndex + 1, newP);
      } else {
        body.children.add(newP);
      }
    }

    _refreshParagraphs();
  }

  /// Returns the re-serialized XML string.
  String buildXml() {
    return document.toXmlString();
  }
}
