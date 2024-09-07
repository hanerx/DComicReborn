import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:flutter/material.dart';

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
            title: Text(S.of(context).LoginPageTitle),
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
