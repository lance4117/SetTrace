/// Pure query contract. A schedule request does not prove an alarm is still
/// registered or that its sound was heard.
class RestStatusField {
  const RestStatusField(
    this.availability,
    this.value,
    this.observedUtc,
    this.reason,
  );
  final String availability;
  final Object? value;
  final int? observedUtc;
  final String? reason;
  factory RestStatusField.fromMap(Map<dynamic, dynamic> map) {
    final availability = map['availability'];
    if (!const {
      'available',
      'unsupported',
      'unknown',
      'read_failed',
    }.contains(availability)) {
      throw const FormatException('Invalid status availability');
    }
    return RestStatusField(
      availability as String,
      map['value'],
      (map['observedUtc'] as num?)?.toInt(),
      map['reason'] as String?,
    );
  }
}

class RestDeliveryStatus {
  const RestDeliveryStatus(this.capturedUtc, this.instance, this.fields);
  final int? capturedUtc;
  final String? instance;
  final Map<String, RestStatusField> fields;
  factory RestDeliveryStatus.fromMap(Map<dynamic, dynamic> map) {
    if (map['version'] != 1) {
      throw const FormatException('Unsupported delivery status');
    }
    final fields = map['fields'] as Map<dynamic, dynamic>;
    return RestDeliveryStatus(
      (map['capturedUtc'] as num?)?.toInt(),
      map['instance'] as String?,
      Map.unmodifiable(
        fields.map(
          (key, value) =>
              MapEntry(key as String, RestStatusField.fromMap(value as Map)),
        ),
      ),
    );
  }
  factory RestDeliveryStatus.unsupported() =>
      const RestDeliveryStatus(null, null, {});
}
