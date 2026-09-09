import 'package:web/web.dart' as web;

String? readSetting(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

bool writeSetting(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
    return web.window.localStorage.getItem(key) == value;
  } catch (_) {
    return false;
  }
}
