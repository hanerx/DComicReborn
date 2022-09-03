import 'package:dcomic/generated/l10n.dart';
import 'package:direct_select_flutter/direct_select_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class LeftDrawer extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return _LeftDrawerState();
  }

}

class _LeftDrawerState extends State<LeftDrawer>{
  @override
  Widget build(BuildContext context) {
    List list = buildList(context);
    return Drawer(
      child: DirectSelectContainer(
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: list.length,
          itemBuilder: (context, index) {
            return list[index];
          },
        ),
      ),
    );
  }

  List<Widget> buildList(BuildContext context){
    List<Widget> list=<Widget>[
      UserAccountsDrawerHeader(
        accountName: Text(S.of(context).AppName),
        accountEmail: Text(
          S.of(context).DrawerEmail,
          style: const TextStyle(color: Colors.white60),
        ),
        currentAccountPicture: const FlutterLogo(),
        otherAccountsPictures: const <Widget>[],
      ),
    ];
    return list;
  }

}