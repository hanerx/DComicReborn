import 'package:carousel_slider/carousel_slider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CarouselSlider(
                options: CarouselOptions(
                  viewportFraction: 1,
                  enableInfiniteScroll: true,
                  autoPlay: true,
                  aspectRatio: 16 / 7,
                ),
                items: [
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: DComicImage(ImageEntity(ImageType.network,
                        "https://www.baidu.com/img/flexible/logo/pc/result.png")),
                  ),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: DComicImage(ImageEntity(ImageType.network,
                        "https://www.baidu.com/img/flexible/logo/pc/result.png")),
                  ),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: DComicImage(ImageEntity(ImageType.network,
                        "https://www.baidu.com/img/flexible/logo/pc/result.png")),
                  ),
                ],
              ),
            )
          ],
        ));
  }
}
