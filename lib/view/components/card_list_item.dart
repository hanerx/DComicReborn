import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

class CardListItem extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: (){},
        radius: 3,
        child: Card(
          color: Colors.transparent,
          elevation: 0,
          child: Row(
            children: [
              Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      child: DComicImage(ImageEntity(ImageType.network, "https://images.dmzj.com/webpic/0/191212lmlyshzhyxsj.jpg"),fit: BoxFit.fill,),
                    ),
                  )),
              Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 3, 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex:3,child: Text("蕾米莉亚似乎在环游新世界")),
                          Expanded(flex:2,child: Text("Test1",style: Theme.of(context).textTheme.bodySmall,)),
                          Expanded(flex:2,child: Text("Test2",style: Theme.of(context).textTheme.bodySmall,)),
                          Expanded(flex:2,child: Text("Test3",style: Theme.of(context).textTheme.bodySmall,))
                        ],
                      ),
                    ),
                  ))
            ],
          ),
        ),
      ),
      color: Colors.transparent,
    );
  }

}