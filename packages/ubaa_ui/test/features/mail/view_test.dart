import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_ui/src/features/mail/format.dart';
import 'package:ubaa_ui/src/features/mail/view.dart';

const _me = MailContact(address: 'me@buaa.edu.cn', name: '我');
const _teacher = MailContact(address: 'teacher@buaa.edu.cn', name: '王老师');

MailSummary _mail(
  int uid,
  String subject, {
  String folder = 'INBOX',
  bool seen = true,
  MailContact from = _teacher,
  List<MailContact> to = const [_me],
}) => MailSummary(
  uid: uid,
  folder: folder,
  subject: subject,
  from: from,
  to: to,
  date: DateTime.utc(2026, 11, 20, 2),
  seen: seen,
);

/// 内存里的假邮箱，记下登录和发出的信。
class _FakeMail implements MailService {
  _FakeMail({this.saved});
  MailAccount? saved;
  final signIns = <String>[];
  final sent = <MailDraft>[];
  final boxes = {
    'INBOX': [_mail(2, '期末考试安排', seen: false), _mail(1, '课程作业说明')],
    'Sent': [
      _mail(
        3,
        '作业提交',
        folder: 'Sent',
        from: _me,
        to: const [MailContact(address: 'ta@buaa.edu.cn', name: '助教')],
      ),
    ],
  };

  @override
  Future<MailAccount?> account() async => saved;

  @override
  Future<MailAccount> signIn(String address, String password) async {
    signIns.add(address);
    if (password != 'app-password') {
      throw const MailException(MailFailure.authentication);
    }
    return saved = MailAccount(address: buaaMailAddress(address));
  }

  @override
  Future<void> signOut() async => saved = null;

  @override
  Future<List<MailFolder>> folders() async => const [
    MailFolder(path: 'INBOX', name: 'INBOX', kind: MailFolderKind.inbox),
    MailFolder(path: 'Sent', name: '已发送', kind: MailFolderKind.sent),
  ];

  @override
  Future<MailPage> list(String folder, {int? before, int limit = 30}) async =>
      MailPage(messages: boxes[folder] ?? const [], total: 0);

  @override
  Future<MailMessage> read(String folder, int uid) async => MailMessage(
    summary: boxes[folder]!.firstWhere((m) => m.uid == uid),
    cc: const [],
    text: '第 $uid 封信的正文\n请按时完成',
    messageId: '<$uid@buaa.edu.cn>',
  );

  @override
  Future<void> send(MailDraft draft) async => sent.add(draft);
}

Future<void> _pump(WidgetTester tester, MailService service) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: MailView(service: service)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('没登录时显示说明，密码错误提示原因，登录后显示收件箱', (tester) async {
    final service = _FakeMail();
    await _pump(tester, service);
    expect(find.text('登录 @buaa.edu.cn 邮箱'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '邮箱地址'), 'me');
    await tester.enterText(find.widgetWithText(TextField, '客户端专用密码'), 'wrong');
    await tester.tap(find.text('登录邮箱'));
    await tester.pumpAndSettle();
    expect(find.textContaining('客户端专用密码，并确认已开启'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '客户端专用密码'),
      'app-password',
    );
    await tester.tap(find.text('登录邮箱'));
    await tester.pumpAndSettle();
    expect(service.signIns, ['me', 'me']);
    expect(find.text('me@buaa.edu.cn'), findsOneWidget);
    expect(find.text('期末考试安排'), findsOneWidget);
    expect(find.text('课程作业说明'), findsOneWidget);
  });

  testWidgets('打开邮件看正文，回复时带上收件人、主题和引用', (tester) async {
    final service = _FakeMail(
      saved: const MailAccount(address: 'me@buaa.edu.cn'),
    );
    await _pump(tester, service);
    await tester.tap(find.text('期末考试安排'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 2 封信的正文'), findsOneWidget);
    expect(find.text('王老师 <teacher@buaa.edu.cn>'), findsOneWidget);

    await tester.tap(find.byTooltip('回复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    final draft = service.sent.single;
    expect(draft.to, ['teacher@buaa.edu.cn']);
    expect(draft.subject, 'Re: 期末考试安排');
    expect(draft.text, contains('> 请按时完成'));
    expect(draft.replyTo?.messageId, '<2@buaa.edu.cn>');
    expect(find.text('邮件已发送'), findsOneWidget);
  });

  testWidgets('写信要求填收件人，已发送里显示发给谁', (tester) async {
    final service = _FakeMail(
      saved: const MailAccount(address: 'me@buaa.edu.cn'),
    );
    await _pump(tester, service);
    await tester.tap(find.text('写信'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(find.text('请填写收件人'), findsOneWidget);
    expect(service.sent, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '已发送'));
    await tester.pumpAndSettle();
    expect(find.text('发给 助教'), findsOneWidget);
    expect(find.text('期末考试安排'), findsNothing);
  });

  test('收件人拆分、补全域名，回复主题不重复加前缀', () {
    expect(mailAddresses('a, b@qq.com；c\nd'), [
      'a@buaa.edu.cn',
      'b@qq.com',
      'c@buaa.edu.cn',
      'd@buaa.edu.cn',
    ]);
    expect(mailReplySubject('通知'), 'Re: 通知');
    expect(mailReplySubject('回复：通知'), '回复：通知');
    expect(mailReplySubject('RE: 通知'), 'RE: 通知');
  });
}
