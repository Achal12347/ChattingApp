import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  CryptoService._();

  static final CryptoService instance = CryptoService._();

  static const _version = 'v1';

  Uint8List _deriveKey(String conversationId) {
    final seed = sha256
        .convert(utf8.encode('chatly-secure::$conversationId::$_version'))
        .bytes;
    return Uint8List.fromList(seed);
  }

  String encryptContent(String plainText, String conversationId) {
    if (plainText.isEmpty) return plainText;

    final key = enc.Key(_deriveKey(conversationId));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return '$_version:${base64Encode(iv.bytes)}:${encrypted.base64}';
  }

  String decryptIfNeeded(String raw, String conversationId) {
    if (raw.isEmpty || !raw.startsWith('$_version:')) return raw;

    try {
      final parts = raw.split(':');
      if (parts.length < 3) return raw;

      final iv = enc.IV(base64Decode(parts[1]));
      final encryptedData = parts.sublist(2).join(':');
      final key = enc.Key(_deriveKey(conversationId));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (_) {
      return raw;
    }
  }
}
