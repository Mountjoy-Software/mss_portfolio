import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences?>((ref) => null);

const _themeKey = 'theme_mode';

ThemeMode _parse(String? name) => switch (name) {
  'dark' => ThemeMode.dark,
  'light' => ThemeMode.light,
  _ => ThemeMode.system,
};

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      _parse(ref.read(preferencesProvider)?.getString(_themeKey));

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await ref.read(preferencesProvider)?.setString(_themeKey, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
