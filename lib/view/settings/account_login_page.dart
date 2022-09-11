import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AccountLoginPage extends StatefulWidget {
  const AccountLoginPage({super.key});

  @override
  State<StatefulWidget> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Provider.of<ComicSourceProvider>(context)
            .activeModel
            .accountModel!
            .buildLoginWidget(context),
      ),
    );
  }
}
