import 'package:flutter/material.dart';

// Definiciones de Color para asegurar consistencia
const Color _primaryPink = Color(0xFFF8B6B6);
const Color _darkBrown = Color(0xFF7A4A4A);
const Color _lightBrownText = Color(0xFFA57D7D);
const Color _tertiaryMint = Color(0xFF83D1B9); // El color verde/mint

// Colores específicos del Tema Oscuro
const Color _darkBackground = Color(0xFF121212); // Fondo oscuro base
const Color _darkSurface = Color(0xFF1D1D1D); // Para Cards, AppBar, etc.
const Color _darkOnSurface = Colors.white70; // Texto claro

// Estilo de AppBar compartido
const AppBarTheme _appBarThemeLight = AppBarTheme(
  backgroundColor: Colors.white,
  foregroundColor: _darkBrown, // Color del título y los iconos
  elevation: 1,
  iconTheme: IconThemeData(color: _darkBrown),
  titleTextStyle: TextStyle(
    color: _darkBrown,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
);

// Estilo de AppBar para el MODO OSCURO
const AppBarTheme _appBarThemeDark = AppBarTheme(
  backgroundColor: _darkSurface,
  foregroundColor: _darkOnSurface, // Texto en color claro
  elevation: 1,
  iconTheme: IconThemeData(color: _darkOnSurface),
  titleTextStyle: TextStyle(
    color: _darkOnSurface,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
);

// =================================================================
// 🚀 TEMA CLARO (LIGHT THEME)
// =================================================================
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _darkBrown,
    primary: _darkBrown,
    secondary: _primaryPink,
    tertiary: _tertiaryMint, // Usado en las SummaryCard
    background: Colors.white,
    surface: Colors.white,
    onPrimary: Colors.white, // Color de iconos y texto sobre el color primario
    onSurface: Colors.black87,
    // NO AÑADIMOS brightness: Brightness.light, ya que es el default
  ),
  scaffoldBackgroundColor: Colors.grey[50], // Fondo ligeramente gris
  appBarTheme: _appBarThemeLight,

  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _primaryPink.withAlpha(128)),
    ),
    focusedBorder:  OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _darkBrown, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _primaryPink.withAlpha(204)),
    ),
    labelStyle: const TextStyle(color: _lightBrownText),
  ),

  useMaterial3: true,
);

// =================================================================
// 🌑 TEMA OSCURO (DARK THEME)
// =================================================================
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _darkBrown,
    // 👇 ¡AQUÍ ESTÁ LA CORRECCIÓN CLAVE!
    brightness: Brightness.dark,
    // Colores adaptados:
    primary: _primaryPink, // Usar el rosa como Primary (se ve mejor en oscuro)
    secondary: _darkBrown,
    tertiary: _tertiaryMint,
    background: _darkBackground,
    surface: _darkSurface, // Fondo para Cards/Surfaces
    onPrimary: Colors.black, // Texto sobre el rosa
    onSurface: _darkOnSurface,
  ),
  scaffoldBackgroundColor: _darkBackground,
  appBarTheme: _appBarThemeDark,

  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _primaryPink.withAlpha(51)),
    ),
    focusedBorder:  OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: _primaryPink,
        width: 2,
      ), // Resaltar con Primary Pink
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _primaryPink.withAlpha(102)),
    ),
    labelStyle: TextStyle(color: _primaryPink.withAlpha(200)),
    hintStyle: TextStyle(color: _darkOnSurface.withOpacity(0.5)),
    fillColor: _darkSurface,
    filled: true,
  ),

  useMaterial3: true,
);
