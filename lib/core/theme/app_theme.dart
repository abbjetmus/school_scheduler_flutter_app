import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Skolpunktens färger — samma som Vuetify-temat i school-scheduler-nuxt-app
/// (nuxt.config.ts, tema "skolpunkten"). Färgerna betyder något: blått =
/// det man gör, gult = nu / väntar på dig, grått för resten.
class AppColors {
  static const background = Color(0xFFF4F6F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFEEF1F5);
  static const ink = Color(0xFF141B2D);
  static const ink2 = Color(0xFF444D62);
  static const ink3 = Color(0xFF5A6377);
  static const line = Color(0xFFE3E7EE);
  static const lineStrong = Color(0xFFC8CFDA);
  static const primary = Color(0xFF1F5FCC);
  static const primaryLight = Color(0xFFE1EAFB);
  static const onPrimaryLight = Color(0xFF12408F);
  static const sun = Color(0xFFF6C744);
  static const sunLight = Color(0xFFFFF4D1);
  static const onSunLight = Color(0xFF7A5700);
  static const error = Color(0xFFB42318);
  static const errorLight = Color(0xFFFDECEA);
  static const success = Color(0xFF1E7A46);
  static const successLight = Color(0xFFE3F4EA);
  static const warning = Color(0xFF8A6200);
}

/// Hörn som i webben: kort 18, rutor 16, fält 12, knappar helt runda.
class AppRadius {
  static const card = 18.0;
  static const tile = 16.0;
  static const field = 12.0;
}

/// [fontFamily] används i stället för Figtree från Google Fonts — för tester
/// som laddar typsnittet själva.
ThemeData buildAppTheme({String? fontFamily}) {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.onPrimaryLight,
    secondary: AppColors.ink,
    onSecondary: Colors.white,
    // Valt läge i SegmentedButton och liknande — ljusblått som aktiv meny.
    secondaryContainer: AppColors.primaryLight,
    onSecondaryContainer: AppColors.onPrimaryLight,
    tertiary: AppColors.sun,
    onTertiary: AppColors.ink,
    tertiaryContainer: AppColors.sunLight,
    onTertiaryContainer: AppColors.onSunLight,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.ink2,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.background,
    surfaceContainer: AppColors.surfaceLight,
    surfaceContainerHigh: AppColors.surfaceLight,
    surfaceContainerHighest: AppColors.surfaceLight,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.errorLight,
    onErrorContainer: AppColors.error,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
  );

  TextStyle font({double? fontSize, FontWeight? fontWeight, Color? color}) => fontFamily != null
      ? TextStyle(fontFamily: fontFamily, fontSize: fontSize, fontWeight: fontWeight, color: color)
      : GoogleFonts.figtree(fontSize: fontSize, fontWeight: fontWeight, color: color);

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily);
  final text = (fontFamily != null ? base.textTheme : GoogleFonts.figtreeTextTheme(base.textTheme)).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  const pill = StadiumBorder();
  final buttonText = font(fontSize: 15, fontWeight: FontWeight.w600);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 16);

  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: field(AppColors.lineStrong),
      enabledBorder: field(AppColors.lineStrong),
      focusedBorder: field(AppColors.primary, 2),
      errorBorder: field(AppColors.error),
      focusedErrorBorder: field(AppColors.error, 2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.ink3),
      hintStyle: const TextStyle(color: AppColors.ink3),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill, textStyle: buttonText, padding: buttonPadding, elevation: 0),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: pill,
        textStyle: buttonText,
        padding: buttonPadding,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.lineStrong),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill, textStyle: buttonText),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: pill,
      side: const BorderSide(color: AppColors.line),
      labelStyle: font(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink2),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: font(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
      width: 560,
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.ink3),
    tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 400)),
  );
}

/// Sidrubriken: 30 px, 800 — som `.page-title` i webben.
TextStyle pageTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineMedium!.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          height: 1.1,
        );

/// Små versaler över en sektion — som `.section-label` i webben.
TextStyle sectionLabelStyle(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall!.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppColors.ink3,
        );

TextStyle sectionTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 19, fontWeight: FontWeight.w700);
