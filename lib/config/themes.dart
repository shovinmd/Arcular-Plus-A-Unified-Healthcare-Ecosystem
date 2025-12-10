import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    textTheme: GoogleFonts.poppinsTextTheme(),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    textTheme: GoogleFonts.poppinsTextTheme(),
  );
}

// User color palette
const Color userPrimary = Color(0xFF638ECB);
const Color userPrimaryDark = Color(0xFF395886);
const Color userAccent = Color(0xFF8AAEE0);
const Color userBackground = Color(0xFFF0F3FA);
const Color userCard = Color(0xFFD5DEEF);
const Color userLight = Color(0xFFB1C9EF);

final ThemeData userTheme = ThemeData(
  primaryColor: userPrimary,
  scaffoldBackgroundColor: userBackground,
  textTheme: GoogleFonts.poppinsTextTheme(),
  appBarTheme: AppBarTheme(
    backgroundColor: userPrimary,
    foregroundColor: Colors.white,
    elevation: 1,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  ),
  colorScheme: ColorScheme.fromSwatch().copyWith(
    primary: userPrimary,
    secondary: userAccent,
    background: userBackground,
    surface: userCard,
  ),
  cardColor: userCard,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: userPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: userLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    labelStyle: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: userAccent,
    foregroundColor: Colors.white,
  ),
);
