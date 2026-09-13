import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/viewer_setting_list.dart';
import 'package:flutter/material.dart';

class ViewerSettingPage extends StatefulWidget {
  const ViewerSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _ViewerSettingState();
}

class _ViewerSettingState extends State<ViewerSettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).ReaderSettings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: const ViewerSettingList(),
        ),
      ),
    );
  }
}
