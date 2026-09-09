import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';

const _themeKey = 'mss.theme_mode';

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
