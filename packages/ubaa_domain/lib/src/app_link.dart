/// 关于页的公开目的地，不携带账号或学校业务参数。
/// ReUBAA 是 UBAA 的 fork，项目和反馈指向 fork，另留一个原版入口。
enum AppLink {
  project('开源项目（GitHub）', 'https://github.com/kahpoh19/ReUBAA'),
  feedback('反馈建议（Issues）', 'https://github.com/kahpoh19/ReUBAA/issues'),
  upstream('原版 UBAA（GitHub）', 'https://github.com/BUAASubnet/UBAA');

  const AppLink(this.label, this.url);
  final String label;
  final String url;
}
