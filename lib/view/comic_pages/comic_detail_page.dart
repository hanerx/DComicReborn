import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/page_controllers/comic_detail_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:direct_select_flutter/direct_select_container.dart';
import 'package:direct_select_flutter/direct_select_item.dart';
import 'package:direct_select_flutter/direct_select_list.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ComicDetailPage extends StatefulWidget {
  final String title;
  final String comicId;
  final BaseComicSourceModel? comicSourceModel;

  const ComicDetailPage({super.key, required this.title, required this.comicId, this.comicSourceModel});
  @override
  State<StatefulWidget> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(create: (_)=>ComicDetailPageController(widget.comicSourceModel),builder: (context,child)=>DirectSelectContainer(
        child: Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: Icon(Icons.play_arrow),
          ),
          body: Container(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: ExtendedNestedScrollView(
                onlyOneScrollInBody: true,
                pinnedHeaderSliverHeightBuilder: () {
                  return MediaQuery.of(context).padding.top + kToolbarHeight;
                },
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return <Widget>[
                    SliverAppBar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      expandedHeight: 300,
                      pinned: true,
                      actions: [
                        IconButton(onPressed: () {}, icon: Icon(Icons.share))
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          'MEME娘',
                        ),
                        background: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              child: DComicImage(
                                ImageEntity(ImageType.network,
                                    "https://images.dmzj.com/webpic/5/memeniang622.jpg"),
                                fit: BoxFit.fitWidth,
                                customErrorMessageColor:
                                Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.transparent,
                                        Theme.of(context).colorScheme.primary,
                                      ])),
                            )
                          ],
                        ),
                        centerTitle: false,
                      ),
                    ),
                  ];
                },
                body: EasyRefresh(
                  header: ClassicHeader(
                      safeArea: false,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      textStyle:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                      messageStyle:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                      iconTheme: IconThemeData(
                          color: Theme.of(context).colorScheme.onPrimary)),
                  onRefresh: () async{
                    await Provider.of<ComicDetailPageController>(context,listen: false).refresh(context, widget.comicId, widget.title);
                  },
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Container(
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.primary,
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.only(left: 5, top: 5, right: 5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(3),
                                  topRight: Radius.circular(3))),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(
                                              left: 10, top: 5, bottom: 5),
                                          child: Text("MEME娘"),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(
                                              left: 10, top: 5, bottom: 5),
                                          child: Text(
                                            "2022-09-10 连载中",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                      onPressed: () {},
                                      icon: Icon(
                                        Icons.favorite_border,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .errorContainer,
                                      ))
                                ],
                              ),
                              Divider(
                                height: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        child: Card(
                          elevation: 0,
                          margin: EdgeInsets.only(left: 5, right: 5, bottom: 5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(3),
                                  bottomRight: Radius.circular(3))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(Icons.supervisor_account),
                                  ),
                                  Text("作者："),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                        onPressed: () {},
                                        label: Text(
                                          "Test",
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        visualDensity: VisualDensity(vertical: -4)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                        onPressed: () {},
                                        label: Text(
                                          "Test",
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        visualDensity: VisualDensity(vertical: -4)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                        onPressed: () {},
                                        label: Text(
                                          "Test",
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        visualDensity: VisualDensity(vertical: -4)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                        onPressed: () {},
                                        label: Text(
                                          "Test",
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        visualDensity: VisualDensity(vertical: -4)),
                                  )
                                ],
                              ),
                              Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Icon(Icons.apps),
                                  ),
                                  Text("分类："),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                      onPressed: () {},
                                      label: Text(
                                        "Test",
                                      ),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      visualDensity: VisualDensity(vertical: -4),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                        onPressed: () {},
                                        label: Text(
                                          "Test",
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        visualDensity: VisualDensity(vertical: -4)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                        onPressed: () {},
                                        label: Text(
                                          "Test",
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        visualDensity: VisualDensity(vertical: -4)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: ActionChip(
                                        onPressed: () {},
                                        label: Text(
                                          "Test",
                                        ),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        visualDensity: VisualDensity(vertical: -4)),
                                  )
                                ],
                              ),
                              Divider(
                                height: 1,
                              ),
                              Padding(
                                padding: EdgeInsets.all(5),
                                child: Text(
                                    "你和我的关系是？漫画 ，“老师...你没对我出手呢” 28岁，没有男友的悠香，兴致缺缺地参加了联谊会。但在联谊会上遇到的，居然是高中时期憧憬的数学老师....！成为酒友的2人增加了见面的机会，那一天，喝得烂醉后在酒店度过了一晚── “对我而言你还是学生啊” 明明经过10年我也已经长大了.....越来越喜欢的这种心情，老师对我的那份温柔只因为我是前学生？还是说──。 人气爆棚的令人心痒小鹿乱撞的爱情小说终于漫画化了！！欢迎在动漫之家漫画网观看你和我的关系是？漫画"),
                              )
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        child: Card(
                          margin: EdgeInsets.all(5),
                          elevation: 0,
                          child: Column(
                            children: [
                              SizedBox(height: 48,child: Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(left: 5),
                                    child: Text("当前ID："),
                                  ),
                                  Expanded(
                                    child: Center(child: Text("1234556"),),
                                  ),
                                  Text("绑定ID："),
                                  Expanded(
                                    child: Center(child: Text("1234556"),),
                                  ),
                                  IconButton(
                                    onPressed: () {},
                                    icon: Icon(Icons.refresh),
                                    splashRadius: 25,
                                    visualDensity:
                                    VisualDensity(horizontal: -4, vertical: -4),
                                  )
                                ],
                              ),),
                              Divider(
                                height: 1,
                              ),
                              _buildSourceController(context)
                            ],
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              )),
        )),);
  }

  Widget _buildSourceController(BuildContext context) {
    return Row(
      children: [
        Padding(padding: EdgeInsets.only(left: 5),child: Icon(Icons.apps),),
        Expanded(
          child: DirectSelectList<BaseComicSourceModel>(
              values:
                  Provider.of<ComicSourceProvider>(context).hasHomepageSources,
              defaultItemIndex: Provider.of<ComicSourceProvider>(context)
                  .activeHomeModelIndex,
              itemBuilder: (BaseComicSourceModel value) =>
                  DirectSelectItem<BaseComicSourceModel>(
                      itemHeight: 48,
                      value: value,
                      itemBuilder: (context, value) {
                        return Padding(
                          padding: EdgeInsets.only(left: 25),
                          child: Text(
                            value.type.sourceName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        );
                      }),
              onItemSelectedListener: (item, index, context) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(item.type.sourceName)));
                Provider.of<ComicSourceProvider>(context, listen: false)
                    .activeHomeModel = item;
              },
              focusedItemDecoration: BoxDecoration(
                border: BorderDirectional(
                  bottom: BorderSide(
                      width: 1, color: Theme.of(context).colorScheme.primary),
                  top: BorderSide(
                      width: 1, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ),
        Padding(padding: EdgeInsets.only(right: 5),child: Icon(Icons.unfold_more),)
      ],
    );
  }

  List<Widget> _buildChapters(BuildContext context){
    List<Widget> chapters=[];
    Container(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.all(5),
        elevation: 0,
        child: Column(
          children: [
            Padding(padding: EdgeInsets.only(top: 10),child: Center(child: Text("Title",style: TextStyle(color: Theme.of(context).primaryColor,fontWeight: FontWeight.bold),),),),
            Divider(),
            GridView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 3 / 1),
              children: [
                for (int i = 0; i < 20; i++)
                  Padding(
                    padding: EdgeInsets.all(3),
                    child: OutlinedButton(
                        onPressed: () {},
                        child: Text("Chapter $i")),
                  )
              ],
            )
          ],
        ),
      ),);
    return chapters;
  }
}
