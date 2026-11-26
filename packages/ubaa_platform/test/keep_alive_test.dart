import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_platform/ubaa_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.edu.buaa.ubaa/keep-alive');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('从后台隐藏经保活通道交给原生端', () async {
    final gateway = ChannelKeepAliveGateway(enabled: true);
    await gateway.setHiddenFromRecents(true);
    await gateway.setHiddenFromRecents(false);
    expect(calls.map((c) => (c.method, c.arguments)), [
      ('setHiddenFromRecents', true),
      ('setHiddenFromRecents', false),
    ]);
  });

  test('不支持后台保活的平台不调用原生端', () async {
    await ChannelKeepAliveGateway(enabled: false).setHiddenFromRecents(true);
    await const UnavailableKeepAliveGateway().setHiddenFromRecents(true);
    expect(calls, isEmpty);
  });
}
