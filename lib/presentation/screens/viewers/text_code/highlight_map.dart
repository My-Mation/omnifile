class HighlightMap {
  HighlightMap._();

  static const Map<String, String> _extensionToLanguage = {
    'py': 'python',
    'js': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'ts': 'typescript',
    'dart': 'dart',
    'java': 'java',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'c': 'c',
    'cpp': 'cpp',
    'cc': 'cpp',
    'cxx': 'cpp',
    'h': 'cpp',
    'hpp': 'cpp',
    'cs': 'cs',
    'go': 'go',
    'rs': 'rust',
    'rb': 'ruby',
    'php': 'php',
    'sh': 'bash',
    'bash': 'bash',
    'zsh': 'bash',
    'bat': 'cmd',
    'cmd': 'cmd',
    'ps1': 'powershell',
    'sql': 'sql',
    'xml': 'xml',
    'json': 'json',
    'yml': 'yaml',
    'yaml': 'yaml',
    'toml': 'ini',
    'ini': 'ini',
    'cfg': 'ini',
    'conf': 'ini',
    'css': 'css',
    'scss': 'scss',
    'html': 'xml',
    'htm': 'xml',
    'xhtml': 'xml',
    'svg': 'xml',
    'md': 'markdown',
    'markdown': 'markdown',
    'mdown': 'markdown',
    'mkdn': 'markdown',
    'mdwn': 'markdown',
    'jsx': 'javascript',
    'tsx': 'typescript',
    'swift': 'swift',
    'scala': 'scala',
    'groovy': 'groovy',
    'gradle': 'groovy',
    'lua': 'lua',
    'r': 'r',
    'diff': 'diff',
    'patch': 'diff',
    'dockerfile': 'dockerfile',
    'makefile': 'makefile',
    'env': 'ini',
    'properties': 'ini',
    'jsonc': 'json',
    'json5': 'json',
  };

  static const Map<String, String> _filenameToLanguage = {
    'makefile': 'makefile',
    'dockerfile': 'dockerfile',
    'containerfile': 'dockerfile',
    'gemfile': 'ruby',
    'rakefile': 'ruby',
    'vagrantfile': 'ruby',
    'cmakelists.txt': 'cmake',
    '.gitignore': 'ini',
    '.gitattributes': 'ini',
    '.gitmodules': 'ini',
    '.env': 'ini',
    '.editorconfig': 'ini',
    '.bashrc': 'bash',
    '.bash_profile': 'bash',
    '.zshrc': 'bash',
    '.profile': 'bash',
  };

  static String? getLanguageForFilename(String fileName) {
    final lower = fileName.toLowerCase().split(RegExp(r'[/\\]')).last;
    if (_filenameToLanguage.containsKey(lower)) {
      return _filenameToLanguage[lower];
    }
    if (lower.startsWith('.env.')) {
      return 'ini';
    }
    if (lower.startsWith('readme')) {
      return 'markdown';
    }
    return null;
  }

  static String? getLanguageForExtension(String extension) {
    return _extensionToLanguage[extension.toLowerCase()];
  }
}
