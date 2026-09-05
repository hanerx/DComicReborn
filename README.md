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

访问协议参考 [LittleSurvival/copymanga-copy20 v1.4.84](https://github.com/LittleSurvival/copymanga-copy20/blob/7591be034286bb19bc8380c4ec3fd8622090f175/apk/tachiyomi-zh.copymanga-v1.4.84.apk)，包含独立吐槽线路、站点请求头和章节路径差异；不再依赖旧版 App 的动态域名发现与随机签名。

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
