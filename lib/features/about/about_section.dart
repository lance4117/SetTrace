import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/localization.dart';
import 'app_info_service.dart';
import 'app_notice_dialog.dart';
import 'licenses_page.dart';

class AboutSection extends StatefulWidget {
  const AboutSection({super.key, this.info = const AppInfoService()});
  final AppInfoService info;
  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  InstalledVersion? version;
  bool loading = true, versionFailed = false, opening = false;
  bool? failedLink;
  @override
  void initState() {
    super.initState();
    readVersion();
  }

  Future<void> readVersion() async {
    setState(() {
      loading = true;
      versionFailed = false;
    });
    try {
      final value = await widget.info.readVersion();
      if (mounted) setState(() => version = value);
    } catch (_) {
      if (mounted) setState(() => versionFailed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openPage(bool issues) async {
    if (opening) return;
    setState(() {
      opening = true;
      failedLink = null;
    });
    try {
      if (!await widget.info.openPage(issues: issues)) {
        throw StateError('externalPageFailed');
      }
    } catch (_) {
      if (mounted) setState(() => failedLink = issues);
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(l.aboutApp, style: TextStyle(color: c.textSecondary)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Image.asset(
                      dark
                          ? 'assets/brand/settrace-symbol-white.png'
                          : 'assets/brand/settrace-symbol.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'SetTrace',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l.appTagline),
              const SizedBox(height: 12),
              if (loading)
                const LinearProgressIndicator()
              else if (versionFailed) ...[
                Text(l.versionUnavailable, style: TextStyle(color: c.danger)),
                TextButton(onPressed: readVersion, child: Text(l.retry)),
              ] else if (version != null)
                Text(
                  '${l.appVersion} ${version!.version} (${version!.buildNumber})',
                  key: const ValueKey('installed-version'),
                  style: TextStyle(color: c.textSecondary),
                ),
              const SizedBox(height: 16),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.projectHome),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.open_in_new, size: 22),
                ),
                enabled: !opening,
                onTap: () => openPage(false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.issueFeedback),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.open_in_new, size: 22),
                ),
                enabled: !opening,
                onTap: () => openPage(true),
              ),
              if (opening) const LinearProgressIndicator(),
              if (failedLink != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l.externalPageFailed,
                    style: TextStyle(color: c.danger),
                  ),
                ),
                TextButton(
                  onPressed: () => openPage(failedLink!),
                  child: Text(l.retry),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.privacyAndData),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.chevron_right, size: 22),
                ),
                onTap: () => showAppNotice(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.openSourceLicenses),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.chevron_right, size: 22),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppLicensesPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
