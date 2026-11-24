import 'package:flutter/material.dart';

/// Sistema visual: poucas cores, hierarquia forte e superfícies sem sombras pesadas.
class AppTheme {
  static const accent = Color(0xff566bd9);
  static const ink = Color(0xff172033);
  static const paper = Color(0xfff6f7fa);
  static const radius = 16.0;

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness,
      surface: dark ? const Color(0xff171b24) : Colors.white);
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xff10141c) : paper,
      canvasColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xff10141c) : paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700,
          letterSpacing: -.5, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: scheme.primary, width: 1.4)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(
        minimumSize: const Size(44,44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        side: BorderSide(color:scheme.outlineVariant.withValues(alpha:.65)),
        padding:const EdgeInsets.symmetric(horizontal:4,vertical:2)),
      listTileTheme: ListTileThemeData(
        iconColor:scheme.onSurfaceVariant,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: .55)),
      tooltipTheme: TooltipThemeData(decoration: BoxDecoration(
        color: scheme.inverseSurface, borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 12)),
    );
  }
}
