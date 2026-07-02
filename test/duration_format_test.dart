import 'package:flutter_test/flutter_test.dart';

import 'package:focustrace/focus_trace.dart';

void main() {
  group('DurationFormat', () {
    test('formats compact durations', () {
      expect(DurationFormat.compact(const Duration(seconds: 20)), '<1m');
      expect(DurationFormat.compact(const Duration(minutes: 45)), '45m');
      expect(DurationFormat.compact(const Duration(hours: 2)), '2h');
      expect(
        DurationFormat.compact(const Duration(hours: 2, minutes: 15)),
        '2h 15m',
      );
    });

    test('formats clock durations', () {
      expect(
        DurationFormat.clock(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });
}
