import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/view/settings/about_page.dart';
import 'package:dcomic/view/settings/debug_page.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class MainSettingPage extends StatefulWidget {
  const MainSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _MainSettingPageState();
}

class _MainSettingPageState extends State<MainSettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).DrawerSetting),
      ),
      body: EasyRefresh(
        header: SecondaryBuilderHeader(
            header: const ClassicHeader(
              mainAxisAlignment: MainAxisAlignment.end,
              position: IndicatorPosition.locator,
              safeArea: false,
              clipBehavior: Clip.none,
            ),
            builder: (context, state, header) => const Center(
                  child: SizedBox(),
                ),
            secondaryDimension: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
            secondaryTriggerOffset: 120),
        onRefresh: (){},
        child: ListView(
          shrinkWrap: false,
          children: [
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode),
              title: Text(S.of(context).ReaderSettings),
              subtitle: Text(S.of(context).ReaderSettingsDescription),
            ),
            ListTile(
              leading: const Icon(Icons.ad_units_outlined),
              title: Text(S.of(context).SourceSettings),
              subtitle: Text(S.of(context).SourceSettingsDescription),
            ),
            ListTile(
              leading: const Icon(Icons.account_box),
              title: Text(S.of(context).AccountSettings),
              subtitle: Text(S.of(context).AccountSettingsDescription),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(S.of(context).DownloadSettings),
              subtitle: Text(S.of(context).DownloadSettingsDescription),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(S.of(context).DebugSettings),
              subtitle: Text(S.of(context).DebugSettingsDescription),
              onTap: (){
                Provider.of<NavigatorProvider>(context, listen: false)
                    .getNavigator(context, NavigatorType.defaultNavigator)
                    ?.push(MaterialPageRoute(
                    builder: (context) => const DebugPage(),
                    settings: const RouteSettings(name: 'DebugPage')));
              },
            ),
            ListTile(
              leading: const Icon(FontAwesome5.flask),
              title: Text(S.of(context).ExperimentalSettings),
              subtitle: Text(S.of(context).ExperimentalSettingsDescription),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.apps),
              title: Text(S.of(context).AboutSettings),
              subtitle: Text(S.of(context).AboutSettingsDescription),
              onTap: (){
                Provider.of<NavigatorProvider>(context, listen: false)
                    .getNavigator(context, NavigatorType.defaultNavigator)
                    ?.push(MaterialPageRoute(
                    builder: (context) => const AboutPage(),
                    settings: const RouteSettings(name: 'AboutPage')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
