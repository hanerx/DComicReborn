import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/components/dcomic_mark.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
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
    return SettingsPage(
      title: Text(S.of(context).AccountSettings),
      body: EasyRefresh(
        onRefresh: () {
          Provider.of<ComicSourceProvider>(context, listen: false).callNotify();
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
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
                return SettingsCard(
                  key: ValueKey(sourceModel),
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        title: Text(
                          sourceModel.type.sourceName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        leading: SizedBox(
                          height: 48,
                          width: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: sourceModel.accountModel?.avatar != null
                                ? DComicImage(
                                    sourceModel.accountModel!.avatar!,
                                    errorMessageOverflow: TextOverflow.ellipsis,
                                    showErrorMessage: false,
                                    errorLogoSize: 48,
                                    fit: BoxFit.cover,
                                  )
                                : const DComicMark(size: 48),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S
                                  .of(context)
                                  .AccountManagePageSubtitleNickname(
                                    sourceModel.accountModel!.nickname != null
                                        ? sourceModel.accountModel!.nickname!
                                        : "",
                                  ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              S
                                  .of(context)
                                  .AccountManagePageSubtitleUID(
                                    sourceModel.accountModel!.uid != null
                                        ? sourceModel.accountModel!.uid!
                                        : "",
                                  ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              S
                                  .of(context)
                                  .AccountManagePageSubtitleUsername(
                                    sourceModel.accountModel!.username != null
                                        ? sourceModel.accountModel!.username!
                                        : "",
                                  ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            if (sourceModel.accountModel!.isLogin) {
                              sourceModel.accountModel!.logout().then(
                                (value) => Provider.of<ComicSourceProvider>(
                                  context,
                                  listen: false,
                                ).callNotify(),
                              );
                            } else {
                              Provider.of<NavigatorProvider>(
                                    context,
                                    listen: false,
                                  )
                                  .getNavigator(
                                    context,
                                    NavigatorType.defaultNavigator,
                                  )
                                  ?.push(
                                    MaterialPageRoute(
                                      builder: (context) => AccountLoginPage(
                                        sourceModel: sourceModel,
                                      ),
                                      settings: const RouteSettings(
                                        name: 'AccountLoginPage',
                                      ),
                                    ),
                                  )
                                  .then(
                                    (value) => Provider.of<ComicSourceProvider>(
                                      context,
                                      listen: false,
                                    ).callNotify(),
                                  );
                            }
                          },
                          icon: Icon(
                            sourceModel.accountModel!.isLogin
                                ? Icons.logout
                                : Icons.login,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      SettingsTile(
                        leading: const Icon(Icons.token),
                        title: Text(S.of(context).TokenCopy),
                        enabled: sourceModel.accountModel?.token != null,
                        onTap: () {
                          if (sourceModel.accountModel?.token != null) {
                            Clipboard.setData(
                              ClipboardData(
                                text: sourceModel.accountModel!.token!,
                              ),
                            ).then((value) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(S.of(context).TokenCopied),
                                  ),
                                );
                              }
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  S.of(context).RequireLoginForToken,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
