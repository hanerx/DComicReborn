import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<StatefulWidget> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).DebugSettings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.network_check),
            title: Text(S.of(context).DebugPageNetworkCheck),
            subtitle: Text(S.of(context).DebugPageNetworkCheckDescription),
            onTap: () async {
              var request = RequestHandler("https://dmzj.com");
              await Future.delayed(const Duration(seconds: 1));
              int ping = await request.ping();
              var cookies = await request.cookieManager.cookieJar
                  .loadForRequest(Uri.https("dmzj.com",'/'));
              print(cookies);
              DatabaseInstance.instance.then((value) async => print(await value.cookieDao.getAllCookies()));

            },
          )
        ],
      ),
    );
  }
}
