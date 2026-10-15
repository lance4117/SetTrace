import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

typedef InstalledVersion = ({String version, String buildNumber});

/// Only explicit user actions open these public pages. No user data is sent.
class AppInfoService {
  const AppInfoService({this.launch});
  final Future<bool> Function(Uri)? launch;
  static final projectUri = Uri.parse('https://github.com/lance4117/SetTrace');
  static final issuesUri = Uri.parse(
    'https://github.com/lance4117/SetTrace/issues',
  );
  Future<InstalledVersion> readVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, buildNumber: info.buildNumber);
  }

  Future<bool> openPage({required bool issues}) {
    final uri = issues ? issuesUri : projectUri;
    if (launch != null) return launch!(uri);
    return launchUrl(
      issues ? issuesUri : projectUri,
      mode: LaunchMode.externalApplication,
    );
  }
}
