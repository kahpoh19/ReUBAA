import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' as em;
import 'package:ubaa_domain/ubaa_domain.dart';

import 'credentials.dart';
import 'html_text.dart';

/// 北航邮箱的 IMAP/SMTP 实现。
///
/// 收信复用一个 IMAP 连接，所有操作排队执行；连接被服务器断开时重连一次再试。
/// 发信每次新开 SMTP 连接，发完再把副本存进“已发送”。
final class ImapMailService implements MailService {
  ImapMailService({MailCredentialStore? store, this.clientVersion = '1.0.0'})
    : _store = store ?? SecureMailCredentialStore();
  final MailCredentialStore _store;
  final String clientVersion;

  static const _connectTimeout = Duration(seconds: 20);
  static const _responseTimeout = Duration(seconds: 40);

  em.ImapClient? _imap;
  MailCredential? _credential;
  List<MailFolder>? _folders;
  Future<void> _tail = Future.value();

  /// 同一时间只跑一个 IMAP 操作，避免命令交错。
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<MailAccount?> account() async {
    final saved = _credential ??= await _store.read();
    return saved == null ? null : MailAccount(address: saved.address);
  }

  @override
  Future<MailAccount> signIn(String address, String password) =>
      _serial(() async {
        final normalized = buaaMailAddress(address);
        final credential = MailCredential(
          address: normalized,
          password: password,
        );
        // 先用新账号连一次，成功了才保存，失败不影响之前的账号。
        final client = await _login(credential);
        await _drop();
        _imap = client;
        _credential = credential;
        _folders = null;
        await _store.write(credential);
        return MailAccount(address: normalized);
      });

  @override
  Future<void> signOut() => _serial(() async {
    await _drop();
    _credential = null;
    _folders = null;
    await _store.clear();
  });

  @override
  Future<List<MailFolder>> folders() => _serial(
    () => _withImap((imap) async {
      final boxes = await imap.listMailboxes(recursive: true);
      final folders = [
        for (final box in boxes)
          if (!box.isNotSelectable) _folder(box),
      ]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
      _folders = folders;
      return folders;
    }),
  );

  @override
  Future<MailPage> list(String folder, {int? before, int limit = 30}) =>
      _serial(
        () => _withImap((imap) async {
          final box = await imap.selectMailboxByPath(folder);
          final total = box.messagesExists;
          final end = before == null ? total : before - 1;
          if (end < 1) return MailPage(messages: const [], total: total);
          final start = end - limit + 1 < 1 ? 1 : end - limit + 1;
          final result = await imap.fetchMessages(
            em.MessageSequence.fromRange(start, end),
            '(UID FLAGS ENVELOPE BODYSTRUCTURE)',
          );
          final messages = [
            for (final message in result.messages.reversed)
              if (message.uid != null) _summary(message, folder),
          ];
          return MailPage(
            messages: messages,
            total: total,
            nextBefore: start > 1 ? start : null,
          );
        }),
      );

  @override
  Future<MailMessage> read(String folder, int uid) => _serial(
    () => _withImap((imap) async {
      await imap.selectMailboxByPath(folder);
      final result = await imap.uidFetchMessage(uid, 'BODY.PEEK[]');
      if (result.messages.isEmpty) {
        throw const MailException(MailFailure.rejected, '这封信已经不在了');
      }
      final message = result.messages.first;
      // 正文读到后再标已读，读取失败时保持未读。
      try {
        await imap.uidMarkSeen(em.MessageSequence.fromId(uid, isUid: true));
      } on em.ImapException {
        // 标已读失败不影响看信。
      }
      final html = message.decodeTextHtmlPart();
      final text =
          message.decodeTextPlainPart() ??
          (html == null ? '' : mailHtmlToText(html));
      return MailMessage(
        summary: _summary(message, folder, uid: uid, seen: true),
        cc: _contacts(message.cc),
        text: text.trim(),
        messageId: message.getHeaderValue('message-id'),
        attachments: [
          for (final info in message.findContentInfo())
            MailAttachment(
              name: info.fileName ?? '附件',
              size: info.size,
              type: info.mediaType?.text,
            ),
        ],
      );
    }),
  );

  @override
  Future<void> send(MailDraft draft) async {
    final credential = _credential ??= await _store.read();
    if (credential == null) {
      throw const MailException(MailFailure.notSignedIn);
    }
    final from = em.MailAddress(null, credential.address);
    final message = em.MessageBuilder.buildSimpleTextMessage(
      from,
      [for (final address in draft.to) em.MailAddress(null, address)],
      draft.text,
      cc: [for (final address in draft.cc) em.MailAddress(null, address)],
      subject: draft.subject,
    );
    // 回复时带上引用头，对方的邮件客户端能串成会话。
    final replyId = draft.replyTo?.messageId;
    if (replyId != null && replyId.isNotEmpty) {
      message
        ..setHeader('In-Reply-To', replyId)
        ..setHeader('References', replyId);
    }
    final smtp = em.SmtpClient('reubaa.local');
    try {
      await smtp.connectToServer(
        BuaaMailServer.smtpHost,
        BuaaMailServer.smtpPort,
        timeout: _connectTimeout,
      );
      await smtp.ehlo();
      try {
        await smtp.authenticate(
          credential.address,
          credential.password,
          em.AuthMechanism.login,
        );
      } on em.SmtpException {
        throw const MailException(MailFailure.authentication);
      }
      try {
        await smtp.sendMessage(message);
      } on em.SmtpException catch (error) {
        throw MailException(MailFailure.rejected, error.message);
      }
    } on MailException {
      rethrow;
    } on Object catch (error) {
      throw _mapError(error);
    } finally {
      unawaited(_quietly(smtp.quit));
    }
    // 发出去了才存副本；服务器自己存过就不再存，存副本失败不算发送失败。
    final messageId = message.getHeaderValue('message-id');
    try {
      await _serial(
        () => _withImap((imap) async {
          final sent = (_folders ?? const <MailFolder>[])
              .where((f) => f.kind == MailFolderKind.sent)
              .firstOrNull;
          if (sent == null) return;
          if (messageId != null) {
            await imap.selectMailboxByPath(sent.path);
            final found = await imap.uidSearchMessages(
              searchCriteria: 'HEADER Message-ID "$messageId"',
            );
            if (found.matchingSequence?.isNotEmpty ?? false) return;
          }
          await imap.appendMessage(
            message,
            targetMailboxPath: sent.path,
            flags: [em.MessageFlags.seen],
          );
        }),
      );
    } on Object {
      // 忽略。
    }
  }

  Future<em.ImapClient> _login(MailCredential credential) async {
    final client = em.ImapClient(defaultResponseTimeout: _responseTimeout);
    try {
      await client.connectToServer(
        BuaaMailServer.imapHost,
        BuaaMailServer.imapPort,
        timeout: _connectTimeout,
      );
    } on Object catch (error) {
      throw _mapError(error);
    }
    try {
      await client.login(credential.address, credential.password);
    } on em.ImapException {
      unawaited(_quietly(client.disconnect));
      throw const MailException(MailFailure.authentication);
    } on Object catch (error) {
      unawaited(_quietly(client.disconnect));
      throw _mapError(error);
    }
    // Coremail 要求客户端先报上 ID，否则可能拒绝后续命令；不支持也不影响。
    try {
      await client.id(
        clientId: em.Id(name: 'ReUBAA', version: clientVersion),
      );
    } on Object {
      // 忽略。
    }
    return client;
  }

  /// 拿到已登录的连接执行操作；连接断了重连一次再试。
  Future<T> _withImap<T>(Future<T> Function(em.ImapClient imap) action) async {
    final credential = _credential ??= await _store.read();
    if (credential == null) {
      throw const MailException(MailFailure.notSignedIn);
    }
    for (var attempt = 0; ; attempt++) {
      final imap = _imap ??= await _login(credential);
      try {
        return await action(imap);
      } on MailException {
        rethrow;
      } on Object catch (error) {
        await _drop();
        if (attempt > 0) throw _mapError(error);
      }
    }
  }

  Future<void> _drop() async {
    final imap = _imap;
    _imap = null;
    if (imap != null) await _quietly(imap.disconnect);
  }

  MailFolder _folder(em.Mailbox box) {
    final kind = box.isInbox
        ? MailFolderKind.inbox
        : box.isSent
        ? MailFolderKind.sent
        : box.isDrafts
        ? MailFolderKind.drafts
        : box.isJunk
        ? MailFolderKind.junk
        : box.isTrash
        ? MailFolderKind.trash
        : _guessKind(box);
    return MailFolder(path: box.path, name: box.name, kind: kind);
  }

  /// 服务器没标特殊用途时按名字猜，Coremail 常用中文名。
  static MailFolderKind _guessKind(em.Mailbox box) {
    final name = box.name.toLowerCase();
    if (name == 'inbox') return MailFolderKind.inbox;
    if (name.contains('sent') || box.name.contains('已发送')) {
      return MailFolderKind.sent;
    }
    if (name.contains('draft') || box.name.contains('草稿')) {
      return MailFolderKind.drafts;
    }
    if (name.contains('junk') ||
        name.contains('spam') ||
        box.name.contains('垃圾')) {
      return MailFolderKind.junk;
    }
    if (name.contains('trash') ||
        name.contains('deleted') ||
        box.name.contains('已删除')) {
      return MailFolderKind.trash;
    }
    return MailFolderKind.other;
  }

  MailSummary _summary(
    em.MimeMessage message,
    String folder, {
    int? uid,
    bool? seen,
  }) {
    final envelope = message.envelope;
    final from = envelope?.from ?? message.from;
    final subject = envelope?.subject ?? message.decodeSubject();
    return MailSummary(
      uid: uid ?? message.uid!,
      folder: folder,
      subject: subject == null || subject.trim().isEmpty
          ? '（无主题）'
          : subject.trim(),
      from: from == null || from.isEmpty ? null : _contact(from.first),
      to: _contacts(envelope?.to ?? message.to),
      date: envelope?.date ?? message.decodeDate(),
      seen: seen ?? message.isSeen,
      hasAttachments: message.hasAttachments(),
    );
  }

  static MailContact _contact(em.MailAddress address) =>
      MailContact(address: address.email, name: address.personalName);

  static List<MailContact> _contacts(List<em.MailAddress>? addresses) => [
    for (final address in addresses ?? const <em.MailAddress>[])
      _contact(address),
  ];

  static MailException _mapError(Object error) => switch (error) {
    MailException() => error,
    SocketException() ||
    TimeoutException() ||
    HandshakeException() => const MailException(MailFailure.network),
    em.ImapException() => MailException(MailFailure.rejected, error.message),
    em.SmtpException() => MailException(MailFailure.rejected, error.message),
    _ => const MailException(MailFailure.network),
  };

  static Future<void> _quietly(Future<Object?> Function() action) async {
    try {
      await action();
    } on Object {
      // 关连接时出错没关系。
    }
  }
}
