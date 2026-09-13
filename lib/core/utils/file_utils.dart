import 'dart:io';
import 'package:crypto/crypto.dart';

class FileUtils {
  FileUtils._();

  static Future<String?> computeSha256(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final size = await file.length();
      // Only compute for files < 100MB as specified in rules.txt §5.1
      if (size > 100 * 1024 * 1024) return null;

      final stream = file.openRead();
      final digest = await sha256.bind(stream).first;
      return digest.toString();
    } catch (_) {
      return null;
    }
  }
}
