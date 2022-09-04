import 'package:carousel_slider/carousel_slider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:dcomic/view/components/grid_card.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 2));
        },
        refreshOnStart: true,
        child:Container(
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: ListView(
            shrinkWrap: true,
            children: [
              CarouselSlider(
                options: CarouselOptions(
                  viewportFraction: 1,
                  enableInfiniteScroll: true,
                  autoPlay: true,
                  aspectRatio: 16 / 7,
                ),
                items: [
                  Card(
                    elevation: 0,
                    child: DComicImage(ImageEntity(ImageType.network,
                        "https://www.baidu.com/img/flexible/logo/pc/result.png")),
                  ),
                  Card(
                    elevation: 0,
                    child: DComicImage(ImageEntity(ImageType.network,
                        "https://www.baidu.com/img/flexible/logo/pc/result.png")),
                  ),
                  Card(
                    elevation: 0,
                    child: DComicImage(ImageEntity(ImageType.network,
                        "https://www.baidu.com/img/flexible/logo/pc/result.png")),
                  ),
                ],
              ),
              GridCard("Title1",
                onSideIconPressed: (){},
                children: [
                  GridCardItem(
                    image: ImageEntity(ImageType.network,"http://images.dmzj.com/webpic/1/xsdjs20220825.jpg",imageHeaders: {"referer":"http://dmzj.com"}),
                    onTap: (){},
                    title: "Title1",
                    subtitle: "SubTitle1",
                  ),GridCardItem(
                    image: ImageEntity(ImageType.unknown,""),
                    onTap: (){},
                    title: "Title1",
                    subtitle: "SubTitle1",
                  ),GridCardItem(
                    image: ImageEntity(ImageType.unknown,""),
                    onTap: (){},
                    title: "Title1",
                    subtitle: "SubTitle1",
                  ),
                ],),
              GridCard("Title2",crossAxisCount: 2,children: [
                GridCardItem(
                  image: ImageEntity(ImageType.network,"http://images.dmzj.com/webpic/1/xsdjs20220825.jpg",imageHeaders: {"referer":"http://dmzj.com"}),
                  onTap: (){},
                  title: "Title2",
                ),GridCardItem(
                  image: ImageEntity(ImageType.unknown,""),
                  onTap: (){},
                ),GridCardItem(
                  image: ImageEntity(ImageType.unknown,""),
                  onTap: (){},
                ),GridCardItem(
                  image: ImageEntity(ImageType.unknown,""),
                  onTap: (){},
                ),
              ],),
              GridCard("Title3"),
            ],
          ),
        ));
  }
}
