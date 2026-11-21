import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Palette {
  final Color bg, card, ink, mute, acc, accSoft, sand, line, ok;
  const Palette({required this.bg, required this.card, required this.ink, required this.mute,
    required this.acc, required this.accSoft, required this.sand, required this.line, required this.ok});

  static const light = Palette(bg: Color(0xFFFBF3E8), card: Colors.white, ink: Color(0xFF2A1A10),
    mute: Color(0xFF7D6B5D), acc: Color(0xFFB84C1E), accSoft: Color(0xFFF5E2D8),
    sand: Color(0xFFEFE3D3), line: Color(0xFFEADFCE), ok: Color(0xFFB84C1E));
  static const dark = Palette(bg: Color(0xFF15110E), card: Color(0xFF201A16), ink: Color(0xFFF8EEE2),
    mute: Color(0xFFB5A493), acc: Color(0xFFC44B1F), accSoft: Color(0xFF3D2218),
    sand: Color(0xFF2C241E), line: Color(0xFF322A23), ok: Color(0xFFF08A5D));
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).brightness == Brightness.dark ? Palette.dark : Palette.light;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: p.acc, brightness: b).copyWith(primary: p.acc, surface: p.card),
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(bodyColor: p.ink, displayColor: p.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.acc, foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 16)),
    ),
  );
}