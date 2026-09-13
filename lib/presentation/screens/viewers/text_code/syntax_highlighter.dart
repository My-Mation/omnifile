import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' as hl;
import '../../../../core/theme/open_file_colors.dart';

class CodeSyntaxHighlighter {
  final OpenFileColors colors;
  final String? language;

  CodeSyntaxHighlighter({
    required this.colors,
    this.language,
  });

  TextSpan highlight(String text, TextStyle baseStyle) {
    if (language == null) {
      return TextSpan(text: text, style: baseStyle);
    }

    try {
      final result = hl.highlight.parse(text, language: language, autoDetection: false);
      final nodes = result.nodes;
      if (nodes == null || nodes.isEmpty) {
        return TextSpan(text: text, style: baseStyle);
      }

      final children = <InlineSpan>[];
      for (final node in nodes) {
        children.add(_convertNode(node, baseStyle));
      }
      return TextSpan(style: baseStyle, children: children);
    } catch (_) {
      return TextSpan(text: text, style: baseStyle);
    }
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
      case 'bullet':
        return baseStyle.copyWith(
          color: colors.fileCode,
        );

      case 'emphasis':
        return baseStyle.copyWith(fontStyle: FontStyle.italic);

      case 'strong':
        return baseStyle.copyWith(fontWeight: FontWeight.bold);

      default:
        return baseStyle;
    }
  }
}
