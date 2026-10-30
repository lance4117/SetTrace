import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/features/rest_alerts/rest_delivery_status.dart';

void main() {
  test('partial status distinguishes false, unknown and read failures', () {
    final status = RestDeliveryStatus.fromMap({
      'version': 1,
      'capturedUtc': 1000,
      'instance': 'runtime',
      'fields': {
        'powerSave': {
          'availability': 'available',
          'value': false,
          'observedUtc': 1000,
        },
        'vendorAutostart': {
          'availability': 'unknown',
          'value': null,
          'observedUtc': 1000,
        },
        'restChannel': {
          'availability': 'read_failed',
          'value': null,
          'reason': 'read_failed',
        },
      },
    });
    expect(status.fields['powerSave']!.value, false);
    expect(status.fields['vendorAutostart']!.availability, 'unknown');
    expect(status.fields['restChannel']!.availability, 'read_failed');
    expect(() => status.fields.clear(), throwsUnsupportedError);
  });
  test('unsupported version and invalid availability are rejected', () {
    expect(
      () => RestDeliveryStatus.fromMap({'version': 2}),
      throwsFormatException,
    );
    expect(
      () => RestStatusField.fromMap({'availability': 'probably_ok'}),
      throwsFormatException,
    );
  });
}
