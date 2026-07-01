// ============================================================
// 모이쇼 디자인시스템 v2 — Flutter ThemeData 매핑
// tokens.css 의 단일 출처를 Flutter 로 1:1 이식.
// 앱에서는 core/theme/ 로 옮겨 MaterialApp(theme: moishoTheme()) 로 사용.
//
// 색 출입 권한(money/community)은 색 자체가 아니라 "어떤 화면에서
// 어떤 색을 쓰는가"의 규칙이다 → MoishoSurface 위젯(아래 components)에서 강제.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontFeature;

// ---------- 1. PRIMITIVE / SEMANTIC COLORS (tokens.css 그대로) ----------
abstract class MoishoColors {
  // brand — 신뢰·정산
  static const primary      = Color(0xFF3B5CFF);
  static const primaryHover = Color(0xFF2E47E6);
  static const primaryPress = Color(0xFF2438B8);
  static const primarySoft  = Color(0xFFEEF2FF);

  // warm — 모임 온기 (community 전용)
  static const warm       = Color(0xFFFF6B5C);
  static const warmHover  = Color(0xFFED5746);
  static const warmSoft   = Color(0xFFFFF0EE);
  static const warmStrong = Color(0xFFE0513F);

  // status
  static const success       = Color(0xFF00C781);
  static const successSoft   = Color(0xFFE5FBF3);
  static const successStrong = Color(0xFF008857);
  static const danger        = Color(0xFFF0384B); // 크림슨
  static const dangerSoft    = Color(0xFFFEE9EC);
  static const warning       = Color(0xFFFFA722);

  // ink / text
  static const ink       = Color(0xFF161A24); // 금액·헤드라인
  static const textTitle = Color(0xFF272D3B);
  static const textBody  = Color(0xFF3C4456);
  static const textMuted = Color(0xFF6E7689);
  static const textFaint = Color(0xFF9AA3B5);

  // surface / border
  static const page         = Color(0xFFFFFFFF);
  static const card         = Color(0xFFFFFFFF);
  static const sunken       = Color(0xFFF4F6FA);
  static const borderSubtle = Color(0xFFEBEEF4);
  static const border       = Color(0xFFDDE2EC);
  static const borderStrong = Color(0xFFC5CCDA);

  // 마스코트 전용(UI 시맨틱 아님)
  static const jellyYellow = Color(0xFFFFC83D);
}

// ---------- 2. RADIUS / SHADOW / MOTION ----------
abstract class MoishoRadius {
  static const mini = 6.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 36.0, pill = 999.0;
}

abstract class MoishoShadow {
  static const card = [BoxShadow(color: Color(0x0F3B5CFF), blurRadius: 20, offset: Offset(0, 4))]; // 0 4 20 rgba(59,92,255,.06)
  static const pop  = [BoxShadow(color: Color(0x291E2E8F), blurRadius: 40, offset: Offset(0, 16))];
  static const glowBlue = [BoxShadow(color: Color(0x593B5CFF), blurRadius: 20, offset: Offset(0, 6))];
  static const glowSlab = [BoxShadow(color: Color(0x523B5CFF), blurRadius: 26, offset: Offset(0, 10))];
  static const glowWarm = [BoxShadow(color: Color(0x4DFF6B5C), blurRadius: 12, offset: Offset(0, 4))];
}

abstract class MoishoMotion {
  // "또로롱" — 가볍게 통통
  static const spring   = Cubic(0.34, 1.56, 0.64, 1.0);
  static const standard = Cubic(0.2, 0.0, 0.2, 1.0);
  static const easeOut  = Cubic(0.16, 1.0, 0.3, 1.0);
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
}

// 금액·숫자 텍스트엔 항상 이 feature (tabular numerals)
const kTabular = [FontFeature.tabularFigures()];

// ---------- 3. TYPOGRAPHY (Pretendard) ----------
TextTheme _textTheme() => const TextTheme(
  // 에디토리얼 헤드라인 앵커 (800)
  displaySmall:  TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.18, letterSpacing: -0.6, color: MoishoColors.ink),
  headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.18, color: MoishoColors.ink),
  headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.35, color: MoishoColors.ink),
  titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.35, letterSpacing: -0.18, color: MoishoColors.textTitle),
  titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5,  color: MoishoColors.textTitle),
  bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5,  color: MoishoColors.textBody),
  labelMedium:   TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.35, color: MoishoColors.textMuted),
  labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.35, color: MoishoColors.textMuted),
);

// ---------- 4. THEME ----------
ThemeData moishoTheme() {
  final scheme = const ColorScheme.light(
    primary: MoishoColors.primary,
    onPrimary: Colors.white,
    secondary: MoishoColors.warm,          // community 액센트
    onSecondary: Colors.white,
    error: MoishoColors.danger,
    surface: MoishoColors.card,
    onSurface: MoishoColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Pretendard',
    colorScheme: scheme,
    scaffoldBackgroundColor: MoishoColors.page,
    textTheme: _textTheme(),
    cardTheme: CardTheme(
      color: MoishoColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MoishoRadius.xl)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MoishoColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MoishoRadius.md)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MoishoColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: const TextStyle(color: MoishoColors.textFaint),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(MoishoRadius.md), borderSide: const BorderSide(color: MoishoColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(MoishoRadius.md), borderSide: const BorderSide(color: MoishoColors.primary, width: 1.5)),
    ),
    extensions: const [MoishoTokens()],
  );
}

// ---------- 5. ThemeExtension — Material 표준에 없는 토큰 ----------
@immutable
class MoishoTokens extends ThemeExtension<MoishoTokens> {
  const MoishoTokens();
  final Color warm = MoishoColors.warm;
  final Color success = MoishoColors.success;
  final Color ink = MoishoColors.ink;
  final Color sunken = MoishoColors.sunken;

  @override
  MoishoTokens copyWith() => const MoishoTokens();
  @override
  MoishoTokens lerp(ThemeExtension<MoishoTokens>? other, double t) => this;
}
