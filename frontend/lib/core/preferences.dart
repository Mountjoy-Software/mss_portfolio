import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

const _themeKey = 'mss.theme_mode';

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

ThemeMode _parse(String? name) => switch (name) {
  'dark' => ThemeMode.dark,
  'light' => ThemeMode.light,
  _ => ThemeMode.system,
};

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _parse(readSetting(_themeKey));

  bool set(ThemeMode mode) {
    state = mode;
    return writeSetting(_themeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
