import 'package:flutter/material.dart';

/// Palette ispirata a Slack/Rocket.Chat, coerente con il client web (tema chiaro e scuro).
class AT extends ThemeExtension<AT> {
  final Color sidebar, sidebarText, sidebarMuted, sidebarActive, sidebarHover;
  final Color surface, surface2, border, text, muted, accent, mention, codeBg, online;

  const AT({
    required this.sidebar,
    required this.sidebarText,
    required this.sidebarMuted,
    required this.sidebarActive,
    required this.sidebarHover,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.mention,
    required this.codeBg,
    required this.online,
  });

  static const light = AT(
    sidebar: Color(0xFF3F0E40),
    sidebarText: Color(0xFFFFFFFF),
    sidebarMuted: Color(0xFFCFC3CF),
    sidebarActive: Color(0xFF1164A3),
    sidebarHover: Color(0xFF350D36),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF8F8F8),
    border: Color(0xFFE2E2E2),
    text: Color(0xFF1D1C1D),
    muted: Color(0xFF616061),
    accent: Color(0xFF1264A3),
    mention: Color(0xFFE01E5A),
    codeBg: Color(0xFFF6F6F6),
    online: Color(0xFF2BAC76),
  );

  static const dark = AT(
    sidebar: Color(0xFF19171D),
    sidebarText: Color(0xFFE8E8E8),
    sidebarMuted: Color(0xFF9A9A9E),
    sidebarActive: Color(0xFF1164A3),
    sidebarHover: Color(0xFF27242C),
    surface: Color(0xFF1A1D21),
    surface2: Color(0xFF222529),
    border: Color(0xFF35373B),
    text: Color(0xFFD1D2D3),
    muted: Color(0xFFABABAD),
    accent: Color(0xFF1D9BD1),
    mention: Color(0xFFE01E5A),
    codeBg: Color(0xFF232529),
    online: Color(0xFF2BAC76),
  );

  static AT of(BuildContext c) => Theme.of(c).extension<AT>()!;

  @override
  AT copyWith() => this;

  @override
  AT lerp(AT? other, double t) => t < .5 ? this : (other ?? this);
}

ThemeData buildTheme(Brightness b) {
  final at = b == Brightness.dark ? AT.dark : AT.light;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4A154B), brightness: b).copyWith(
    primary: at.accent,
    surface: at.surface,
    onSurface: at.text,
    outlineVariant: at.border,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
    scaffoldBackgroundColor: at.surface,
    extensions: [at],
    fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
    dividerColor: at.border,
    appBarTheme: AppBarTheme(
      backgroundColor: at.surface,
      foregroundColor: at.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: at.border)),
      titleTextStyle: TextStyle(color: at.text, fontSize: 17, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: at.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: at.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: at.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: at.accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF007A5A),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(color: at.surface2, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: at.surface, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: at.surface, surfaceTintColor: Colors.transparent),
  );
}
