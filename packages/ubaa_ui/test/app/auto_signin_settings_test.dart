import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubaa_ui/src/app/settings/auto_signin_settings.dart';

void main() {
  const hideKey = ValueKey('settings-auto-signin-hide-recents');

  Future<List<bool>> mount(
    WidgetTester tester, {
    bool enabled = true,
    bool? battery = true,
    bool hidden = false,
    bool supported = true,
  }) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AutoSigninPanel(
              controls: UiAutoSigninControls(
                enabled: enabled,
                onChanged: (_) async {},
                onHide: () async {},
                batteryUnrestricted: battery,
                hideFromRecents: hidden,
                onHideFromRecentsChanged: supported
                    ? (value) async => changes.add(value)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('开着时和电池优化、自启动一起显示从后台隐藏开关', (tester) async {
    final changes = await mount(tester);
    expect(find.text('忽略电池优化'), findsOneWidget);
    expect(find.byKey(hideKey), findsOneWidget);
    await tester.tap(find.byKey(hideKey));
    await tester.pump();
    expect(changes, [true]);
  });

  testWidgets('已隐藏时开关为开，再点一次取消隐藏', (tester) async {
    final changes = await mount(tester, hidden: true);
    expect(tester.widget<SwitchListTile>(find.byKey(hideKey)).value, isTrue);
    await tester.tap(find.byKey(hideKey));
    await tester.pump();
    expect(changes, [false]);
  });

  testWidgets('功能关着、非 Android 或不支持时不显示从后台隐藏', (tester) async {
    for (final (enabled, battery, supported) in [
      (false, true, true),
      (true, null, true),
      (true, true, false),
    ]) {
      await mount(
        tester,
        enabled: enabled,
        battery: battery,
        supported: supported,
      );
      expect(find.byKey(hideKey), findsNothing);
    }
  });
}
