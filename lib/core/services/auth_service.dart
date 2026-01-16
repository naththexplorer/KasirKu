import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class AuthService {
  static String generateSalt([int length = 16]) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (i) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static bool verifyPin(String inputPin, String storedHash, String salt) {
    final inputHash = hashPin(inputPin, salt);
    return inputHash == storedHash;
  }
}
