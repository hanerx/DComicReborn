import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/settings/account_login_page.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AccountManagePage extends StatefulWidget {
  const AccountManagePage({super.key});

  @override
  State<StatefulWidget> createState() => _AccountManagePageState();
}

class _AccountManagePageState extends State<AccountManagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text(S.of(context).AccountSettings),
        ),
        body: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: EasyRefresh(
            onRefresh: () {
              Provider.of<ComicSourceProvider>(context, listen: false)
                  .callNotify();
            },
            child: ListView.builder(
              itemCount: Provider.of<ComicSourceProvider>(context)
                  .hasAccountSettingSources
                  .length,
              itemBuilder: (context, index) {
                var sourceModel = Provider.of<ComicSourceProvider>(context)
                    .hasAccountSettingSources[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.all(10),
                  child: Column(children: [
                    ListTile(
                      title: Text(
                        sourceModel.type.sourceName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      leading: SizedBox(
                        height: 50,
                        width: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: sourceModel.accountModel?.avatar != null
                              ? DComicImage(
                                  sourceModel.accountModel!.avatar!,
                                  errorMessageOverflow: TextOverflow.ellipsis,
                                  showErrorMessage: false,
                                  errorLogoSize: 48,
                                  fit: BoxFit.cover,
                                )
                              : const FlutterLogo(),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(
                            height: 1,
                          ),
                          Text(
                            S.of(context).AccountManagePageSubtitleNickname(
                                sourceModel.accountModel!.nickname != null
                                    ? sourceModel.accountModel!.nickname!
                                    : ""),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            S.of(context).AccountManagePageSubtitleUID(
                                sourceModel.accountModel!.uid != null
                                    ? sourceModel.accountModel!.uid!
                                    : ""),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            S.of(context).AccountManagePageSubtitleUsername(
                                sourceModel.accountModel!.username != null
                                    ? sourceModel.accountModel!.username!
                                    : ""),
                            overflow: TextOverflow.ellipsis,
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
                              Provider.of<NavigatorProvider>(context,
                                      listen: false)
                                  .getNavigator(
                                      context, NavigatorType.defaultNavigator)
                                  ?.push(MaterialPageRoute(
                                      builder: (context) => AccountLoginPage(
                                            sourceModel: sourceModel,
                                          ),
                                      settings: const RouteSettings(
                                          name: 'AccountLoginPage')))
                                  .then((value) =>
                                      Provider.of<ComicSourceProvider>(context,
                                              listen: false)
                                          .callNotify());
                            }
                          },
                          icon: Icon(sourceModel.accountModel!.isLogin
                              ? Icons.logout
                              : Icons.login)),
                    ),
                    const Divider(
                      height: 1,
                    ),
                    ListTile(
                      leading: const Icon(Icons.token),
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
                        }else{
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
        ));
  }
}
