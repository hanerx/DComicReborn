import 'package:dcomic/generated/l10n.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<StatefulWidget> createState() => _SplashPage();
}

class _SplashPage extends State<SplashPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlutterLogo(
              size: 100,
            ),
            Text(S.of(context).AppName, style: TextStyle(fontSize: 30, color: Theme.of(context).disabledColor),),
            Text(S.of(context).Loading, style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor),)
          ],
        ),
      ),
    );
  }
}
