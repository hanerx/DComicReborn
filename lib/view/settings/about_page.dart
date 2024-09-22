import 'dart:math';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/version_provider.dart';
import 'package:dcomic/view/components/list_card.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart' as url_string_launcher;

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<StatefulWidget> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const _imgHeight = 80.0;
  static const _expandedHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EasyRefresh(
        header: BuilderHeader(
          clamping: false,
          position: IndicatorPosition.locator,
          triggerOffset: 100000,
          notifyWhenInvisible: true,
          builder: (context, state) {
            const expandedExtent = _expandedHeight - kToolbarHeight;
            final pixels = state.notifier.position.pixels;
            final height = state.offset + _imgHeight;
            final clipEndHeight = pixels < expandedExtent
                ? _imgHeight
                : max(0.0, _imgHeight - pixels + expandedExtent);
            final imgHeight = pixels < expandedExtent
                ? _imgHeight
                : max(0.0, _imgHeight - (pixels - expandedExtent));
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ClipPath(
                  clipper: _TrapezoidClipper(
                    height: height,
                    clipStartHeight: 0.0,
                    clipEndHeight: clipEndHeight,
                  ),
                  child: Container(
                    height: height,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Positioned(
                  top: -1,
                  left: 0,
                  right: 0,
                  child: ClipPath(
                    clipper: _FillLineClipper(imgHeight),
                    child: Container(
                      height: 2,
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 0,
                  child: ClipOval(
                    child: FlutterLogo(
                      size: 80,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        onRefresh: () {},
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              expandedHeight: _expandedHeight,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  S.of(context).AppName,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
                centerTitle: true,
              ),
            ),
            const HeaderLocator.sliver(paintExtent: 80),
            SliverToBoxAdapter(
              child: ListCard(
                color: Theme.of(context).colorScheme.primaryContainer,
                children: [
                  ListTile(
                    leading: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.system_update)),
                    title: Text(S.of(context).AboutPageCheckForUpdate),
                    subtitle: Text(
                        Provider.of<VersionProvider>(context).currentVersion),
                    onTap: () async {
                      if (await Provider.of<VersionProvider>(context,
                              listen: false)
                          .checkUpdate()) {
                        if (context.mounted) {
                          await showReleaseInfo(context);
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
                    leading: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(FontAwesome5.git_alt)),
                    title: Text(S.of(context).AboutPageUpdateChannel),
                    subtitle: Text(S.of(context).AboutPageUpdateChannelModes(
                        Provider.of<VersionProvider>(context).channel.name)),
                    onTap: () {
                      var index = UpdateChannel.values.indexOf(
                          Provider.of<VersionProvider>(context, listen: false)
                              .channel);
                      index++;
                      if (index >= UpdateChannel.values.length) {
                        index = 0;
                      }
                      Provider.of<VersionProvider>(context, listen: false)
                          .channel = UpdateChannel.values[index];
                    },
                  ),
                  ListTile(
                    leading: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.new_releases)),
                    title: Text(S.of(context).SettingPageShowReleaseInfo),
                    subtitle: Text(
                        Provider.of<VersionProvider>(context).latestVersion),
                    onTap: () async {
                      await showReleaseInfo(context);
                    },
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: ListCard(
                color: Theme.of(context).colorScheme.secondaryContainer,
                children: [
                  ListTile(
                    leading: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(FontAwesome5.github_alt)),
                    title: Text(S.of(context).AboutPageGithub),
                    subtitle: Text(S.of(context).AboutPageGithubUrl),
                    onTap: () async {
                      if (await url_string_launcher.canLaunchUrlString(
                          S.of(context).AboutPageGithubUrl)) {
                        if (context.mounted) {
                          url_string_launcher.launchUrlString(
                              S.of(context).AboutPageGithubUrl);
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(FontAwesome5.clipboard_list)),
                    title: Text(S.of(context).AboutPageChangeLog),
                    subtitle: Text(S.of(context).AboutPageChangeLogSubtitle),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: ListCard(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                children: [
                  ListTile(
                    leading: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(FontAwesome5.app_store)),
                    title: Text(S.of(context).AboutPageAbout),
                    subtitle: Text(S.of(context).AboutPageAboutSubtitle),
                    onTap: () {
                      showAboutDialog(
                          context: context,
                          applicationVersion: Provider.of<VersionProvider>(
                                  context,
                                  listen: false)
                              .currentVersion,
                          children: [
                            Text(
                                S.of(context).AboutPageAboutDialogueDescription)
                          ]);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showReleaseInfo(BuildContext context) async {
    ReleaseInfo? releaseInfo =
        await Provider.of<VersionProvider>(context, listen: false)
            .getLatestUpdateInfo();
    if (releaseInfo != null) {
      if (context.mounted) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title:
                      Text(S.of(context).ReleaseInfoTitle(releaseInfo.version)),
                  content: Text(releaseInfo.desc),
                  actions: [
                    TextButton(
                        onPressed: () async {
                          if (await url_string_launcher
                              .canLaunchUrlString(releaseInfo.releaseUrl)) {
                            if (context.mounted) {
                              url_string_launcher
                                  .launchUrlString(releaseInfo.releaseUrl);
                            }
                          }
                        },
                        child: Text(S.of(context).AboutPageGithub)),
                    TextButton(
                        onPressed: () async {
                          if (await url_string_launcher
                              .canLaunchUrlString(releaseInfo.updateUrl)) {
                            if (context.mounted) {
                              url_string_launcher
                                  .launchUrlString(releaseInfo.updateUrl);
                            }
                          }
                        },
                        child: Text(S.of(context).ReleaseInfoDownload))
                  ],
                ));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.of(context).SettingPageFailToGetReleaseInfo)));
      }
    }
  }
}

class _TrapezoidClipper extends CustomClipper<Path> {
  final double height;
  final double clipStartHeight;
  final double clipEndHeight;

  _TrapezoidClipper({
    required this.height,
    required this.clipStartHeight,
    required this.clipEndHeight,
  });

  @override
  Path getClip(Size size) {
    final width = size.width;
    final height = size.height;
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(width, 0);
    path.lineTo(width, height - clipEndHeight);
    path.lineTo(0, height - clipStartHeight);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TrapezoidClipper oldClipper) {
    return oldClipper.height != height ||
        oldClipper.clipStartHeight != clipStartHeight ||
        oldClipper.clipEndHeight != clipEndHeight;
  }
}

class _FillLineClipper extends CustomClipper<Path> {
  final double imgHeight;

  _FillLineClipper(this.imgHeight);

  @override
  Path getClip(Size size) {
    final width = size.width;
    final height = size.height;
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(width, 0);
    path.lineTo(width, height / 2);
    path.lineTo(0, height / 2 + imgHeight / 2);
    path.lineTo(0, height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _FillLineClipper oldClipper) {
    return oldClipper.imgHeight != imgHeight;
  }
}
