import 'dart:io';
import 'dart:typed_data';
import '../entities/viewer_type.dart';

class DetectFileTypeUseCase {
  // In-memory cache keyed by "path:size:mtime"
  final Map<String, ViewerType> _cache = {};

  static const Map<String, ViewerType> _specialNameMap = {
    // Readme & Documentation
    'readme': ViewerType.markdown,
    'changelog': ViewerType.markdown,
    'contributing': ViewerType.markdown,
    'authors': ViewerType.text,
    'license': ViewerType.text,
    'licence': ViewerType.text,
    'copying': ViewerType.text,
    'install': ViewerType.text,
    'todo': ViewerType.text,
    'notice': ViewerType.text,

    // Build & Config Scripts (no extension)
    'makefile': ViewerType.code,
    'dockerfile': ViewerType.code,
    'containerfile': ViewerType.code,
    'procfile': ViewerType.code,
    'gemfile': ViewerType.code,
    'rakefile': ViewerType.code,
    'vagrantfile': ViewerType.code,
    'cmakelists.txt': ViewerType.code,

    // Dotfiles
    '.gitignore': ViewerType.code,
    '.gitattributes': ViewerType.code,
    '.gitmodules': ViewerType.code,
    '.env': ViewerType.code,
    '.editorconfig': ViewerType.code,
    '.bashrc': ViewerType.code,
    '.bash_profile': ViewerType.code,
    '.zshrc': ViewerType.code,
    '.profile': ViewerType.code,
    '.npmrc': ViewerType.code,
    '.prettierrc': ViewerType.code,
    '.eslintrc': ViewerType.code,
    '.clang-format': ViewerType.code,
  };

  static const Map<String, ViewerType> _extensionMap = {
    // PDF
    'pdf': ViewerType.pdf,

    // Text & Documents
    'txt': ViewerType.text,
    'text': ViewerType.text,
    'log': ViewerType.text,
    'csv': ViewerType.office,
    'tsv': ViewerType.office,
    'conf': ViewerType.text,
    'config': ViewerType.text,
    'cfg': ViewerType.code,
    'ini': ViewerType.code,
    'inf': ViewerType.text,
    'properties': ViewerType.code,
    'env': ViewerType.code,
    'nfo': ViewerType.text,
    'srt': ViewerType.text,
    'vtt': ViewerType.text,
    'sub': ViewerType.text,
    'ass': ViewerType.text,
    'diff': ViewerType.text,
    'patch': ViewerType.text,
    'manifest': ViewerType.text,
    'reg': ViewerType.text,
    'asc': ViewerType.text,
    'key': ViewerType.text,
    'pem': ViewerType.text,
    'pub': ViewerType.text,
    'cer': ViewerType.text,
    'crt': ViewerType.text,
    'tex': ViewerType.text,
    'rst': ViewerType.text,
    'adoc': ViewerType.text,
    'asciidoc': ViewerType.text,

    // Markdown
    'md': ViewerType.markdown,
    'markdown': ViewerType.markdown,
    'mdown': ViewerType.markdown,
    'mkdn': ViewerType.markdown,
    'mdwn': ViewerType.markdown,
    'mdtxt': ViewerType.markdown,
    'mdtext': ViewerType.markdown,

    // Images
    'jpg': ViewerType.image,
    'jpeg': ViewerType.image,
    'png': ViewerType.image,
    'gif': ViewerType.image,
    'webp': ViewerType.image,
    'bmp': ViewerType.image,
    'heic': ViewerType.image,
    'heif': ViewerType.image,
    'ico': ViewerType.image,
    'cur': ViewerType.image,
    'tif': ViewerType.image,
    'tiff': ViewerType.image,
    'avif': ViewerType.image,
    'svg': ViewerType.svg,

    // Video (VLC-Grade container & codec coverage)
    'mp4': ViewerType.video,
    'm4v': ViewerType.video,
    'mkv': ViewerType.video,
    'avi': ViewerType.video,
    'mov': ViewerType.video,
    'qt': ViewerType.video,
    'webm': ViewerType.video,
    '3gp': ViewerType.video,
    '3g2': ViewerType.video,
    'm2ts': ViewerType.video,
    'mts': ViewerType.video,
    'flv': ViewerType.video,
    'f4v': ViewerType.video,
    'wmv': ViewerType.video,
    'asf': ViewerType.video,
    'mpg': ViewerType.video,
    'mpeg': ViewerType.video,
    'mpe': ViewerType.video,
    'mpv': ViewerType.video,
    'vob': ViewerType.video,
    'ogv': ViewerType.video,
    'divx': ViewerType.video,
    'rm': ViewerType.video,
    'rmvb': ViewerType.video,
    'h264': ViewerType.video,
    'h265': ViewerType.video,
    'hevc': ViewerType.video,

    // Audio (VLC-Grade container & codec coverage)
    'mp3': ViewerType.audio,
    'wav': ViewerType.audio,
    'wave': ViewerType.audio,
    'flac': ViewerType.audio,
    'aac': ViewerType.audio,
    'ogg': ViewerType.audio,
    'oga': ViewerType.audio,
    'm4a': ViewerType.audio,
    'm4b': ViewerType.audio,
    'm4p': ViewerType.audio,
    'opus': ViewerType.audio,
    'wma': ViewerType.audio,
    'aiff': ViewerType.audio,
    'aif': ViewerType.audio,
    'aifc': ViewerType.audio,
    'mid': ViewerType.audio,
    'midi': ViewerType.audio,
    'ac3': ViewerType.audio,
    'eac3': ViewerType.audio,
    'amr': ViewerType.audio,
    'ape': ViewerType.audio,
    'mka': ViewerType.audio,
    'au': ViewerType.audio,
    'snd': ViewerType.audio,
    'voc': ViewerType.audio,
    'weba': ViewerType.audio,
    'ra': ViewerType.audio,
    'mp2': ViewerType.audio,
    'mpa': ViewerType.audio,

    // Archives
    'zip': ViewerType.archive,
    'tar': ViewerType.archive,
    'gz': ViewerType.archive,
    'tgz': ViewerType.archive,
    'bz2': ViewerType.archive,
    'tbz2': ViewerType.archive,
    'tbz': ViewerType.archive,
    'xz': ViewerType.archive,
    'txz': ViewerType.archive,
    '7z': ViewerType.archive,
    'rar': ViewerType.archive,
    'jar': ViewerType.archive,
    'war': ViewerType.archive,
    'apk': ViewerType.archive,
    'xpi': ViewerType.archive,

    // HTML
    'html': ViewerType.html,
    'htm': ViewerType.html,
    'xhtml': ViewerType.html,

    // Code & Scripting
    'py': ViewerType.code,
    'pyw': ViewerType.code,
    'js': ViewerType.code,
    'mjs': ViewerType.code,
    'cjs': ViewerType.code,
    'jsx': ViewerType.code,
    'ts': ViewerType.code,
    'tsx': ViewerType.code,
    'dart': ViewerType.code,
    'java': ViewerType.code,
    'kt': ViewerType.code,
    'kts': ViewerType.code,
    'c': ViewerType.code,
    'cpp': ViewerType.code,
    'cc': ViewerType.code,
    'cxx': ViewerType.code,
    'h': ViewerType.code,
    'hpp': ViewerType.code,
    'hxx': ViewerType.code,
    'cs': ViewerType.code,
    'go': ViewerType.code,
    'rs': ViewerType.code,
    'rb': ViewerType.code,
    'php': ViewerType.code,
    'sh': ViewerType.code,
    'bash': ViewerType.code,
    'zsh': ViewerType.code,
    'fish': ViewerType.code,
    'bat': ViewerType.code,
    'cmd': ViewerType.code,
    'ps1': ViewerType.code,
    'psm1': ViewerType.code,
    'sql': ViewerType.code,
    'xml': ViewerType.code,
    'json': ViewerType.json,
    'jsonc': ViewerType.json,
    'json5': ViewerType.json,
    'ndjson': ViewerType.json,
    'yml': ViewerType.code,
    'yaml': ViewerType.code,
    'toml': ViewerType.code,
    'css': ViewerType.code,
    'scss': ViewerType.code,
    'sass': ViewerType.code,
    'less': ViewerType.code,
    'vue': ViewerType.code,
    'svelte': ViewerType.code,
    'swift': ViewerType.code,
    'scala': ViewerType.code,
    'groovy': ViewerType.code,
    'gradle': ViewerType.code,
    'lua': ViewerType.code,
    'r': ViewerType.code,
    'pl': ViewerType.code,
    'pm': ViewerType.code,
    'asm': ViewerType.code,
    's': ViewerType.code,
    'v': ViewerType.code,
    'vhdl': ViewerType.code,
    'zig': ViewerType.code,
    'nim': ViewerType.code,
    'graphql': ViewerType.code,
    'gql': ViewerType.code,
    'proto': ViewerType.code,

    // Office & Documents
    'docx': ViewerType.office,
    'xlsx': ViewerType.office,
    'pptx': ViewerType.office,
    'doc': ViewerType.office,
    'xls': ViewerType.office,
    'ppt': ViewerType.office,
    'odt': ViewerType.office,
    'ods': ViewerType.office,
    'odp': ViewerType.office,
    'rtf': ViewerType.office,

    // eBook
    'epub': ViewerType.epub,
    'mobi': ViewerType.epub,
    'azw': ViewerType.epub,
    'azw3': ViewerType.epub,
    'fb2': ViewerType.epub,
    'cbz': ViewerType.archive,
    'cbr': ViewerType.archive,

    // Binary / Executable / Hex
    'dat': ViewerType.hex,
    'exe': ViewerType.hex,
    'dll': ViewerType.hex,
    'so': ViewerType.hex,
    'dylib': ViewerType.hex,
    'class': ViewerType.hex,
    'o': ViewerType.hex,
    'obj': ViewerType.hex,
    'iso': ViewerType.hex,
    'img': ViewerType.hex,
    'rom': ViewerType.hex,
    'elf': ViewerType.hex,
    'wasm': ViewerType.hex,
    'dex': ViewerType.hex,
    'lib': ViewerType.hex,
    'a': ViewerType.hex,
    'sys': ViewerType.hex,
    'drv': ViewerType.hex,
    'hex': ViewerType.hex,
  };

  static ViewerType? _checkSpecialName(String? fileName) {
    if (fileName == null) return null;
    final base = fileName.split(RegExp(r'[/\\]')).last.toLowerCase();
    if (_specialNameMap.containsKey(base)) {
      return _specialNameMap[base];
    }
    if (base == 'readme') {
      return ViewerType.markdown;
    }
    if (base.startsWith('.env.')) {
      return ViewerType.code;
    }
    return null;
  }

  Future<ViewerType> call(String filePath, {String? originalFileName}) async {
    final effectiveName = originalFileName ?? filePath;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return detectByPathOnly(effectiveName);
      }

      final stat = await file.stat();
      final cacheKey = '$filePath:$effectiveName:${stat.size}:${stat.modified.millisecondsSinceEpoch}';
      if (_cache.containsKey(cacheKey)) {
        return _cache[cacheKey]!;
      }

      final detected = await detectFile(file, stat.size, originalFileName: effectiveName);
      _cache[cacheKey] = detected;
      return detected;
    } catch (_) {
      return detectByPathOnly(effectiveName);
    }
  }

  ViewerType detectByPathOnly(String filePath) {
    final special = _checkSpecialName(filePath);
    if (special != null) return special;

    final ext = _extractExtension(filePath);
    if (ext != null && _extensionMap.containsKey(ext)) {
      return _extensionMap[ext]!;
    }
    return ViewerType.unknown;
  }

  Future<ViewerType> detectFile(File file, int fileSize, {String? originalFileName}) async {
    final effectiveName = originalFileName ?? file.path;
    if (fileSize == 0) {
      // Empty file: respect extension if known text/code, otherwise text
      final ext = _extractExtension(effectiveName);
      if (ext != null && _extensionMap.containsKey(ext)) {
        return _extensionMap[ext]!;
      }
      return ViewerType.text;
    }

    // Read initial bytes (up to 4096 bytes for magic numbers and HTML tag search)
    final sampleSize = fileSize < 4096 ? fileSize : 4096;
    Uint8List headerBytes;
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        headerBytes = await raf.read(sampleSize);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return detectByPathOnly(file.path);
    }

    return detectFromBytes(headerBytes, fileName: file.path, totalSize: fileSize);
  }

  ViewerType detectFromBytes(
    Uint8List bytes, {
    String? fileName,
    int? totalSize,
  }) {
    if (bytes.isEmpty) {
      if (fileName != null) {
        final special = _checkSpecialName(fileName);
        if (special != null) return special;

        final ext = _extractExtension(fileName);
        if (ext != null && _extensionMap.containsKey(ext)) {
          return _extensionMap[ext]!;
        }
      }
      return ViewerType.text;
    }

    // 1. Check Definitive Magic Numbers (Magic MUST win over extensions!)
    final magicType = _checkMagicNumbers(bytes, fileName);
    if (magicType != null) {
      return magicType;
    }

    // 2. Check special names like README, Makefile, .gitignore, .env
    if (fileName != null) {
      final special = _checkSpecialName(fileName);
      if (special != null) {
        return special;
      }
    }

    // 3. Extension Map (Fast path for non-magic files like code/text)
    if (fileName != null) {
      final ext = _extractExtension(fileName);
      if (ext != null && _extensionMap.containsKey(ext)) {
        final mapped = _extensionMap[ext]!;
        return mapped;
      }
    }

    // 4. Text-Detection Heuristic (first 8KB check, >90% printable)
    if (_isTextHeuristic(bytes)) {
      return ViewerType.text;
    }

    // 5. Fallback: Unknown / Hex
    return ViewerType.unknown;
  }

  ViewerType? _checkMagicNumbers(Uint8List bytes, String? fileName) {
    final len = bytes.length;

    // %PDF (4 bytes)
    if (len >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return ViewerType.pdf;
    }

    // \x89PNG\r\n\x1a\n (8 bytes)
    if (len >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return ViewerType.image;
    }

    // JPEG: \xFF\xD8\xFF (3 bytes)
    if (len >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return ViewerType.image;
    }

    // GIF: GIF87a or GIF89a (6 bytes)
    if (len >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return ViewerType.image;
    }

    // BMP: BM (2 bytes)
    if (len >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return ViewerType.image;
    }

    // GZIP: \x1F\x8B (2 bytes)
    if (len >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      return ViewerType.archive;
    }

    // BZIP2: BZ (2 bytes)
    if (len >= 2 && bytes[0] == 0x42 && bytes[1] == 0x5A) {
      return ViewerType.archive;
    }

    // XZ: \xFD7zXZ\x00 (6 bytes)
    if (len >= 6 &&
        bytes[0] == 0xFD &&
        bytes[1] == 0x37 &&
        bytes[2] == 0x7A &&
        bytes[3] == 0x58 &&
        bytes[4] == 0x5A &&
        bytes[5] == 0x00) {
      return ViewerType.archive;
    }

    // 7-Zip: 7z\xBC\xAF\x27\x1C (6 bytes)
    if (len >= 6 &&
        bytes[0] == 0x37 &&
        bytes[1] == 0x7A &&
        bytes[2] == 0xBC &&
        bytes[3] == 0xAF &&
        bytes[4] == 0x27 &&
        bytes[5] == 0x1C) {
      return ViewerType.archive;
    }

    // RAR: Rar!\x1A\x07 (6 bytes)
    if (len >= 6 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x61 &&
        bytes[2] == 0x72 &&
        bytes[3] == 0x21 &&
        bytes[4] == 0x1A &&
        bytes[5] == 0x07) {
      return ViewerType.archive;
    }

    // Matroska / WebM: \x1A\x45\xDF\xA3 (4 bytes)
    if (len >= 4 &&
        bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      if (fileName != null) {
        final ext = _extractExtension(fileName);
        if (ext == 'mka' || ext == 'weba') return ViewerType.audio;
      }
      return ViewerType.video;
    }

    // MP4 / MOV: ftyp or moov at offset 4
    if (len >= 8 &&
        bytes[4] == 0x66 && // 'f'
        bytes[5] == 0x74 && // 't'
        bytes[6] == 0x79 && // 'y'
        bytes[7] == 0x70) { // 'p'
      return ViewerType.video;
    }
    if (len >= 8 &&
        bytes[4] == 0x6D && // 'm'
        bytes[5] == 0x6F && // 'o'
        bytes[6] == 0x6F && // 'o'
        bytes[7] == 0x76) { // 'v'
      return ViewerType.video;
    }

    // MP3: ID3 header
    if (len >= 3 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      return ViewerType.audio;
    }

    // MP3: sync word \xFF\xFB or \xFF\xF3 or \xFF\xF2
    if (len >= 2 &&
        bytes[0] == 0xFF &&
        (bytes[1] == 0xFB || bytes[1] == 0xF3 || bytes[1] == 0xF2)) {
      return ViewerType.audio;
    }

    // FLAC: fLaC (4 bytes)
    if (len >= 4 &&
        bytes[0] == 0x66 &&
        bytes[1] == 0x4C &&
        bytes[2] == 0x61 &&
        bytes[3] == 0x43) {
      return ViewerType.audio;
    }

    // OGG: OggS (4 bytes)
    if (len >= 4 &&
        bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53) {
      if (fileName != null) {
        final ext = _extractExtension(fileName);
        if (ext == 'ogv') return ViewerType.video;
      }
      return ViewerType.audio;
    }

    // RIFF formats: WAV, AVI, WEBP (12 bytes)
    if (len >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46) { // F
      // Sub-chunk ID at offset 8
      final sub = String.fromCharCodes(bytes.sublist(8, 12));
      if (sub == 'WAVE') return ViewerType.audio;
      if (sub == 'AVI ') return ViewerType.video;
      if (sub == 'WEBP') return ViewerType.image;
    }

    // AIFF: FORM....AIFF or AIFC (12 bytes)
    if (len >= 12 &&
        bytes[0] == 0x46 && // F
        bytes[1] == 0x4F && // O
        bytes[2] == 0x52 && // R
        bytes[3] == 0x4D) { // M
      final formType = String.fromCharCodes(bytes.sublist(8, 12));
      if (formType == 'AIFF' || formType == 'AIFC') {
        return ViewerType.audio;
      }
    }

    // FLV: FLV\x01 (4 bytes)
    if (len >= 4 &&
        bytes[0] == 0x46 &&
        bytes[1] == 0x4C &&
        bytes[2] == 0x56 &&
        bytes[3] == 0x01) {
      return ViewerType.video;
    }

    // MPEG Program Stream: 00 00 01 BA (4 bytes)
    if (len >= 4 &&
        bytes[0] == 0x00 &&
        bytes[1] == 0x00 &&
        bytes[2] == 0x01 &&
        bytes[3] == 0xBA) {
      return ViewerType.video;
    }

    // MPEG Transport Stream: 0x47 sync byte at offset 0 and offset 188
    if (len >= 189 && bytes[0] == 0x47 && bytes[188] == 0x47) {
      return ViewerType.video;
    }

    // Windows Media (ASF / WMV / WMA): 30 26 B2 75 8E 66 CF 11 (8 bytes)
    if (len >= 8 &&
        bytes[0] == 0x30 &&
        bytes[1] == 0x26 &&
        bytes[2] == 0xB2 &&
        bytes[3] == 0x75 &&
        bytes[4] == 0x8E &&
        bytes[5] == 0x66 &&
        bytes[6] == 0xCF &&
        bytes[7] == 0x11) {
      if (fileName != null && _extractExtension(fileName) == 'wma') {
        return ViewerType.audio;
      }
      return ViewerType.video;
    }

    // AMR: #!AMR\n (6 bytes)
    if (len >= 6 &&
        bytes[0] == 0x23 &&
        bytes[1] == 0x21 &&
        bytes[2] == 0x41 &&
        bytes[3] == 0x4D &&
        bytes[4] == 0x52 &&
        bytes[5] == 0x0A) {
      return ViewerType.audio;
    }

    // AC-3: 0B 77 (2 bytes)
    if (len >= 2 && bytes[0] == 0x0B && bytes[1] == 0x77) {
      return ViewerType.audio;
    }

    // TAR: "ustar" at offset 257
    if (len >= 262) {
      final ustar = String.fromCharCodes(bytes.sublist(257, 262));
      if (ustar == 'ustar') {
        return ViewerType.archive;
      }
    }

    // OLE Compound File: \xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1 (legacy .doc, .xls, .ppt)
    if (len >= 8 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0 &&
        bytes[4] == 0xA1 &&
        bytes[5] == 0xB1 &&
        bytes[6] == 0x1A &&
        bytes[7] == 0xE1) {
      return ViewerType.office;
    }

    // PK\x03\x04 -> ZIP or Office (docx, xlsx, pptx, odt, ods, odp)
    if (len >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      // Check if office or epub extension
      if (fileName != null) {
        final ext = _extractExtension(fileName);
        if (ext == 'docx' ||
            ext == 'xlsx' ||
            ext == 'pptx' ||
            ext == 'doc' ||
            ext == 'xls' ||
            ext == 'ppt' ||
            ext == 'odt' ||
            ext == 'ods' ||
            ext == 'odp' ||
            ext == 'rtf') {
          return ViewerType.office;
        }
        if (ext == 'epub') {
          return ViewerType.epub;
        }
      }
      // Check if bytes contain OpenXML or OpenDocument signatures
      final sampleStr = String.fromCharCodes(bytes);
      if (sampleStr.contains('[Content_Types].xml') ||
          sampleStr.contains('word/') ||
          sampleStr.contains('xl/') ||
          sampleStr.contains('ppt/') ||
          sampleStr.contains('mimetypeapplication/vnd.oasis.opendocument')) {
        return ViewerType.office;
      }
      return ViewerType.archive;
    }

    // SVG: check first 4KB for <svg
    if (len >= 4) {
      final checkLen = len < 4096 ? len : 4096;
      final text = String.fromCharCodes(bytes.sublist(0, checkLen)).toLowerCase();
      if (text.contains('<svg')) {
        return ViewerType.svg;
      }
    }

    // HTML: check first 4KB for <!DOCTYPE html or <html
    if (len >= 5) {
      final checkLen = len < 4096 ? len : 4096;
      final text = String.fromCharCodes(bytes.sublist(0, checkLen)).toLowerCase();
      if (text.contains('<!doctype html') ||
          text.contains('<html') ||
          text.contains('<head') ||
          text.contains('<body')) {
        return ViewerType.html;
      }
    }

    return null;
  }

  static bool _isTextHeuristic(Uint8List bytes) {
    if (bytes.isEmpty) return true;

    // Check for UTF-16 BOM: FF FE (LE) or FE FF (BE)
    if (bytes.length >= 2) {
      if ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF)) {
        return true;
      }
    }

    // Check for UTF-8 BOM: EF BB BF
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return true;
    }

    int printableCount = 0;
    int nullCount = 0;
    final total = bytes.length;

    for (int i = 0; i < total; i++) {
      final b = bytes[i];
      if (b == 0x00) {
        nullCount++;
      } else if (b == 0x09 || b == 0x0A || b == 0x0D || (b >= 0x20 && b <= 0x7E)) {
        printableCount++;
      } else if (b >= 0x80) {
        // High byte (UTF-8 multi-byte candidate)
        printableCount++;
      }
    }

    // If more than 1% null bytes and not UTF-16, it's binary
    if (nullCount > total * 0.01) {
      return false;
    }

    // >90% printable characters
    return (printableCount / total) >= 0.90;
  }

  static String? _extractExtension(String path) {
    final slashIndex = path.lastIndexOf('/');
    final backslashIndex = path.lastIndexOf('\\');
    final lastSep = slashIndex > backslashIndex ? slashIndex : backslashIndex;
    final filename = lastSep != -1 ? path.substring(lastSep + 1) : path;

    // Dotfiles without additional extension (e.g. .gitignore, .env)
    if (filename.startsWith('.') && filename.indexOf('.', 1) == -1) {
      return null;
    }

    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == filename.length - 1) return null;
    return filename.substring(dotIndex + 1).toLowerCase();
  }
}
