import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';
import 'package:ubaa_mail/ubaa_mail.dart';

void main() {
  test('HTML 正文转成可读的纯文本', () {
    const html = '''
<html><head><title>通知</title><style>p{color:red}</style></head>
<body><!-- 跟踪代码 --><p>各位同学：</p><div>请于&nbsp;周五前提交&ldquo;选课确认&rdquo;。<br>谢谢！</div>
<ul><li>第一项</li><li>第二项 &amp; 补充</li></ul><script>alert(1)</script>
<p>&#x5B66;&#26657;</p></body></html>''';
    expect(
      mailHtmlToText(html),
      '各位同学：\n请于 周五前提交“选课确认”。\n谢谢！\n\n• 第一项\n• 第二项 & 补充\n\n学校',
    );
  });

  test('不认识的实体原样保留', () {
    expect(mailHtmlToText('a &unknown; b'), 'a &unknown; b');
  });

  test('只填用户名时补全学校域名', () {
    expect(buaaMailAddress(' zhangsan '), 'zhangsan@buaa.edu.cn');
    expect(buaaMailAddress('a@buaa.edu.cn'), 'a@buaa.edu.cn');
  });

  test('凭据打印时不带密码', () {
    const credential = MailCredential(address: 'a@buaa.edu.cn', password: 'x');
    expect('$credential', isNot(contains('x')));
  });
}
