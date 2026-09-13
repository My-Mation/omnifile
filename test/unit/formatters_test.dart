import 'package:flutter_test/flutter_test.dart';
import 'package:openfile/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    test('formatFileSize formats correctly', () {
      expect(Formatters.formatFileSize(0), '0 B');
      expect(Formatters.formatFileSize(512), '512 B');
      expect(Formatters.formatFileSize(1024), '1.0 KB');
      expect(Formatters.formatFileSize(1536), '1.5 KB');
      expect(Formatters.formatFileSize(1048576), '1.0 MB');
      expect(Formatters.formatFileSize(1048576 * 5), '5.0 MB');
      expect(Formatters.formatFileSize(1048576 * 100), '100 MB');
      expect(Formatters.formatFileSize(1073741824), '1.0 GB');
    });

    test('middleTruncate truncates long text with ellipsis in middle', () {
      expect(Formatters.middleTruncate('short.txt', maxLength: 20), 'short.txt');
      final truncated = Formatters.middleTruncate(
        'very_long_file_name_that_exceeds_length.pdf',
        maxLength: 20,
      );
      expect(truncated.contains('…'), isTrue);
      expect(truncated.length, lessThanOrEqualTo(21));
    });

    test('formatRelativeTime formats properly', () {
      final now = DateTime.now();
      expect(Formatters.formatRelativeTime(now), 'Just now');
      expect(
        Formatters.formatRelativeTime(now.subtract(const Duration(minutes: 5))),
        '5 mins ago',
      );
      expect(
        Formatters.formatRelativeTime(now.subtract(const Duration(hours: 3))),
        '3 hours ago',
      );
      expect(
        Formatters.formatRelativeTime(now.subtract(const Duration(days: 2))),
        '2 days ago',
      );
    });
  });
}
