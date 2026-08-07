import 'package:flutter/material.dart';

abstract final class AmanaTheme {
  static const Color primary = Color(0xFF006C4C);
  static const Color accent = Color(0xFFD59B2D);
  static const Color background = Color(0xFFF7F7F2);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
