<div align="center">

<img src="packages/ubaa_ui/assets/icons/app_icon.png" width="112" alt="ReUBAA 图标">

# ReUBAA

**Make UBAA Great Again!**

基于 [UBAA](https://github.com/BUAASubnet/UBAA) 的个人修改版，在原版课表、作业、成绩、选课、预约、日程和云盘的基础上，加了几项自己常用的功能。

[![许可证](https://img.shields.io/badge/%E8%AE%B8%E5%8F%AF%E8%AF%81-MIT-2fb67c)](LICENSE)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20HarmonyOS%20%7C%20Desktop-2fb67c.svg?style=flat)

[原版项目](https://github.com/BUAASubnet/UBAA) · [原版使用指南](https://www.ubaa.top) · [问题反馈](https://github.com/kahpoh19/ReUBAA/issues)

</div>

---

## 为什么选择 UBAA

- 📚 **一个入口**：不用在十几个学校系统之间来回切换，查课表、交作业前看截止、抢博雅、约座位都在同一个应用里。
- 📱 **全平台**：手机、平板、电脑都能用，覆盖 Android、iOS、HarmonyOS、Windows、macOS 和 Linux。
- 🌐 **校内校外都能连**：自动在直连和学校 WebVPN 之间选择，网络变化后自动恢复。
- 📴 **离线也能看**：打开就先显示上次的内容，没网时照样能看课表和成绩。
- 🔒 **校园数据由设备直接处理**：校园请求不经过 UBAA 服务器中转；勾选“记住密码”后，密码保存在系统安全存储里。

## 功能一览

| | 功能 | 你可以做什么 |
|---|---|---|
| 🗓️ | **日程与待办** | 课表、作业截止和自己的安排合在一条时间线里；支持重复规则、教学周、完成标记，可导出到系统日历 |
| 📖 | **学习** | 课表、考试、成绩、空教室、SPOC 和希冀作业、每日课程、教学评教 |
| 🎓 | **博雅课程** | 浏览、筛选、选课与退选 |
| 🏛️ | **校园服务** | 图书馆座位、研讨室预约、阳光打卡、iHome 诉求、财务收入查询 |
| ☁️ | **北航云盘** | 浏览和管理文件，上传、下载、分享，回收站；也可用来在多台设备间同步日程 |
| ⌨️ | **桌面命令模式** | 在终端里查课表、看成绩、管理日程，和桌面应用共用同一个账号 |

每项功能的详细用法见[用户文档](docs/README.md#用户)中的功能总览。

## ReUBAA 新增功能

- 📧 **邮箱**：首页「邮箱」入口，通过 IMAP/SMTP 收发 @buaa.edu.cn 邮件，支持切换文件夹、看信、写信和回复。登录用网页版邮箱「个人设置 → 安全设置 → 客户端专用密码」里生成的密码，不是统一认证密码；密码只存在本机的系统安全存储里，退出邮箱时删除。附件暂时只显示名字和大小，下载请到网页版。
- 🔔 **课程与待办通知**：设置页“通知”分组里分别开关，默认关闭。课程提醒默认课前 10、30 分钟，待办提醒默认截止前 4 小时、1 天，都可以勾选其他档位或自定义。
- 🎨 **Miuix 界面风格**：设置里「界面风格」可以在原来的 Material 和仿 HyperOS 的 Miuix 之间切换：浅灰页面、白色无边框卡片，深色模式为纯黑背景。

ReUBAA 包名为 `cn.edu.reubaa`，可以和原版 UBAA 同时安装。新功能有问题欢迎在[本仓库](https://github.com/kahpoh19/ReUBAA/issues)反馈。其余内容沿用原版说明。

## 快速开始

1. 在 [Releases](https://github.com/BUAASubnet/UBAA/releases) 下载对应平台的安装包。请认准 **v2.x** 版本。
2. 打开应用，用北航统一认证账号登录。连接方式选“自动”即可。
3. 登录后进入首页，所有功能都在底部导航（手机）或侧栏（电脑）里。

> [!TIP]
> 从旧版 v1.x 升级前，请到[用户文档](docs/README.md#用户)查看新版变化。旧版的登录状态和设置不会自动迁移，需要重新登录。

桌面版附带 `ubaa-cli` 命令，和图形界面共用账号与数据：

```bash
ubaa-cli auth login --username 你的学号
ubaa-cli schedule today
ubaa-cli --json grades list --term 2025-2026-1
```

桌面命令模式的完整用法见[用户文档](docs/README.md#用户)中的功能总览。

## 隐私与安全

- 校园请求由设备直接发往学校系统或学校 WebVPN。校园业务缓存保存在本机并加密，不上传到 UBAA 服务器；主动使用北航云盘同步日程时，日程保存到自己的北航云盘。
- 勾选“记住密码”后，密码保存在设备的系统安全存储（如钥匙串）中。
- 产品改进统计在同意隐私政策后开启，可在设置中关闭，也可按隐私政策联系维护者申请删除已上传的数据。统计不上传学校账号原文、密码、课程、成绩或诊断报告。更新检查和公告只发送版本、平台、分发渠道等必要信息。

完整说明见[用户文档](docs/README.md#用户)中的隐私政策。发现安全问题请按[安全策略](SECURITY.md)私下报告。

## 技术栈

| 层 | 技术 |
|---|---|
| 校园协议与业务核心 | Rust：认证、直连/WebVPN、解析、加密缓存 |
| 跨语言桥接 | [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) |
| 界面 | Flutter + Dart，HarmonyOS 使用 OpenHarmony Flutter |
| 本地存储 | SQLite、系统安全存储 |
| 应用服务（更新、公告与匿名统计） | Node.js（TypeScript）、PostgreSQL |
| 文档站 | [VitePress](https://vitepress.dev) |

## 参与开发

欢迎提交 Issue 和 Pull Request。日常开发在 `dev` 分支进行，`main` 是发布分支，旧版代码保存在 [`ubaa1`](https://github.com/BUAASubnet/UBAA/tree/ubaa1) 分支。

- 开发环境、架构和提交指南见[贡献者文档](docs/README.md#贡献者)。
- [行为准则](CODE_OF_CONDUCT.md)：社区行为与私下报告方式
- 协议依据、合同和运行手册见[维护者文档](docs/README.md#维护者)。

## Star History

<a href="https://star-history.com/#BUAASubnet/UBAA&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=BUAASubnet/UBAA&type=Date&theme=dark">
    <img alt="Star History" src="https://api.star-history.com/svg?repos=BUAASubnet/UBAA&type=Date" width="600">
  </picture>
</a>

## 贡献者

<a href="https://github.com/BUAASubnet/UBAA/graphs/contributors">
  <img alt="贡献者" src="https://contrib.rocks/image?repo=BUAASubnet/UBAA">
</a>

## 致谢

UBAA 参考或使用了以下开源项目，感谢它们的作者：

- [fontlos/buaa-api](https://github.com/fontlos/buaa-api)：北航接口协议参考
- [CoolwindHF/Auto-BUAA-icw](https://github.com/CoolwindHF/Auto-BUAA-icw)：财务查询协议参考
- [sml2h3/ddddocr](https://github.com/sml2h3/ddddocr)：验证码识别模型

完整列表见[第三方声明](THIRD_PARTY_NOTICES.md)。

## 免责声明与许可

UBAA 由学生开发者制作和维护，是非官方第三方工具，与北京航空航天大学官方无利益关系。课程、成绩和预约结果以学校系统为准。

本项目基于 [MIT 许可证](LICENSE) 开源。
