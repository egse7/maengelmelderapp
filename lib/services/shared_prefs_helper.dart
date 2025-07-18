import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHelper {
  static Future<String> getOrCreateToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('anonymous_token');
    if (token == null) {
      token = _generateRandomToken();
      await prefs.setString('anonymous_token', token);
    }
    return token;
  }

  static String _generateRandomToken() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
        Random().nextInt(1000).toRadixString(36);
  }
}
