import 'package:dcomic/database/database_instance.dart';
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/requests/base_request.dart';
import 'package:dcomic/utils/firbaselogoutput.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:logger/logger.dart';

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
          ),
          ListTile(
            leading: const Icon(FontAwesome5.bug),
            title: Text(S.of(context).DebugPageTryCrash),
            subtitle: Text(S.of(context).DebugPageTryCrashDescription),
            onTap: (){
              Logger logger = Logger(
                  printer: PrettyPrinter(noBoxingByDefault: true,methodCount:2),
                  filter: ProductionFilter(),
                  output: CrashConsoleOutput());
              try{
                dynamic x=0;
                String y=x;
              }catch(e,s){
                logger.e(e,error: e,stackTrace: s);
              }
            },
          ),
          ListTile(
            leading: const Icon(FontAwesome5.database),
            title: Text(S.of(context).DebugPagePrintModelDatabase),
            subtitle: Text(S.of(context).DebugPagePrintModelDatabaseDescription),
            onTap: () async{
              Logger logger = Logger(
                  printer: PrettyPrinter(noBoxingByDefault: true,methodCount:2),
                  filter: ProductionFilter(),
                  output: CrashConsoleOutput());
              var databaseInstance = await DatabaseInstance.instance;
              var configList = await databaseInstance.modelConfigDao.getAllConfig();
              for (var element in configList) {
                print(element);
              }
              print(await databaseInstance.modelConfigDao.getConfigByKeyAndModel("uid", "dmzj"));
            },
          )
        ],
      ),
    );
  }
}
