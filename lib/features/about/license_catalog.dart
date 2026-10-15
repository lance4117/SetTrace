import 'package:flutter/foundation.dart';

const featuredLicensePackages = [
  'flutter',
  'sqflite',
  'shared_preferences',
  'package_info_plus',
  'url_launcher',
];

class ProjectLicenses {
  ProjectLicenses(this.package, Iterable<String> notices)
    : notices = List.unmodifiable(notices);
  final String package;
  final List<String> notices;
  String get displayName => package == 'flutter' ? 'Flutter' : package;
}

/// Groups by project, preserving every distinct bundled statement.
List<ProjectLicenses> groupProjectLicenses(Iterable<LicenseEntry> entries) {
  final groups = <String, Set<String>>{};
  for (final entry in entries) {
    final names = entry.packages.toSet();
    if (names.isEmpty) names.add('');
    final text = entry.paragraphs.map((p) => p.text).join('\n\n');
    for (final name in names) {
      groups.putIfAbsent(name, () => <String>{}).add(text);
    }
  }
  final names = groups.keys.toList()
    ..sort((a, b) {
      final order = a.toLowerCase().compareTo(b.toLowerCase());
      return order == 0 ? a.compareTo(b) : order;
    });
  return [for (final name in names) ProjectLicenses(name, groups[name]!)];
}
