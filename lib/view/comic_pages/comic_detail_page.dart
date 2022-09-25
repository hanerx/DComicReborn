import 'package:date_format/date_format.dart' as formatDate;
import 'package:dcomic/generated/l10n.dart';
import 'package:dcomic/providers/models/comic_source_model.dart';
import 'package:dcomic/providers/navigator_provider.dart';
import 'package:dcomic/providers/page_controllers/comic_detail_page_controller.dart';
import 'package:dcomic/providers/source_provider.dart';
import 'package:dcomic/utils/custom_theme.dart';
import 'package:dcomic/view/comic_viewer/comic_viewer_page.dart';
import 'package:dcomic/view/components/comment_card.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:direct_select_flutter/direct_select_container.dart';
import 'package:direct_select_flutter/direct_select_item.dart';
import 'package:direct_select_flutter/direct_select_list.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:fluttericon/font_awesome5_icons.dart';
import 'package:provider/provider.dart';

class ComicDetailPage extends StatefulWidget {
  final String title;
  final String comicId;
  final BaseComicSourceModel? comicSourceModel;

  const ComicDetailPage(
      {super.key,
      required this.title,
      required this.comicId,
      this.comicSourceModel});

  @override
  State<StatefulWidget> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        var controller = ComicDetailPageController(widget.comicSourceModel);
        // 用来保证能跑的胶水代码，easyrefresh和nestedscrollview不知道为啥会有冲突
        Future.delayed(const Duration()).then((value) =>
            controller.refresh(context, widget.comicId, widget.title));
        return controller;
      },
      builder: (context, child) => DirectSelectContainer(
          child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.play_arrow),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).colorScheme.primary,
          shape: const CircularNotchedRectangle(),
          child: IconTheme(
              data: Theme.of(context)
                  .iconTheme
                  .copyWith(color: CustomTheme.of(context).foregroundColor),
              child: Row(
                children: [
                  IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.file_download_outlined)),
                  Builder(
                      builder: (context) => IconButton(
                          onPressed: () {
                            Scaffold.of(context).openEndDrawer();
                          },
                          icon: Icon(Icons.message_outlined))),
                  IconButton(onPressed: () {}, icon: Icon(Icons.share)),
                  Spacer()
                ],
              )),
        ),
        endDrawer: _buildEndDrawer(context),
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
                    actions: const [Spacer()],
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        Provider.of<ComicDetailPageController>(context).title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      background: Stack(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: DComicImage(
                              Provider.of<ComicDetailPageController>(context)
                                  .cover,
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
                    textStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary),
                    messageStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary),
                    iconTheme: IconThemeData(
                        color: Theme.of(context).colorScheme.onPrimary)),
                onRefresh: () async {
                  await Provider.of<ComicDetailPageController>(context,
                          listen: false)
                      .refresh(context, widget.comicId, widget.title);
                },
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                        Container(
                          width: double.infinity,
                          color: Theme.of(context).colorScheme.primary,
                          child: Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(
                                left: 5, top: 5, right: 5),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(3),
                                    topRight: Radius.circular(3))),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 10, top: 5, bottom: 5),
                                            child: Text(Provider.of<
                                                        ComicDetailPageController>(
                                                    context)
                                                .title),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 10, top: 5, bottom: 5),
                                            child: Text(
                                              "${Provider.of<ComicDetailPageController>(context).lastUpdate} ${Provider.of<ComicDetailPageController>(context).status}",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                        onPressed: () {
                                          Provider.of<ComicDetailPageController>(
                                                  context,
                                                  listen: false)
                                              .subscribe = !Provider.of<
                                                      ComicDetailPageController>(
                                                  context,
                                                  listen: false)
                                              .subscribe;
                                        },
                                        icon: Icon(
                                          Provider.of<ComicDetailPageController>(
                                                      context)
                                                  .subscribe
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ))
                                  ],
                                ),
                                const Divider(
                                  height: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(
                                left: 5, right: 5, bottom: 5),
                            shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(3),
                                    bottomRight: Radius.circular(3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: _buildAuthorList(context),
                                ),
                                Row(
                                  children: _buildCategoryList(context),
                                ),
                                const Divider(
                                  height: 1,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Text(
                                      Provider.of<ComicDetailPageController>(
                                              context)
                                          .description),
                                )
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            margin: const EdgeInsets.all(5),
                            elevation: 0,
                            child: Column(
                              children: [
                                _buildBindingInfo(context),
                                const Divider(
                                  height: 1,
                                ),
                                _buildSourceController(context)
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            margin: const EdgeInsets.all(5),
                            elevation: 0,
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Provider.of<ComicDetailPageController>(
                                                context,
                                                listen: false)
                                            .nest =
                                        !Provider.of<ComicDetailPageController>(
                                                context,
                                                listen: false)
                                            .nest;
                                  },
                                  icon: Icon(
                                      Provider.of<ComicDetailPageController>(
                                                  context)
                                              .nest
                                          ? Icons.apps
                                          : Icons.list_alt),
                                  label: Text(Provider.of<
                                                  ComicDetailPageController>(
                                              context)
                                          .nest
                                      ? S.of(context).ComicDetailPageGridMode
                                      : S.of(context).ComicDetailPageListMode),
                                  style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStateProperty.all(
                                              Theme.of(context)
                                                  .colorScheme
                                                  .secondary)),
                                ),
                                const Expanded(child: SizedBox()),
                                TextButton.icon(
                                  onPressed: () {
                                    Provider.of<ComicDetailPageController>(
                                                context,
                                                listen: false)
                                            .reverse =
                                        !Provider.of<ComicDetailPageController>(
                                                context,
                                                listen: false)
                                            .reverse;
                                  },
                                  icon: Icon(
                                      Provider.of<ComicDetailPageController>(
                                                  context)
                                              .reverse
                                          ? FontAwesome5.sort_amount_down
                                          : FontAwesome5.sort_amount_down_alt),
                                  label: Text(
                                      Provider.of<ComicDetailPageController>(
                                                  context)
                                              .reverse
                                          ? S
                                              .of(context)
                                              .ComicDetailPageReverseMode
                                          : S
                                              .of(context)
                                              .ComicDetailPagePositiveMode),
                                  style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStateProperty.all(
                                              Theme.of(context)
                                                  .colorScheme
                                                  .secondary)),
                                )
                              ],
                            ),
                          ),
                        ),
                      ] +
                      _buildChapters(context),
                ),
              ),
            )),
      )),
    );
  }

  Widget _buildBindingInfo(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(S.of(context).ComicDetailPageOriginalComicId),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(widget.comicId),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(S.of(context).ComicDetailPageBindComicId),
            ),
          ),
          Expanded(
            child: Center(
              child:
                  Text(Provider.of<ComicDetailPageController>(context).comicId),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.secondary,
            ),
            splashRadius: 25,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          )
        ],
      ),
    );
  }

  Widget _buildSourceController(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Icon(
            Icons.apps,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        Expanded(
          child: DirectSelectList<BaseComicSourceModel>(
            values: Provider.of<ComicSourceProvider>(context).sources,
            defaultItemIndex:
                Provider.of<ComicSourceProvider>(context).activeModelIndex,
            itemBuilder: (BaseComicSourceModel value) =>
                DirectSelectItem<BaseComicSourceModel>(
                    itemHeight: 48,
                    value: value,
                    itemBuilder: (context, value) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 25),
                        child: Text(
                          value.type.sourceName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      );
                    }),
            onItemSelectedListener: (item, index, context) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(item.type.sourceName)));
              Provider.of<ComicSourceProvider>(context, listen: false)
                  .activeModel = item;
              Provider.of<ComicDetailPageController>(context, listen: false)
                  .comicSourceModel = item;
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
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Icon(
            Icons.unfold_more,
            color: Theme.of(context).colorScheme.secondary,
          ),
        )
      ],
    );
  }

  List<Widget> _buildChapters(BuildContext context) {
    List<Widget> chapters = [];
    for (var tuple
        in Provider.of<ComicDetailPageController>(context).chapters.entries) {
      chapters.add(SizedBox(
        width: double.infinity,
        child: Card(
          margin: const EdgeInsets.all(5),
          elevation: 0,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text(
                    tuple.key,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const Divider(),
              _buildChapterList(
                  context,
                  Provider.of<ComicDetailPageController>(context).reverse
                      ? tuple.value
                      : tuple.value.reversed.toList())
            ],
          ),
        ),
      ));
    }

    return chapters;
  }

  Widget _buildChapterList(
      BuildContext context, List<BaseComicChapterEntityModel> data) {
    if (Provider.of<ComicDetailPageController>(context).nest) {
      return GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 3 / 1),
        itemCount: data.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.all(3),
          child: OutlinedButton(
              onPressed: () {
                var detailModel = Provider.of<ComicDetailPageController>(
                        context,
                        listen: false)
                    .detailModel!;
                var chapters = Provider.of<ComicDetailPageController>(context,
                            listen: false)
                        .reverse
                    ? data.reversed.toList()
                    : data;
                Provider.of<NavigatorProvider>(context, listen: false)
                    .getNavigator(context, NavigatorType.defaultNavigator)
                    ?.push(MaterialPageRoute(
                        builder: (context) => ComicViewerPage(
                            detailModel: detailModel,
                            chapters: chapters,
                            chapterId: data[index].chapterId),
                        settings:
                            const RouteSettings(name: 'ComicViewerPage')));
              },
              child: Text(
                data[index].title,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.secondary),
                overflow: TextOverflow.ellipsis,
              )),
        ),
      );
    } else {
      return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(data[index].title),
          subtitle: Text(S.of(context).ComicDetailPageChapterEntitySubtitle(
              formatDate.formatDate(data[index].uploadTime,
                  [formatDate.yyyy, '-', formatDate.mm, '-', formatDate.dd]),
              data[index].chapterId)),
          onTap: () {
            var detailModel =
                Provider.of<ComicDetailPageController>(context, listen: false)
                    .detailModel!;
            var chapters =
                Provider.of<ComicDetailPageController>(context, listen: false)
                        .reverse
                    ? data.reversed.toList()
                    : data;
            Provider.of<NavigatorProvider>(context, listen: false)
                .getNavigator(context, NavigatorType.defaultNavigator)
                ?.push(MaterialPageRoute(
                    builder: (context) => ComicViewerPage(
                        detailModel: detailModel,
                        chapters: chapters,
                        chapterId: data[index].chapterId),
                    settings: const RouteSettings(name: 'ComicViewerPage')));
          },
        ),
      );
    }
  }

  List<Widget> _buildCategoryList(BuildContext context) {
    List<Widget> data = [
      Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Icon(
          Icons.apps,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      Text(S.of(context).ComicDetailPageCategory),
    ];

    for (var item
        in Provider.of<ComicDetailPageController>(context).categories) {
      data.add(Padding(
        padding: const EdgeInsets.only(left: 5),
        child: ActionChip(
            onPressed: () {},
            label: Text(
              item.title,
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            visualDensity: const VisualDensity(vertical: -4)),
      ));
    }
    return data;
  }

  List<Widget> _buildAuthorList(BuildContext context) {
    List<Widget> data = [
      Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Icon(
          Icons.supervisor_account,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      Text(S.of(context).ComicDetailPageAuthor),
    ];

    for (var item in Provider.of<ComicDetailPageController>(context).authors) {
      data.add(Padding(
        padding: const EdgeInsets.only(left: 5),
        child: ActionChip(
            onPressed: () {},
            label: Text(
              item.title,
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            visualDensity: const VisualDensity(vertical: -4)),
      ));
    }
    return data;
  }

  Widget _buildEndDrawer(BuildContext context){
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.9,
      backgroundColor: Colors.transparent,
      child: Card(
        child: SizedBox.expand(
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3)),
                child: Container(
                  height: MediaQuery.of(context).padding.top - 4,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              Container(
                color: Theme.of(context).primaryColor,
                child: IconTheme(
                  data: Theme.of(context).iconTheme.copyWith(
                      color: CustomTheme.of(context).foregroundColor),
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodyText2!.copyWith(
                        color: CustomTheme.of(context).foregroundColor),
                    child: Row(
                      children: [
                        const BackButton(),
                        Expanded(child: Text(S.of(context).ComicDetailPageComments))
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                  child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(3),
                          bottomRight: Radius.circular(3)),
                      child: EasyRefresh(
                        header: const ClassicHeader(safeArea: false),
                        refreshOnStart: true,
                        onRefresh: () async{
                          await Provider.of<ComicDetailPageController>(context,listen: false).refreshComment();
                        },
                        onLoad: ()async{
                          await Provider.of<ComicDetailPageController>(context,listen: false).loadComment();
                        },
                        child: Container(
                          color:
                          Theme.of(context).colorScheme.surfaceVariant,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                              itemCount:
                              Provider.of<ComicDetailPageController>(
                                  context)
                                  .comments
                                  .length,
                              itemBuilder: (context, index) {
                                var item =
                                Provider.of<ComicDetailPageController>(
                                    context)
                                    .comments[index];
                                return CommentCard(
                                    avatar: item.avatar,
                                    nickname: item.nickname,
                                    comment: item.comment);
                              }),
                        ),
                      )))
            ],
          ),
        ),
      ),
    );
  }
}
