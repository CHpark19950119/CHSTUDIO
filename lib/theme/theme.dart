// DAILY theme — Material 3 + Pretendard. Light + Dark mode 지원.
// 사용자 지시 (2026-04-28 23:18): 상품급 전면개편.
import 'package:flutter/material.dart';

class DailyPalette {
  DailyPalette._();
  // Brand
  static const primary = Color(0xFF8B6F47);        // warm clay
  static const primaryLight = Color(0xFFA88868);
  static const primarySurface = Color(0xFFF3EBDD);
  static const gold = Color(0xFFC8975B);
  static const goldSurface = Color(0xFFF7EFE0);
  static const cream = Color(0xFFFEF8EC);
  // 배경·surface
  static const paper = Color(0xFFFAF8F3);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE8E2D4);
  // dark
  static const paperDark = Color(0xFF1A1815);
  static const cardDark = Color(0xFF252220);
  static const lineDark = Color(0xFF3A3631);
  static const inkDark = Color(0xFFEDE8DC);
  static const slateDark = Color(0xFFB5AE9F);
  static const ashDark = Color(0xFF7E7A70);
  // 텍스트 (light)
  static const ink = Color(0xFF2C2A26);
  static const slate = Color(0xFF5E5A53);
  static const ash = Color(0xFF8A857C);
  static const fog = Color(0xFFB8B2A6);
  // 상태
  static const success = Color(0xFF7A8A6E);
  static const warn = Color(0xFFC8975B);
  static const error = Color(0xFFB05A5A);
  static const info = Color(0xFF6B8BA3);
  static const sleep = Color(0xFF6B5DAF);
  static const craving = Color(0xFFB05A5A);
}

class DailySpace {
  DailySpace._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20, xxl = 28;
  static const double radius = 10, radiusL = 14, radiusXL = 20, radiusXXL = 28;
  // Elevation
  static const double elevSm = 1, elevMd = 2, elevLg = 4;
}

/// Material 3 Expressive 비대칭 코너 (Trendy v4 · 사용자 명시 1431·1433).
class DailyRadius {
  DailyRadius._();
  static const expressive = BorderRadius.only(
    topLeft: Radius.circular(32),
    topRight: Radius.circular(12),
    bottomLeft: Radius.circular(12),
    bottomRight: Radius.circular(32),
  );
  static const card = BorderRadius.all(Radius.circular(24));
  static const chip = BorderRadius.all(Radius.circular(14));
}

/// DAILY v12 luminous bento — STUDY v12 token DAILY 적용 (사용자 명시 2026-05-01 02:08).
/// 사용 범위 = DAILY 모든 화면. 기존 DailyPalette 와 공존.
class DailyV12 {
  DailyV12._();

  // Ambient gradient (배경)
  static const ambient1 = Color(0xFFECD9B0);
  static const ambient2 = Color(0xFFD4B88E);
  static const ambient3 = Color(0xFFA88868);

  // Ink (본문 텍스트)
  static const ink = Color(0xFF1A1814);
  static const ink2 = Color(0xFF3A352D);
  static const ink3 = Color(0xFF5E5A53);
  static const ink4 = Color(0xFF8A857C);

  // Slate (hero 패널 · DAILY 는 warm clay 기반)
  static const slate = Color(0xFF5A4B36);
  static const slate2 = Color(0xFF3E3424);
  static const slate3 = Color(0xFF241D14);

  // Cream (hero 텍스트)
  static const cream = Color(0xFFFFF8E0);
  static const cream2 = Color(0xFFF0E0B8);
  static const cream3 = Color(0xFFFAF1D6);

  // Bronze (primary accent)
  static const bronze = Color(0xFFB87020);
  static const bronzeDeep = Color(0xFF824A14);
  static const bronzeSoft = Color(0xFFD48A3A);
  static const bronzeBright = Color(0xFFF0B860);

  // Gold (secondary accent)
  static const gold = Color(0xFFC8975B);
  static const goldBright = Color(0xFFFFD478);

  // Glass (카드 배경)
  static Color glassLight = const Color(0xFFFFFAEB).withValues(alpha: 0.78);
  static Color glassLight2 = const Color(0xFFF5EFE2).withValues(alpha: 0.82);
  static Color glassEdge = const Color(0xFFFFFAEB).withValues(alpha: 0.92);

  // Glow (라디얼)
  static Color warmGlow = const Color(0xFFFFDC96).withValues(alpha: 0.7);
  static Color bronzeGlow = const Color(0xFFD48A3A).withValues(alpha: 0.42);
  static Color goldGlow = const Color(0xFFF0C060).withValues(alpha: 0.45);
}

/// v12 shape tokens.
class DailyV12Radius {
  DailyV12Radius._();
  static const card = BorderRadius.all(Radius.circular(24));
  static const bento = BorderRadius.all(Radius.circular(22));
  static const capsule = BorderRadius.all(Radius.circular(999));
  static const button = BorderRadius.all(Radius.circular(8));
}

/// v12 luminous shadow stack — embossed top + 4단 cinematic depth.
class DailyV12Shadow {
  DailyV12Shadow._();
  static List<BoxShadow> card() => [
        const BoxShadow(color: Color(0x14141C30), blurRadius: 2, offset: Offset(0, 1)),
        const BoxShadow(color: Color(0x29141C30), blurRadius: 16, offset: Offset(0, 8)),
        const BoxShadow(color: Color(0x3D141C30), blurRadius: 36, offset: Offset(0, 20)),
        const BoxShadow(color: Color(0x52141C30), blurRadius: 72, offset: Offset(0, 40)),
      ];
}

/// Soft Neumorphism 2.0 + Botanical Organic 결합 — Kit 3+9 정합 (사용자 명세 22:15).
class DailyShadow {
  DailyShadow._();
  static List<BoxShadow> soft({bool isDark = false, double opacity = 1.0}) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35 * opacity),
          blurRadius: 18, offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: const Color(0xFF2C3530).withValues(alpha: 0.25 * opacity),
          blurRadius: 6, offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF8B6F47).withValues(alpha: 0.10 * opacity),
        blurRadius: 24, offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: const Color(0xFF2C2A26).withValues(alpha: 0.04 * opacity),
        blurRadius: 6, offset: const Offset(0, 2),
      ),
    ];
  }
  static List<BoxShadow> hero({bool isDark = false}) => soft(isDark: isDark, opacity: 1.6);
}

const _textThemeLight = TextTheme(
  displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: DailyPalette.ink, height: 1.15, letterSpacing: -0.5),
  displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DailyPalette.ink, height: 1.2),
  headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: DailyPalette.ink, height: 1.25),
  headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: DailyPalette.ink, height: 1.3),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DailyPalette.ink, height: 1.3),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DailyPalette.ink, height: 1.4),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DailyPalette.ink, height: 1.4),
  bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: DailyPalette.ink, height: 1.5),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: DailyPalette.slate, height: 1.5),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: DailyPalette.slate, height: 1.4),
  labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DailyPalette.ink, letterSpacing: 0.1),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DailyPalette.slate, letterSpacing: 0.2),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: DailyPalette.ash, letterSpacing: 0.2),
);

const _textThemeDark = TextTheme(
  displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: DailyPalette.inkDark, height: 1.15, letterSpacing: -0.5),
  displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: DailyPalette.inkDark, height: 1.2),
  headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: DailyPalette.inkDark, height: 1.25),
  headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: DailyPalette.inkDark, height: 1.3),
  titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: DailyPalette.inkDark, height: 1.3),
  titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DailyPalette.inkDark, height: 1.4),
  titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: DailyPalette.inkDark, height: 1.4),
  bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: DailyPalette.inkDark, height: 1.5),
  bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: DailyPalette.slateDark, height: 1.5),
  bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: DailyPalette.slateDark, height: 1.4),
  labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DailyPalette.inkDark, letterSpacing: 0.1),
  labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DailyPalette.slateDark, letterSpacing: 0.2),
  labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: DailyPalette.ashDark, letterSpacing: 0.2),
);

ThemeData buildDailyTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: DailyPalette.primary,
    brightness: brightness,
    primary: DailyPalette.primary,
    surface: isDark ? DailyPalette.paperDark : DailyPalette.paper,
    onSurface: isDark ? DailyPalette.inkDark : DailyPalette.ink,
    error: DailyPalette.error,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? DailyPalette.paperDark : DailyPalette.paper,
    textTheme: isDark ? _textThemeDark : _textThemeLight,
    cardTheme: CardThemeData(
      color: isDark ? DailyPalette.cardDark : DailyPalette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DailySpace.radiusL)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? DailyPalette.paperDark : DailyPalette.paper,
      foregroundColor: isDark ? DailyPalette.inkDark : DailyPalette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? DailyPalette.cardDark : DailyPalette.paper,
      indicatorColor: DailyPalette.goldSurface,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? DailyPalette.primary : (isDark ? DailyPalette.ashDark : DailyPalette.ash),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? DailyPalette.primary : (isDark ? DailyPalette.ashDark : DailyPalette.ash),
        );
      }),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? DailyPalette.lineDark : DailyPalette.line,
      thickness: 0.8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? DailyPalette.cardDark : DailyPalette.goldSurface,
      side: BorderSide(color: isDark ? DailyPalette.lineDark : DailyPalette.line),
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? DailyPalette.inkDark : DailyPalette.ink),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DailySpace.radius)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
