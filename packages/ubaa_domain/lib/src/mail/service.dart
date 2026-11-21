/// 北航邮箱的展示模型和服务接口。
///
/// 实现走 IMAP/SMTP，登录用 Coremail 网页版里生成的客户端专用密码，不碰统一认证。
library;

/// 北航邮箱的服务器，网页版“设置 → 客户端设置”里也是这几个。
abstract final class BuaaMailServer {
  static const imapHost = 'imap.buaa.edu.cn';
  static const imapPort = 993;
  static const smtpHost = 'smtp.buaa.edu.cn';
  static const smtpPort = 465;
}

/// 只填学号或用户名时补上 @buaa.edu.cn。
String buaaMailAddress(String input) {
  final value = input.trim();
  return value.contains('@') ? value : '$value@buaa.edu.cn';
}

/// 已保存的邮箱账号，不含密码。
final class MailAccount {
  const MailAccount({required this.address});
  final String address;
}

enum MailFolderKind { inbox, sent, drafts, junk, trash, other }

final class MailFolder {
  const MailFolder({
    required this.path,
    required this.name,
    required this.kind,
  });

  /// 服务器上的文件夹路径，操作时原样传回。
  final String path;
  final String name;
  final MailFolderKind kind;

  /// 常用文件夹显示中文名，其余用服务器给的名字。
  String get label => switch (kind) {
    MailFolderKind.inbox => '收件箱',
    MailFolderKind.sent => '已发送',
    MailFolderKind.drafts => '草稿箱',
    MailFolderKind.junk => '垃圾邮件',
    MailFolderKind.trash => '已删除',
    MailFolderKind.other => name,
  };
}

final class MailContact {
  const MailContact({required this.address, this.name});
  final String address;
  final String? name;

  /// 有名字显示名字，没有就显示地址。
  String get label => name?.trim().isNotEmpty == true ? name!.trim() : address;
}

/// 列表里的一封信，只有信封信息。
final class MailSummary {
  const MailSummary({
    required this.uid,
    required this.folder,
    required this.subject,
    this.from,
    this.to = const [],
    this.date,
    this.seen = true,
    this.hasAttachments = false,
  });
  final int uid;
  final String folder;
  final String subject;
  final MailContact? from;
  final List<MailContact> to;
  final DateTime? date;
  final bool seen, hasAttachments;
}

/// 一页信件。[nextBefore] 不为空时还能往前翻，传给下一次 list。
final class MailPage {
  const MailPage({required this.messages, this.nextBefore, this.total = 0});
  final List<MailSummary> messages;
  final int? nextBefore;
  final int total;
}

final class MailAttachment {
  const MailAttachment({required this.name, this.size, this.type});
  final String name;
  final int? size;
  final String? type;
}

/// 打开后的整封信。正文优先纯文本，只有 HTML 时转成文本。
final class MailMessage {
  const MailMessage({
    required this.summary,
    required this.cc,
    required this.text,
    this.messageId,
    this.attachments = const [],
  });
  final MailSummary summary;
  final List<MailContact> cc;
  final String text;
  final String? messageId;
  final List<MailAttachment> attachments;
}

/// 要发出去的信。[replyTo] 不为空时按回复处理（带上引用头）。
final class MailDraft {
  const MailDraft({
    required this.to,
    required this.subject,
    required this.text,
    this.cc = const [],
    this.replyTo,
  });
  final List<String> to, cc;
  final String subject, text;
  final MailMessage? replyTo;
}

enum MailFailure {
  /// 地址或客户端专用密码不对，或者没开 IMAP/SMTP。
  authentication,

  /// 连不上服务器或超时。
  network,

  /// 服务器拒绝了操作（比如收件人地址不对）。
  rejected,

  /// 还没登录邮箱。
  notSignedIn,
}

final class MailException implements Exception {
  const MailException(this.failure, [this.detail]);
  final MailFailure failure;

  /// 服务器返回的原话，只用于提示，不含密码。
  final String? detail;

  String get message => switch (failure) {
    MailFailure.authentication => '登录失败：请检查邮箱地址和客户端专用密码，并确认已开启 IMAP/SMTP',
    MailFailure.network => '连不上邮箱服务器，请检查网络后重试',
    MailFailure.rejected => '邮箱服务器拒绝了这次操作${detail == null ? '' : '：$detail'}',
    MailFailure.notSignedIn => '还没有登录邮箱',
  };

  @override
  String toString() => 'MailException($failure)';
}

abstract interface class MailService {
  /// 已保存的账号；没登录过为 null。
  Future<MailAccount?> account();

  /// 用地址和客户端专用密码试登录，成功后保存到系统安全存储。
  Future<MailAccount> signIn(String address, String password);

  /// 退出并删除保存的密码。
  Future<void> signOut();

  Future<List<MailFolder>> folders();

  /// 按时间倒序取一页；[before] 用上一页的 [MailPage.nextBefore]。
  Future<MailPage> list(String folder, {int? before, int limit = 30});

  /// 读一封信并标为已读。
  Future<MailMessage> read(String folder, int uid);

  Future<void> send(MailDraft draft);
}
