import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' as hl;
import '../../../../core/theme/open_file_colors.dart';

class SyntaxHighlightingController extends TextEditingController {
  OpenFileColors colors;
  String? language;
  String searchQuery = '';
  int currentMatchIndex = -1;

  SyntaxHighlightingController({
    super.text,
    required this.colors,
    this.language,
  });

  void updateSettings({
    required OpenFileColors newColors,
    String? newLanguage,
    String? newSearchQuery,
    int? newMatchIndex,
  }) {
    colors = newColors;
    if (newLanguage != null) language = newLanguage;
    if (newSearchQuery != null) searchQuery = newSearchQuery;
    if (newMatchIndex != null) currentMatchIndex = newMatchIndex;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? TextStyle(color: colors.textPrimary);
    final content = text;

    if (content.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    // If search is active, we overlay search highlights on the text
    if (searchQuery.isNotEmpty) {
      return _buildSearchHighlightedSpan(content, baseStyle);
    }

    // Standard syntax highlight
    if (language != null && language!.isNotEmpty) {
      try {
        final result = hl.highlight.parse(content, language: language, autoDetection: false);
        final nodes = result.nodes;
        if (nodes != null && nodes.isNotEmpty) {
          final spans = <InlineSpan>[];
          for (final node in nodes) {
            spans.add(_convertNode(node, baseStyle));
          }
          return TextSpan(style: baseStyle, children: spans);
        }
      } catch (_) {
        // Fallback to plain text on parse error
      }
    }

    return TextSpan(style: baseStyle, text: content);
  }

  InlineSpan _convertNode(hl.Node node, TextStyle baseStyle) {
    if (node.value != null) {
      return TextSpan(
        text: node.value,
        style: _getNodeStyle(node.className, baseStyle),
      );
    }

    final children = <InlineSpan>[];
    if (node.children != null) {
      for (final child in node.children!) {
        children.add(_convertNode(child, baseStyle));
      }
    }

    return TextSpan(
      style: _getNodeStyle(node.className, baseStyle),
      children: children,
    );
  }

  TextStyle _getNodeStyle(String? className, TextStyle baseStyle) {
    if (className == null) return baseStyle;

    switch (className) {
      case 'keyword':
      case 'selector-tag':
      case 'built_in':
      case 'name':
      case 'tag':
        return baseStyle.copyWith(
          color: colors.accentPrimary,
          fontWeight: FontWeight.w600,
        );

      case 'string':
      case 'title':
      case 'section':
      case 'attribute':
      case 'literal':
      case 'template-tag':
      case 'template-variable':
      case 'type':
      case 'addition':
        return baseStyle.copyWith(
          color: colors.stateSuccess,
        );

      case 'comment':
      case 'quote':
      case 'deletion':
      case 'meta':
        return baseStyle.copyWith(
          color: colors.textDisabled,
          fontStyle: FontStyle.italic,
        );

      case 'number':
      case 'regexp':
      case 'link':
        return baseStyle.copyWith(
          color: colors.stateWarning,
        );

      case 'subst':
      case 'symbol':
      case 'class':
      case 'function':
      case 'title.function':
        return baseStyle.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w600,
        );

      default:
        return baseStyle;
    }
  }

  TextSpan _buildSearchHighlightedSpan(String content, TextStyle baseStyle) {
    final lowerContent = content.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final queryLen = searchQuery.length;
    final spans = <InlineSpan>[];

    int start = 0;
    int matchIdx = 0;

    while (true) {
      final index = lowerContent.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < content.length) {
          spans.add(_highlightChunk(content.substring(start), baseStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(_highlightChunk(content.substring(start, index), baseStyle));
      }

      final isCurrent = matchIdx == currentMatchIndex;
      final matchBg = isCurrent
          ? colors.accentPrimary.withValues(alpha: 0.70)
          : colors.accentPrimary.withValues(alpha: 0.28);

      spans.add(
        TextSpan(
          text: content.substring(index, index + queryLen),
          style: baseStyle.copyWith(
            backgroundColor: matchBg,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + queryLen;
      matchIdx++;
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  InlineSpan _highlightChunk(String chunk, TextStyle baseStyle) {
    if (language != null && language!.isNotEmpty) {
      try {
        final result = hl.highlight.parse(chunk, language: language, autoDetection: false);
        final nodes = result.nodes;
        if (nodes != null && nodes.isNotEmpty) {
          final spans = <InlineSpan>[];
          for (final n in nodes) {
            spans.add(_convertNode(n, baseStyle));
          }
          return TextSpan(style: baseStyle, children: spans);
        }
      } catch (_) {}
    }
    return TextSpan(text: chunk, style: baseStyle);
  }
}
