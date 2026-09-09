import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _primaryOrange = Color(0xFFE65C20);
const _lightScaffold = Color(0xFFF7EBEA);
const _lightSurface = Color(0xFFFFFFFF);
const _lightOnSurface = Color(0xFF1C1917);
const _darkScaffold = Color(0xFF000000);
const _darkSurface = Color(0xFF2D1A18);
const _darkOnSurface = Color(0xFFF6E2DF);

TextTheme _mono(TextTheme base) => GoogleFonts.jetBrainsMonoTextTheme(base);

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  textTheme: _mono(ThemeData.light().textTheme),
  scaffoldBackgroundColor: _lightScaffold,
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    backgroundColor: _lightScaffold,
    foregroundColor: _lightOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  ),
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: _primaryOrange,
        brightness: Brightness.light,
      ).copyWith(
        primary: _primaryOrange,
        onPrimary: Colors.white,
        secondary: const Color(0xFFB45309),
        onSecondary: Colors.white,
        tertiary: const Color(0xFF3F6212),
        onTertiary: Colors.white,
        error: const Color(0xFFDC2626),
        onError: Colors.white,
        surface: _lightSurface,
        surfaceContainerLowest: _lightSurface,
        surfaceContainerLow: _lightSurface,
        surfaceContainer: _lightSurface,
        surfaceContainerHigh: const Color(0xFFF1E7E4),
        surfaceContainerHighest: const Color(0xFFF1E7E4),
        onSurface: _lightOnSurface,
      ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  textTheme: _mono(ThemeData.dark().textTheme),
  scaffoldBackgroundColor: _darkScaffold,
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    backgroundColor: _darkScaffold,
    foregroundColor: _darkOnSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: _primaryOrange,
        brightness: Brightness.dark,
      ).copyWith(
        primary: _primaryOrange,
        onPrimary: Colors.white,
        secondary: const Color(0xFFF0A868),
        onSecondary: Colors.black,
        tertiary: const Color(0xFF9BCB5A),
        onTertiary: Colors.black,
        error: const Color(0xFFF87171),
        onError: Colors.black,
        surface: _darkSurface,
        surfaceContainerLowest: _darkSurface,
        surfaceContainerLow: _darkSurface,
        surfaceContainer: _darkSurface,
        surfaceContainerHigh: const Color(0xFF3A2320),
        surfaceContainerHighest: const Color(0xFF3A2320),
        onSurface: _darkOnSurface,
      ),
);
