import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfile/core/services/ocr_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('OcrService Tests', () {
    test('throws when image file does not exist', () async {
      expect(
        () => OcrService.instance.recognizeImageFile('/non/existent/path/test.png'),
        throwsException,
      );
    });

    test('extracts text from PDF document successfully', () async {
      final document = PdfDocument();
      final page = document.pages.add();
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      page.graphics.drawString('OmniFile Universal Offline PDF Test', font);

      final bytes = document.saveSync();
      document.dispose();

      final tempFile = File('${Directory.systemTemp.path}/test_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
      try {
        await tempFile.writeAsBytes(bytes);
        final extracted = await OcrService.instance.extractOrOcrPdf(tempFile.path);
        expect(extracted, contains('OmniFile Universal Offline PDF Test'));
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });

    test('handles empty PDF gracefully', () async {
      final tempFile = File('${Directory.systemTemp.path}/empty_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
      try {
        await tempFile.writeAsBytes([]);
        final extracted = await OcrService.instance.extractOrOcrPdf(tempFile.path);
        expect(extracted, isEmpty);
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });
  });
}
