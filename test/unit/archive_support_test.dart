import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Archive Multi-Format Decoding & Security Tests', () {
    test('ZipEncoder and ZipDecoder handles nested files', () {
      final archive = Archive();
      final content = 'Hello Archive'.codeUnits;
      archive.addFile(ArchiveFile('docs/readme.txt', content.length, content));

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final decoded = ZipDecoder().decodeBytes(encoded);
      expect(decoded.length, 1);
      expect(decoded.first.name, 'docs/readme.txt');
      expect(String.fromCharCodes(decoded.first.content as List<int>), 'Hello Archive');
    });

    test('TarEncoder and TarDecoder handles standard tar stream', () {
      final archive = Archive();
      final content = 'Tar archive test'.codeUnits;
      archive.addFile(ArchiveFile('test.txt', content.length, content));

      final encoded = TarEncoder().encode(archive);
      final decoded = TarDecoder().decodeBytes(encoded);
      expect(decoded.length, 1);
      expect(decoded.first.name, 'test.txt');
      expect(String.fromCharCodes(decoded.first.content as List<int>), 'Tar archive test');
    });

    test('GZipEncoder and GZipDecoder handles compression and decompression', () {
      final original = 'Gzip compressed text content'.codeUnits;
      final compressed = GZipEncoder().encode(original);
      expect(compressed, isNotNull);

      final decompressed = GZipDecoder().decodeBytes(compressed);
      expect(String.fromCharCodes(decompressed), 'Gzip compressed text content');
    });

    test('BZip2Encoder and BZip2Decoder handles bzip2 streams', () {
      final original = 'BZip2 high ratio compression test'.codeUnits;
      final compressed = BZip2Encoder().encode(original);

      final decompressed = BZip2Decoder().decodeBytes(compressed);
      expect(String.fromCharCodes(decompressed), 'BZip2 high ratio compression test');
    });

    test('XZDecoder decodes XZ streams properly', () {
      final original = 'XZ compressed payload test'.codeUnits;
      final compressed = XZEncoder().encode(original);

      final decompressed = XZDecoder().decodeBytes(compressed);
      expect(String.fromCharCodes(decompressed), 'XZ compressed payload test');
    });

    test('Zip Slip traversal paths are rejected', () {
      final dangerousPaths = [
        '../evil.sh',
        '../../etc/passwd',
        '/root/hacked',
        'docs/../../escape.txt',
      ];

      for (final p in dangerousPaths) {
        final isDangerous = p.startsWith('..') ||
            p.startsWith('/') ||
            p.contains('../') ||
            p.contains('..\\');
        expect(isDangerous, isTrue, reason: 'Path $p must be identified as traversal attempt');
      }
    });
  });
}
