import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/localization.dart';
import 'license_catalog.dart';

class AppLicensesPage extends StatefulWidget {
  const AppLicensesPage({super.key, this.loadLicenses});
  final Future<List<LicenseEntry>> Function()? loadLicenses;
  @override
  State<AppLicensesPage> createState() => _AppLicensesPageState();
}

class _AppLicensesPageState extends State<AppLicensesPage> {
  late Future<List<ProjectLicenses>> entries = load();
  Future<List<ProjectLicenses>> load() async => groupProjectLicenses(
    await (widget.loadLicenses?.call() ?? LicenseRegistry.licenses.toList()),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.openSourceLicenses)),
    body: FutureBuilder<List<ProjectLicenses>>(
      future: entries,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.licensesFailed),
                  TextButton(
                    onPressed: () => setState(() {
                      entries = load();
                    }),
                    child: Text(context.l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }
        final projects = snap.data ?? [];
        if (projects.isEmpty) {
          return Center(child: Text(context.l10n.licensesEmpty));
        }
        final byName = {
          for (final project in projects) project.package: project,
        };
        return ListView(
          key: const PageStorageKey('featured-licenses'),
          padding: const EdgeInsets.all(24),
          children: [
            for (final name in featuredLicensePackages)
              if (byName[name] case final project?)
                _ProjectRow(
                  project: project,
                  purpose: _purpose(context.l10n, name),
                ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AllLicensesPage(projects: projects),
                  ),
                ),
                child: Text(context.l10n.viewAllLicenses),
              ),
            ),
          ],
        );
      },
    ),
  );
}

String _purpose(AppLocalizations l, String package) => switch (package) {
  'flutter' => l.licenseFramework,
  'sqflite' => l.licenseDatabase,
  'shared_preferences' => l.licensePreferences,
  'package_info_plus' => l.licenseAppInformation,
  'url_launcher' => l.licenseExternalLinks,
  _ => '',
};

String _name(BuildContext context, ProjectLicenses project) =>
    project.package.isEmpty
    ? context.l10n.otherLicenseNotices
    : project.displayName;

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, this.purpose});
  final ProjectLicenses project;
  final String? purpose;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(_name(context, project)),
    subtitle: purpose == null ? null : Text(purpose!),
    trailing: const ExcludeSemantics(
      child: Icon(Icons.chevron_right, size: 22),
    ),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LicenseDetailPage(project: project),
      ),
    ),
  );
}

class _AllLicensesPage extends StatelessWidget {
  const _AllLicensesPage({required this.projects});
  final List<ProjectLicenses> projects;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.allOpenSourceLicenses)),
    body: ListView.builder(
      key: const PageStorageKey('all-licenses'),
      padding: const EdgeInsets.all(24),
      itemCount: projects.length,
      itemBuilder: (_, index) => _ProjectRow(project: projects[index]),
    ),
  );
}

class _LicenseDetailPage extends StatelessWidget {
  const _LicenseDetailPage({required this.project});
  final ProjectLicenses project;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_name(context, project))),
    body: ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: project.notices.length,
      separatorBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(),
      ),
      itemBuilder: (_, index) => SelectableText(project.notices[index]),
    ),
  );
}
