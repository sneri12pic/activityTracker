import 'package:flutter_test/flutter_test.dart';

import 'package:focustrace/focus_trace.dart';

void main() {
  test('active status reports tracking', () {
    final status = TrackingStatus.active(UsagePlatform.windows);

    expect(status.platform, UsagePlatform.windows);
    expect(status.isTracking, isTrue);
    expect(status.errorMessage, isNull);
  });

  test('error status keeps message', () {
    final status = TrackingStatus.error(
      platform: UsagePlatform.unsupported,
      message: 'Unsupported',
    );

    expect(status.isTracking, isFalse);
    expect(status.isUnsupported, isTrue);
    expect(status.errorMessage, 'Unsupported');
  });
}
