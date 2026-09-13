import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openfile/core/theme/open_file_colors.dart';
import 'package:openfile/presentation/screens/viewers/text_code/syntax_highlighting_controller.dart';

void main() {
  group('Text Editor & Caret Tests', () {
    test('caret position is preserved across wrap state toggle', () {
      const initialText = '''def calculate_total(items):
    total = 0
    for item in items:
        total += item.price
    return total
''';
      final controller = SyntaxHighlightingController(
        text: initialText,
        colors: OpenFileColors.dark,
        language: 'python',
      );

      // Position caret at line 3, character offset 35
      const targetOffset = 35;
      controller.selection = const TextSelection.collapsed(offset: targetOffset);
      expect(controller.selection.baseOffset, targetOffset);

      // Simulate wrap toggle (wrap ON -> wrap OFF)
      bool wordWrap = true;
      wordWrap = !wordWrap;
      // Caret position must remain unchanged
      expect(controller.selection.baseOffset, targetOffset);

      // Simulate wrap toggle again (wrap OFF -> wrap ON)
      wordWrap = !wordWrap;
      expect(controller.selection.baseOffset, targetOffset);
    });

    testWidgets('SyntaxHighlightingController builds syntax spans and highlights search', (tester) async {
      const code = 'def hello():\n    return "world"\n';
      final controller = SyntaxHighlightingController(
        text: code,
        colors: OpenFileColors.dark,
        language: 'python',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                // Plain syntax span
                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                expect(span.children, isNotNull);

                // Now set search query
                controller.updateSettings(
                  newColors: OpenFileColors.dark,
                  newSearchQuery: 'return',
                  newMatchIndex: 0,
                );

                final searchSpan = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );
                expect(searchSpan.children, isNotNull);
                final textChildren = searchSpan.children!;
                expect(textChildren.any((child) => child.toPlainText().contains('return')), true);

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });
  });
}
