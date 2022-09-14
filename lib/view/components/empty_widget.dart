import 'package:dcomic/generated/l10n.dart';
import 'package:flutter/material.dart';

class EmptyWidget extends StatelessWidget{
  final String? title;
  final IconData? icon;
  final List<Widget>? children;

  const EmptyWidget({super.key, this.title, this.icon, this.children});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
        children: _buildWidgetList(context)
    ),);
  }

  List<Widget> _buildWidgetList(BuildContext context){
    List<Widget> data=[
      Icon(icon ?? Icons.folder_off_outlined,size: 60,color: Theme.of(context).disabledColor,),
      Text(title==null?S.of(context).Empty:title!,overflow: TextOverflow.ellipsis,style: TextStyle(color: Theme.of(context).disabledColor,fontSize: 18),),
    ];
    if(children!=null){
      data+=children!;
    }
    return data;
  }

}