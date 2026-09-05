# DComicReborn
![GitHub Release](https://img.shields.io/github/v/release/hanerx/DComicReborn?style=for-the-badge&link=https%3A%2F%2Fgithub.com%2Fhanerx%2FDComicReborn%2Freleases%2Flatest)
![GitHub Release Date](https://img.shields.io/github/release-date/hanerx/DComicReborn?style=for-the-badge)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/hanerx/DComicReborn/main.yml?style=for-the-badge)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/hanerx/DComicReborn/total?style=for-the-badge)


DComic Ver2.0

## 拷贝 / 热辣源

在「设置 → 漫画源设置 → 拷贝漫画」选择线路：

- **漫画与图片 API 线路**：支持拷贝和热辣，默认 `api.copy4000.com`。
- **拷贝评论与吐槽 API 线路**：独立选择拷贝线路。漫画 API 选择热辣（例如 `api.manga2025.com`）后，可使用热辣图片配合拷贝章节吐槽。
- 两站账号独立；切换站点后在账户设置中登录对应账号。切换立即作用于后续请求；已打开的漫画页面需重新进入。本地收藏和阅读记录仍使用原 `copymanga` 源标识，不迁移或删除。
- 混合吐槽依赖两站共享漫画 / 章节 UUID；热辣独有内容可能没有对应的拷贝吐槽。线路是否可访问取决于网络和源站状态。
- 首页下拉刷新会重新请求源站，不沿用尚未过期的本地缓存；请求失败时保留上一次完整内容，恢复网络后可再次下拉刷新。拷贝和热辣分别展示各自提供的首页栏目。
- 分类图片使用随包提供的精选日漫彩图与 Comiket 官方目录插画，不再随机选图或请求远程分类 Logo。新增、未匹配及“其他”分类显示本地拷贝应用 Logo；分类列表本身仍需从源站加载。
- 图片位于 `assets/copymanga/categories/`，统一裁切为 256 × 256 PNG；来源、作品名和原图裁切坐标记录在 [素材清单](assets/copymanga/credits.json)。替换素材时同步更新清单；增加分类需在 `CopyMangaComicHomepageModel._categoryArtwork` 中登记 API 的 `path_word`。第三方图片版权归原权利人所有，来源记录不代表转载授权。

访问协议参考 [LittleSurvival/copymanga-copy20 v1.4.84](https://github.com/LittleSurvival/copymanga-copy20/blob/7591be034286bb19bc8380c4ec3fd8622090f175/apk/tachiyomi-zh.copymanga-v1.4.84.apk)，包含独立吐槽线路、站点请求头和章节路径差异；不再依赖旧版 App 的动态域名发现与随机签名。

## 再漫画自动签到

- 在「设置 → 漫画源设置 → 再漫画」切换“自动签到”（再漫画卡片位于拷贝漫画卡片下方，可能需要下滑），默认开启，选择会保存并在下次启动时恢复。关闭后不再自动签到或领取 VIP 福利，重新开启时会立即检查并尝试完成当天任务。
- 开启时，密码登录、Token 登录，以及应用启动时恢复有效登录态后，自动检查并完成当天签到，无需每天重新输入账号密码。
- 签到状态以服务端当天的 `is_sign` 为准，不使用个人资料缓存；当天已签则跳过，避免跨日后被旧状态阻止签到。
- 会员身份以个人资料的 `isMember` 为准。VIP 会员会额外查询每日福利任务 `16`，仅在任务可领取时领取；已领取则跳过，不领取其他任务奖励。普通签到与 VIP 福利相互独立，一项失败不会阻止另一项。
- 源设置分别显示今日签到、会员身份和 VIP 每日福利状态，区分未登录、未完成、已完成及查询 / 领取失败。进入设置、设置页回到前台和点击刷新按钮时查询最新状态；状态查询本身不会触发签到或领取。
- 签到接口失败不会退出账号；后续登录或启动恢复时会再次检查。退出登录后不再触发签到。
- 不在应用关闭或停留后台时定时签到。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## ORM Database
- run `flutter packages pub run build_runner build`
- or run `flutter packages pub run build_runner watch`
