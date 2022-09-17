import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AccountLoginPage extends StatefulWidget {
  final BaseComicSourceModel sourceModel;
  const AccountLoginPage({super.key, required this.sourceModel});

  @override
  State<StatefulWidget> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
          appBar: AppBar(
            title: Text("Login"),
            elevation: 0,
          ),
          body: Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: widget.sourceModel
                .accountModel!
                .buildLoginWidget(context),
          ),
        );
  }
}
