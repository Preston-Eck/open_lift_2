import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- The Vitality Rise Palette ---
  static const Color renewalTeal = Color(0xFF2A9D8F);
  static const Color motivationCoral = Color(0xFFE76F51);
  static const Color foundationalSlate = Color(0xFF264653);
  static const Color clarityCream = Color(0xFFF8F9FA);
  static const Color achievementGold = Color(0xFFE9C46A);
  static const Color errorRed = Color(0xFFD32F2F);

  // --- Light Theme (Vitality Rise) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: clarityCream,
      primaryColor: renewalTeal,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: renewalTeal,
        onPrimary: Colors.white,
        secondary: motivationCoral,
        onSecondary: Colors.white,
        tertiary: achievementGold,
        surface: Colors.white,
        onSurface: foundationalSlate,
        error: errorRed,
      ),

      // Typography
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(color: foundationalSlate, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: GoogleFonts.poppins(color: foundationalSlate, fontWeight: FontWeight.bold, fontSize: 28),
        titleLarge: GoogleFonts.poppins(color: foundationalSlate, fontWeight: FontWeight.w600, fontSize: 22),
        titleMedium: GoogleFonts.poppins(color: foundationalSlate, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.inter(color: foundationalSlate, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: foundationalSlate, fontSize: 14),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),

      // Component Themes
      appBarTheme: AppBarTheme(
        backgroundColor: clarityCream,
        foregroundColor: foundationalSlate,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: foundationalSlate,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: foundationalSlate),
      ),

      // FIX: Use CardThemeData instead of CardTheme to match ThemeData parameter type
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: foundationalSlate.withValues(alpha: 0.05), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: motivationCoral,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          elevation: 2,
          shadowColor: motivationCoral.withValues(alpha: 0.4),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: renewalTeal,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: renewalTeal, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: foundationalSlate.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: foundationalSlate.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: renewalTeal, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: foundationalSlate.withValues(alpha: 0.6)),
        floatingLabelStyle: GoogleFonts.inter(color: renewalTeal, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- Dark Theme (Fallback) ---
  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: renewalTeal,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    // FIX: Use CardThemeData
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 2,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      indicatorColor: renewalTeal,
    ),
  );
}