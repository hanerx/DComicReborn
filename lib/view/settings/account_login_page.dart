import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:flutter/material.dart';

class AccountLoginPage extends StatefulWidget {
  final BaseComicSourceModel sourceModel;
  const AccountLoginPage({super.key, required this.sourceModel});

  @override
  State<StatefulWidget> createState() {
    return _AccountLoginPageState();
  }
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: Text(S.of(context).LoginPageTitle),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: widget.sourceModel.accountModel!.buildLoginWidget(context),
          ),
        ),
      ),
    );
  }
}
