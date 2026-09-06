import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/view/components/dcomic_mark.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_string_launcher;

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AboutPageState();
  }
}

class _AboutPageState extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).AboutSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const DComicMark(size: 80),
                const SizedBox(height: 16),
                Text(
                  S.of(context).AppName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  Provider.of<VersionProvider>(context).currentVersion,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _buildPanel(context, [
            ListTile(
              leading: Icon(Icons.system_update, color: colorScheme.primary),
              title: Text(S.of(context).AboutPageCheckForUpdate,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: colorScheme.onSurface)),
              subtitle: Text(
                  Provider.of<VersionProvider>(context).currentVersion,
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: () async {
                if (await Provider.of<VersionProvider>(context, listen: false)
                    .checkUpdate()) {
                  if (context.mounted) {
                    await Provider.of<VersionProvider>(context, listen: false)
                        .showReleaseInfo(context);
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(S.of(context).CheckUpdateUpToDate),
                    ));
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(FontAwesome5.git_alt, color: colorScheme.primary),
              title: Text(S.of(context).AboutPageUpdateChannel,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: colorScheme.onSurface)),
              subtitle: Text(
                  S.of(context).AboutPageUpdateChannelModes(
                      Provider.of<VersionProvider>(context).channel.name),
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: () {
                var index = UpdateChannel.values.indexOf(
                    Provider.of<VersionProvider>(context, listen: false)
                        .channel);
                index++;
                if (index >= UpdateChannel.values.length) {
                  index = 0;
                }
                Provider.of<VersionProvider>(context, listen: false).channel =
                    UpdateChannel.values[index];
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.new_releases_outlined, color: colorScheme.primary),
              title: Text(S.of(context).SettingPageShowReleaseInfo,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: colorScheme.onSurface)),
              subtitle: Text(
                  Provider.of<VersionProvider>(context).latestVersion,
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: () async {
                await Provider.of<VersionProvider>(context, listen: false)
                    .showReleaseInfo(context);
              },
            ),
          ]),
          _buildPanel(context, [
            ListTile(
              leading:
                  Icon(FontAwesome5.github_alt, color: colorScheme.primary),
              title: Text(S.of(context).AboutPageGithub,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: colorScheme.onSurface)),
              subtitle: Text(S.of(context).AboutPageGithubUrl,
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: () async {
                if (await url_string_launcher
                    .canLaunchUrlString(S.of(context).AboutPageGithubUrl)) {
                  if (context.mounted) {
                    url_string_launcher
                        .launchUrlString(S.of(context).AboutPageGithubUrl);
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: colorScheme.primary),
              title: Text(S.of(context).AboutPageAbout,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: colorScheme.onSurface)),
              subtitle: Text(S.of(context).AboutPageAboutSubtitle,
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: () {
                showAboutDialog(
                    context: context,
                    applicationVersion:
                        Provider.of<VersionProvider>(context, listen: false)
                            .currentVersion,
                    children: [
                      Text(S.of(context).AboutPageAboutDialogueDescription)
                    ]);
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}
