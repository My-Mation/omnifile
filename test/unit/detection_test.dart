import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfile/domain/entities/viewer_type.dart';
import 'package:openfile/domain/usecases/detect_file_type_usecase.dart';

void main() {
  final detector = DetectFileTypeUseCase();

  group('DetectFileTypeUseCase - Magic Numbers', () {
    test('detects PDF by magic %PDF', () {
      final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35]);
      expect(detector.detectFromBytes(bytes), ViewerType.pdf);
    });

    test('detects PNG by magic \x89PNG', () {
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(detector.detectFromBytes(bytes), ViewerType.image);
    });

    test('detects JPEG by magic \xFF\xD8\xFF', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      expect(detector.detectFromBytes(bytes), ViewerType.image);
    });

    test('detects GIF by GIF87a and GIF89a', () {
      final gif87 = Uint8List.fromList('GIF87a'.codeUnits);
      final gif89 = Uint8List.fromList('GIF89a'.codeUnits);
      expect(detector.detectFromBytes(gif87), ViewerType.image);
      expect(detector.detectFromBytes(gif89), ViewerType.image);
    });

    test('detects GZIP by \x1F\x8B', () {
      final bytes = Uint8List.fromList([0x1F, 0x8B, 0x08, 0x00]);
      expect(detector.detectFromBytes(bytes), ViewerType.archive);
    });

    test('detects Matroska/WebM by \x1A\x45\xDF\xA3', () {
      final bytes = Uint8List.fromList([0x1A, 0x45, 0xDF, 0xA3, 0x9F]);
      expect(detector.detectFromBytes(bytes), ViewerType.video);
    });

    test('detects MP3 by ID3 or sync words', () {
      final id3 = Uint8List.fromList([0x49, 0x44, 0x33, 0x03, 0x00]);
      final sync1 = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x64]);
      final sync2 = Uint8List.fromList([0xFF, 0xF3, 0x90, 0x64]);
      expect(detector.detectFromBytes(id3), ViewerType.audio);
      expect(detector.detectFromBytes(sync1), ViewerType.audio);
      expect(detector.detectFromBytes(sync2), ViewerType.audio);
    });

    test('detects FLAC by fLaC', () {
      final bytes = Uint8List.fromList([0x66, 0x4C, 0x61, 0x43, 0x00]);
      expect(detector.detectFromBytes(bytes), ViewerType.audio);
    });

    test('detects OGG by OggS', () {
      final bytes = Uint8List.fromList([0x4F, 0x67, 0x67, 0x53, 0x00]);
      expect(detector.detectFromBytes(bytes), ViewerType.audio);
    });

    test('detects WAV, AVI, and WEBP from RIFF headers', () {
      final wav = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45
      ]);
      final avi = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x41, 0x56, 0x49, 0x20
      ]);
      final webp = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50
      ]);
      expect(detector.detectFromBytes(wav), ViewerType.audio);
      expect(detector.detectFromBytes(avi), ViewerType.video);
      expect(detector.detectFromBytes(webp), ViewerType.image);
    });

    test('detects TAR from ustar at offset 257', () {
      final tarBytes = Uint8List(300);
      final ustar = 'ustar'.codeUnits;
      for (int i = 0; i < ustar.length; i++) {
        tarBytes[257 + i] = ustar[i];
      }
      expect(detector.detectFromBytes(tarBytes), ViewerType.archive);
    });

    test('detects HTML by <!DOCTYPE html or <html', () {
      final html1 = Uint8List.fromList('<!DOCTYPE html><html><body></body></html>'.codeUnits);
      final html2 = Uint8List.fromList('<html lang="en"><head></head></html>'.codeUnits);
      expect(detector.detectFromBytes(html1), ViewerType.html);
      expect(detector.detectFromBytes(html2), ViewerType.html);
    });

    test('detects ZIP by PK\x03\x04 and distinguishes DOCX/XLSX/PPTX', () {
      final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]);
      expect(detector.detectFromBytes(zip, fileName: 'test.zip'), ViewerType.archive);
      expect(detector.detectFromBytes(zip, fileName: 'report.docx'), ViewerType.office);
      expect(detector.detectFromBytes(zip, fileName: 'sheet.xlsx'), ViewerType.office);
    });
  });

  group('DetectFileTypeUseCase - Edge Cases & Extensions', () {
    test('JPEG renamed to .txt: magic MUST win', () {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      expect(
        detector.detectFromBytes(jpegBytes, fileName: 'renamed_jpeg.txt'),
        ViewerType.image,
      );
    });

    test('PNG renamed to .txt: magic MUST win', () {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(
        detector.detectFromBytes(pngBytes, fileName: 'photo.txt'),
        ViewerType.image,
      );
    });

    test('Double extension like file.pdf.txt resolves to text unless magic is PDF', () {
      final textBytes = Uint8List.fromList('Hello World'.codeUnits);
      expect(
        detector.detectFromBytes(textBytes, fileName: 'file.pdf.txt'),
        ViewerType.text,
      );

      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      expect(
        detector.detectFromBytes(pdfBytes, fileName: 'file.pdf.txt'),
        ViewerType.pdf,
      );
    });

    test('Uppercase extensions are matched case-insensitively', () {
      final textBytes = Uint8List.fromList('Hello World'.codeUnits);
      expect(
        detector.detectFromBytes(textBytes, fileName: 'README.TXT'),
        ViewerType.text,
      );
      expect(
        detector.detectFromBytes(textBytes, fileName: 'SCRIPT.PY'),
        ViewerType.code,
      );
      expect(
        detector.detectFromBytes(textBytes, fileName: 'NOTES.MD'),
        ViewerType.markdown,
      );
    });

    test('Empty and 1-byte files', () {
      expect(detector.detectFromBytes(Uint8List(0)), ViewerType.text);
      expect(
        detector.detectFromBytes(Uint8List.fromList([0x41]), fileName: 'a.txt'),
        ViewerType.text,
      );
    });

    test('No extension with plain text detects as text via heuristic', () {
      final textBytes = Uint8List.fromList('Just a plaintext file without extension'.codeUnits);
      expect(detector.detectFromBytes(textBytes, fileName: 'raw_log_dump'), ViewerType.text);
    });

    test('Special filenames and dotfiles detection', () {
      final empty = Uint8List(0);
      expect(detector.detectFromBytes(empty, fileName: 'README'), ViewerType.markdown);
      expect(detector.detectFromBytes(empty, fileName: 'README.md'), ViewerType.markdown);
      expect(detector.detectFromBytes(empty, fileName: 'LICENSE'), ViewerType.text);
      expect(detector.detectFromBytes(empty, fileName: 'Makefile'), ViewerType.code);
      expect(detector.detectFromBytes(empty, fileName: 'Dockerfile'), ViewerType.code);
      expect(detector.detectFromBytes(empty, fileName: '.gitignore'), ViewerType.code);
      expect(detector.detectFromBytes(empty, fileName: '.env'), ViewerType.code);
      expect(detector.detectFromBytes(empty, fileName: '.env.local'), ViewerType.code);
    });

    test('VLC-grade audio and video extensions detection', () {
      final textBytes = Uint8List.fromList('media'.codeUnits);
      final audioExts = ['mp3', 'wav', 'wave', 'flac', 'aac', 'ogg', 'm4a', 'opus', 'wma', 'aiff'];
      for (final ext in audioExts) {
        expect(
          detector.detectFromBytes(textBytes, fileName: 'song.$ext'),
          ViewerType.audio,
          reason: 'Audio extension $ext should map to ViewerType.audio',
        );
      }

      final videoExts = ['mp4', 'm4v', 'mkv', 'avi', 'mov', 'webm', '3gp', 'm2ts', 'flv', 'wmv'];
      for (final ext in videoExts) {
        expect(
          detector.detectFromBytes(textBytes, fileName: 'movie.$ext'),
          ViewerType.video,
          reason: 'Video extension $ext should map to ViewerType.video',
        );
      }

      // .ts without MPEG sync byte resolves to TypeScript code
      expect(detector.detectFromBytes(textBytes, fileName: 'app.ts'), ViewerType.code);

      // .ts with MPEG-TS sync bytes resolves to video
      final mpegTsBytes = Uint8List(200);
      mpegTsBytes[0] = 0x47;
      mpegTsBytes[188] = 0x47;
      expect(detector.detectFromBytes(mpegTsBytes, fileName: 'stream.ts'), ViewerType.video);
    });

    test('Universal archive formats detection', () {
      final textBytes = Uint8List.fromList('archive'.codeUnits);
      final archiveExts = ['zip', 'tar', 'gz', 'tgz', 'bz2', 'tbz2', 'xz', '7z', 'rar', 'apk'];
      for (final ext in archiveExts) {
        expect(
          detector.detectFromBytes(textBytes, fileName: 'package.$ext'),
          ViewerType.archive,
          reason: 'Archive extension $ext should map to ViewerType.archive',
        );
      }
    });

    test('BZip2, XZ, 7-Zip, RAR, SVG magic number detection', () {
      final bz2 = Uint8List.fromList([0x42, 0x5A, 0x68, 0x39]);
      expect(detector.detectFromBytes(bz2), ViewerType.archive);

      final xz = Uint8List.fromList([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]);
      expect(detector.detectFromBytes(xz), ViewerType.archive);

      final sevenZip = Uint8List.fromList([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]);
      expect(detector.detectFromBytes(sevenZip), ViewerType.archive);

      final rar = Uint8List.fromList([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07]);
      expect(detector.detectFromBytes(rar), ViewerType.archive);

      final svg = Uint8List.fromList('<svg xmlns="http://www.w3.org/2000/svg"></svg>'.codeUnits);
      expect(detector.detectFromBytes(svg), ViewerType.svg);
    });

    test('UTF-8 BOM heuristic detection', () {
      final bomText = Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x48, 0x69]);
      expect(detector.detectFromBytes(bomText, fileName: 'nobom'), ViewerType.text);
    });

    test('Arbitrary random binary detects as unknown (for hex view fallback)', () {
      final binaryBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x00, 0xFF, 0xFE, 0x00, 0x00]);
      expect(detector.detectFromBytes(binaryBytes, fileName: 'random.bin'), ViewerType.unknown);
    });

    test('All Tier 1 code extensions map to ViewerType.code', () {
      final langs = [
        'py', 'js', 'dart', 'java', 'kt', 'c', 'cpp', 'h', 'cs', 'go', 'rs',
        'rb', 'php', 'sh', 'bat', 'ps1', 'sql', 'xml', 'yml', 'yaml',
        'toml', 'ini', 'cfg', 'css',
      ];
      final textBytes = Uint8List.fromList('code sample'.codeUnits);
      for (final ext in langs) {
        expect(
          detector.detectFromBytes(textBytes, fileName: 'test.$ext'),
          ViewerType.code,
          reason: 'Extension $ext should map to ViewerType.code',
        );
      }
    });
  });
}
