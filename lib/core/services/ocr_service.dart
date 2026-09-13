import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class OcrService {
  OcrService._();

  static final OcrService instance = OcrService._();
  static const MethodChannel _pdfChannel = MethodChannel('com.openfile/pdf_renderer');

  /// Performs 100% offline, on-device OCR on an image file using ML Kit Latin models.
  Future<String> recognizeImageFile(String filePath) async {
    final recognizedText = await recognizeImageFileDetailed(filePath);
    return recognizedText.text.trim();
  }

  /// Performs 100% offline OCR returning the detailed RecognizedText structure
  /// with bounding boxes, lines, and blocks.
  Future<RecognizedText> recognizeImageFileDetailed(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Image file does not exist: $filePath');
    }

    final inputImage = InputImage.fromFilePath(filePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return await textRecognizer.processImage(inputImage);
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

  /// Renders PDF pages to high-resolution JPEG images using native Android PdfRenderer (100% offline).
  Future<List<String>> renderPdfPages(String pdfPath, {List<int>? pageIndices, double scale = 2.0}) async {
    try {
      final result = await _pdfChannel.invokeListMethod<String>('renderPdfPages', {
        'path': pdfPath,
        'pageIndices': pageIndices,
        'dpiScale': scale,
      });
      return result ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Extracts text from PDF files 100% offline.
  /// First attempts fast vector text extraction.
  /// If the PDF contains scanned pages or book photos (no vector text),
  /// it automatically falls back to rendering PDF pages as high-resolution images
  /// and running Google ML Kit Text Recognition on each page.
  Future<String> extractOrOcrPdf(String pdfPath, {int? pageIndex, bool forceScanOcr = false}) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('PDF file does not exist: $pdfPath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return '';
    }

    if (!forceScanOcr) {
      PdfDocument? document;
      try {
        document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final extracted = extractor.extractText().trim();

        if (extracted.isNotEmpty) {
          return extracted;
        }
      } catch (_) {
        // Fall through to raster OCR
      } finally {
        document?.dispose();
      }
    }

    // Fallback: Render PDF page(s) to images using native PdfRenderer and run ML Kit OCR
    final pageIndices = pageIndex != null ? [pageIndex] : null;
    final renderedPaths = await renderPdfPages(pdfPath, pageIndices: pageIndices, scale: 2.0);

    if (renderedPaths.isEmpty) {
      return 'No readable text or pages could be extracted from this PDF.';
    }

    final buffer = StringBuffer();
    for (int i = 0; i < renderedPaths.length; i++) {
      final imgPath = renderedPaths[i];
      try {
        final pageText = await recognizeImageFile(imgPath);
        if (pageText.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln('\n---\n');
          final pageLabel = pageIndex != null ? 'Page ${pageIndex + 1}' : 'Page ${i + 1}';
          buffer.writeln('[$pageLabel]');
          buffer.writeln(pageText);
        }
      } finally {
        try {
          final f = File(imgPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }

    final result = buffer.toString().trim();
    if (result.isNotEmpty) {
      return result;
    }

    return 'No readable text could be recognized from the PDF pages.';
  }
}
