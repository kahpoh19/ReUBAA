import 'package:ubaa_platform/ubaa_platform.dart';

/// 邮箱地址和客户端专用密码。只在内存里流转，不打印内容。
final class MailCredential {
  const MailCredential({required this.address, required this.password});
  final String address, password;

  @override
  String toString() => 'MailCredential([REDACTED])';
}

abstract interface class MailCredentialStore {
  Future<MailCredential?> read();
  Future<void> write(MailCredential value);
  Future<void> clear();
}

final class MemoryMailCredentialStore implements MailCredentialStore {
  MailCredential? _value;
  @override
  Future<MailCredential?> read() async => _value;
  @override
  Future<void> write(MailCredential value) async => _value = value;
  @override
  Future<void> clear() async => _value = null;
}

/// 存进和学校密码同一套系统安全存储（Keychain、Keystore 等）。
final class SecureMailCredentialStore implements MailCredentialStore {
  SecureMailCredentialStore({SecureMaterialTransport? transport})
    : _transport = transport ?? const PlatformSecureMaterialTransport();
  final SecureMaterialTransport _transport;
  static const _addressKey = 'reubaa.mail.address';
  static const _passwordKey = 'reubaa.mail.password';

  @override
  Future<MailCredential?> read() async {
    final address = await _transport.read(_addressKey);
    final password = await _transport.read(_passwordKey);
    if (address == null || password == null) return null;
    return MailCredential(address: address, password: password);
  }

  @override
  Future<void> write(MailCredential value) async {
    await _transport.write(_addressKey, value.address);
    await _transport.write(_passwordKey, value.password);
  }

  @override
  Future<void> clear() async {
    await _transport.delete(_passwordKey);
    await _transport.delete(_addressKey);
  }
}
