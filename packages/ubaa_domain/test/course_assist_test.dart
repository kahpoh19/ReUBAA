import 'package:test/test.dart';
import 'package:ubaa_domain/ubaa_domain.dart';

void main() {
  test('从后台隐藏随设置保存，旧存档没有这一项时按关闭读取', () {
    const saved = AutoSigninSettings(
      unlocked: true,
      enabled: true,
      hideFromRecents: true,
    );
    expect(AutoSigninSettings.fromJson(saved.toJson()), saved);
    final legacy = AutoSigninSettings.fromJson({
      'unlocked': true,
      'enabled': true,
    });
    expect(legacy.hideFromRecents, isFalse);
    expect(legacy.enabled, isTrue);
  });

  test('只有开着时才真的从后台隐藏，未解锁的存档一律不隐藏', () {
    const off = AutoSigninSettings(unlocked: true, hideFromRecents: true);
    expect(off.hidesFromRecents, isFalse);
    expect(off.copyWith(enabled: true).hidesFromRecents, isTrue);
    final locked = AutoSigninSettings.fromJson({
      'unlocked': false,
      'enabled': true,
      'hideFromRecents': true,
    });
    expect(locked.hideFromRecents, isFalse);
    expect(locked.hidesFromRecents, isFalse);
  });
}
