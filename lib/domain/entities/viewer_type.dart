enum ViewerType {
  pdf,
  text,
  markdown,
  image,
  video,
  audio,
  archive,
  html,
  code,
  office,
  epub,
  json,
  svg,
  hex,
  unknown;

  String get displayName {
    switch (this) {
      case ViewerType.pdf:
        return 'PDF';
      case ViewerType.text:
        return 'Text';
      case ViewerType.markdown:
        return 'Markdown';
      case ViewerType.image:
        return 'Image';
      case ViewerType.video:
        return 'Video';
      case ViewerType.audio:
        return 'Audio';
      case ViewerType.archive:
        return 'Archive';
      case ViewerType.html:
        return 'HTML';
      case ViewerType.code:
        return 'Code';
      case ViewerType.office:
        return 'Document';
      case ViewerType.epub:
        return 'eBook';
      case ViewerType.json:
        return 'JSON';
      case ViewerType.svg:
        return 'Vector SVG';
      case ViewerType.hex:
        return 'Binary (Hex)';
      case ViewerType.unknown:
        return 'Unknown';
    }
  }
}
