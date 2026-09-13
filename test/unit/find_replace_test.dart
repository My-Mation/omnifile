import 'package:flutter_test/flutter_test.dart';

int countMatches(String text, String query) {
  if (query.isEmpty) return 0;
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  int count = 0;
  int start = 0;
  while (true) {
    final idx = lowerText.indexOf(lowerQuery, start);
    if (idx == -1) break;
    count++;
    start = idx + lowerQuery.length;
  }
  return count;
}

String replaceMatchAt(String text, String query, String replacement, int matchIndex) {
  if (query.isEmpty) return text;
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  int count = 0;
  int start = 0;
  while (true) {
    final idx = lowerText.indexOf(lowerQuery, start);
    if (idx == -1) break;
    if (count == matchIndex) {
      return text.substring(0, idx) + replacement + text.substring(idx + query.length);
    }
    count++;
    start = idx + lowerQuery.length;
  }
  return text;
}

String replaceAllMatches(String text, String query, String replacement) {
  if (query.isEmpty) return text;
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final sb = StringBuffer();
  int start = 0;
  while (true) {
    final idx = lowerText.indexOf(lowerQuery, start);
    if (idx == -1) {
      sb.write(text.substring(start));
      break;
    }
    sb.write(text.substring(start, idx));
    sb.write(replacement);
    start = idx + lowerQuery.length;
  }
  return sb.toString();
}

void main() {
  group('Find & Replace Unit Tests', () {
    test('counts occurrences accurately', () {
      const sample = 'apple banana apple cherry apple date apple';
      expect(countMatches(sample, 'apple'), 4);
      expect(countMatches(sample, 'orange'), 0);
      expect(countMatches(sample, 'a'), 8);
    });

    test('replaces single match at given index', () {
      const sample = 'first second first third first';
      final replaced = replaceMatchAt(sample, 'first', 'PRIOR', 1);
      expect(replaced, 'first second PRIOR third first');
    });

    test('replace all works on 10+ occurrences correctly', () {
      final input = List.generate(15, (i) => 'item_$i variable = foo;').join('\n');
      expect(countMatches(input, 'foo'), 15);

      final result = replaceAllMatches(input, 'foo', 'bar');
      expect(countMatches(result, 'foo'), 0);
      expect(countMatches(result, 'bar'), 15);
      expect(result.contains('item_0 variable = bar;'), true);
      expect(result.contains('item_14 variable = bar;'), true);
    });

    test('case-insensitive match with exact replacement', () {
      const sample = 'The Foo and foo and FOO';
      final result = replaceAllMatches(sample, 'foo', 'bar');
      expect(result, 'The bar and bar and bar');
    });
  });
}
