import 'package:crypto/crypto.dart';
import 'dart:convert';

class PasswordHasher {
  static const String _salt = 'dilapidation_survey_salt_2024';

  static String hashPassword(String password) {
    return sha256.convert(utf8.encode('$password$_salt')).toString();
  }

  static bool verifyPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }
}
