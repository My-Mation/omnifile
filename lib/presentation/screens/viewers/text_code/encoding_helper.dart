import 'dart:convert';
import 'dart:typed_data';

enum FileEncoding {
  utf8('UTF-8'),
  utf16le('UTF-16LE'),
  utf16be('UTF-16BE'),
  latin1('Latin-1 (ISO-8859-1)'),
  ascii('ASCII');

  final String displayName;
  const FileEncoding(this.displayName);
}

class EncodingHelper {
  EncodingHelper._();

  static FileEncoding detectEncoding(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return FileEncoding.utf8;
    }
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        return FileEncoding.utf16le;
      }
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        return FileEncoding.utf16be;
      }
    }

    // Pattern check: UTF-16 often has null bytes in every other position
    if (bytes.length >= 4) {
      if (bytes[1] == 0x00 && bytes[3] == 0x00) {
        return FileEncoding.utf16le;
      }
      if (bytes[0] == 0x00 && bytes[2] == 0x00) {
        return FileEncoding.utf16be;
      }
    }

    // Try UTF-8 decoding
    try {
      utf8.decode(bytes);
      return FileEncoding.utf8;
    } catch (_) {
      return FileEncoding.latin1;
    }
  }

  static String decode(Uint8List bytes, FileEncoding encoding) {
    switch (encoding) {
      case FileEncoding.utf8:
        // Strip BOM if present
        Uint8List clean = bytes;
        if (bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF) {
          clean = bytes.sublist(3);
        }
        return utf8.decode(clean, allowMalformed: true);

      case FileEncoding.utf16le:
        Uint8List clean = bytes;
        if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
          clean = bytes.sublist(2);
        }
        final charCodes = <int>[];
        for (int i = 0; i + 1 < clean.length; i += 2) {
          charCodes.add(clean[i] | (clean[i + 1] << 8));
        }
        return String.fromCharCodes(charCodes);

      case FileEncoding.utf16be:
        Uint8List clean = bytes;
        if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
          clean = bytes.sublist(2);
        }
        final charCodes = <int>[];
        for (int i = 0; i + 1 < clean.length; i += 2) {
          charCodes.add((clean[i] << 8) | clean[i + 1]);
        }
        return String.fromCharCodes(charCodes);

      case FileEncoding.latin1:
        return latin1.decode(bytes);

      case FileEncoding.ascii:
        return ascii.decode(bytes, allowInvalid: true);
    }
  }

  static Uint8List encode(String text, FileEncoding encoding) {
    switch (encoding) {
      case FileEncoding.utf8:
        return Uint8List.fromList(utf8.encode(text));
      case FileEncoding.utf16le:
        final bytes = <int>[];
        for (final codeUnit in text.codeUnits) {
          bytes.add(codeUnit & 0xFF);
          bytes.add((codeUnit >> 8) & 0xFF);
        }
        return Uint8List.fromList(bytes);
      case FileEncoding.utf16be:
        final bytes = <int>[];
        for (final codeUnit in text.codeUnits) {
          bytes.add((codeUnit >> 8) & 0xFF);
          bytes.add(codeUnit & 0xFF);
        }
        return Uint8List.fromList(bytes);
      case FileEncoding.latin1:
        return Uint8List.fromList(latin1.encode(text));
      case FileEncoding.ascii:
        return Uint8List.fromList(ascii.encode(text));
    }
  }
}
