import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  final SharedPreferences _prefs;
  LocalCache(this._prefs);

  String _key(String k) => 'cache:$k';

  String? read(String key) => _prefs.getString(_key(key));

  Future<void> write(String key, String json) async {
    await _prefs.setString(_key(key), json);
  }
}
