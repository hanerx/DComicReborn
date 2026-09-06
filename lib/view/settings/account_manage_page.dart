import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/components/dcomic_mark.dart';
import 'package:dcomic/view/settings/account_login_page.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AccountManagePage extends StatefulWidget {
  const AccountManagePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _AccountManagePageState();
  }
}

class _AccountManagePageState extends State<AccountManagePage> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).AccountSettings),
      ),
      body: EasyRefresh(
        onRefresh: () {
          Provider.of<ComicSourceProvider>(context, listen: false).callNotify();
        },
        child: ListView.builder(
          padding: EdgeInsets.only(
            top: 12,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: Provider.of<ComicSourceProvider>(context)
              .hasAccountSettingSources
              .length,
          itemBuilder: (context, index) {
            var sourceModel = Provider.of<ComicSourceProvider>(context)
                .hasAccountSettingSources[index];
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                ListTile(
                  title: Text(
                    sourceModel.type.sourceName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  leading: SizedBox(
                    height: 50,
                    width: 50,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: sourceModel.accountModel?.avatar != null
                          ? DComicImage(
                              sourceModel.accountModel!.avatar!,
                              errorMessageOverflow: TextOverflow.ellipsis,
                              showErrorMessage: false,
                              errorLogoSize: 48,
                              fit: BoxFit.cover,
                            )
                          : const DComicMark(size: 50),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).AccountManagePageSubtitleNickname(
                            sourceModel.accountModel!.nickname != null
                                ? sourceModel.accountModel!.nickname!
                                : ""),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        S.of(context).AccountManagePageSubtitleUID(
                            sourceModel.accountModel!.uid != null
                                ? sourceModel.accountModel!.uid!
                                : ""),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        S.of(context).AccountManagePageSubtitleUsername(
                            sourceModel.accountModel!.username != null
                                ? sourceModel.accountModel!.username!
                                : ""),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      )
                    ],
                  ),
                  trailing: IconButton(
                      onPressed: () {
                        if (sourceModel.accountModel!.isLogin) {
                          sourceModel.accountModel!.logout().then((value) =>
                              Provider.of<ComicSourceProvider>(context,
                                      listen: false)
                                  .callNotify());
                        } else {
                          Provider.of<NavigatorProvider>(context, listen: false)
                              .getNavigator(
                                  context, NavigatorType.defaultNavigator)
                              ?.push(MaterialPageRoute(
                                  builder: (context) => AccountLoginPage(
                                        sourceModel: sourceModel,
                                      ),
                                  settings: const RouteSettings(
                                      name: 'AccountLoginPage')))
                              .then((value) => Provider.of<ComicSourceProvider>(
                                      context,
                                      listen: false)
                                  .callNotify());
                        }
                      },
                      icon: Icon(sourceModel.accountModel!.isLogin
                          ? Icons.logout
                          : Icons.login)),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant),
                ListTile(
                  leading: Icon(Icons.token, color: colorScheme.primary),
                  title: Text(S.of(context).TokenCopy),
                  dense: true,
                  enabled: sourceModel.accountModel?.token != null,
                  onTap: () {
                    if (sourceModel.accountModel?.token != null) {
                      Clipboard.setData(ClipboardData(
                              text: sourceModel.accountModel!.token!))
                          .then((value) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(S.of(context).TokenCopied),
                          ));
                        }
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(S.of(context).RequireLoginForToken),
                      ));
                    }
                  },
                )
              ]),
            );
          },
        ),
      ),
    );
  }
}
