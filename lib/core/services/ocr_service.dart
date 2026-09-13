import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OcrService {
  OcrService._();

  static final OcrService instance = OcrService._();

  /// Performs 100% offline, on-device OCR on an image file using ML Kit Latin models.
  Future<String> recognizeImageFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Image file does not exist: $filePath');
    }

    final inputImage = InputImage.fromFilePath(filePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      await textRecognizer.close();
    }
  }

  /// Performs 100% offline, on-device OCR on in-memory image bytes.
  Future<String> recognizeImageBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return '';

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().microsecondsSinceEpoch}.jpg');
    try {
      await tempFile.writeAsBytes(bytes);
      return await recognizeImageFile(tempFile.path);
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Extracts text from PDF files 100% offline.
  /// Uses pure-Dart PDF text extraction engine to retrieve document text.
  Future<String> extractOrOcrPdf(String pdfPath) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('PDF file does not exist: $pdfPath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return '';

    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final extracted = extractor.extractText().trim();

      if (extracted.isNotEmpty) {
        return extracted;
      }
      return 'No readable text could be extracted from this PDF.';
    } finally {
      document?.dispose();
    }
  }
}
