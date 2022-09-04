import 'dart:math';

import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/view/components/list_card.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:fluttericon/font_awesome_icons.dart';

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
                    leading: const Padding(padding:EdgeInsets.all(10),child: Icon(Icons.system_update)),
                    title: const Text('Check For Update'),
                    subtitle: const Text('v2.0.0'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Padding(padding:EdgeInsets.all(10),child: Icon(FontAwesome5.git_alt)),
                    title: const Text('Update Channel'),
                    subtitle: const Text('Develop'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: ListCard(
                color: Theme.of(context).colorScheme.secondaryContainer,
                children: [
                  ListTile(
                    leading: const Padding(padding:EdgeInsets.all(10),child: Icon(FontAwesome5.github_alt)),
                    title: const Text('Github'),
                    subtitle:
                        const Text('https://github.com/hanerx/DComicReborn'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Padding(padding:EdgeInsets.all(10),child:Icon(FontAwesome5.clipboard_list)),
                    title: const Text('Change Log'),
                    subtitle:
                    const Text('Change Log For Each Version'),
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
                    leading: const Padding(padding:EdgeInsets.all(10),child: Icon(FontAwesome5.app_store)),
                    title: const Text('About'),
                    subtitle:
                    const Text('About DComicReborn'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
