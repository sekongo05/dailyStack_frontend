import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couleurs de marque et sémantiques (Option A : Studio Charbon & Indigo).
class AppColors {
  AppColors._();

  // Marque (Indigo franc, zéro néon)
  static const Color brand = Color(0xFF4F46E5);
  static const Color brandBright = Color(0xFF6366F1);
  static const Color brandDark = Color(0xFF4338CA);
  static const Color brandSoft = Color(0xFFEEF2FF);

  // Domaines
  static const Color backend = Color(0xFF059669);
  static const Color devops = Color(0xFF0284C7);

  // Sémantiques
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color streak = Color(0xFFEA580C);

  // Neutres clairs (Zinc neutre, net et contrasté)
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF4F4F5);
  static const Color lightTextPrimary = Color(0xFF09090B);
  static const Color lightTextSecondary = Color(0xFF71717A);
  static const Color lightBorder = Color(0xFFE4E4E7);

  // Neutres sombres (Charbon pur, esprit Linear / Vercel)
  static const Color darkBackground = Color(0xFF09090B);
  static const Color darkSurface = Color(0xFF121215);
  static const Color darkSurfaceAlt = Color(0xFF1C1C21);
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkBorder = Color(0xFF27272A);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double pill = 999.0;
}

/// Neutres dépendants du mode clair/sombre, accessibles via `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color surfaceAlt;
  final Color border;
  final Color textMuted;

  const AppPalette({
    required this.surfaceAlt,
    required this.border,
    required this.textMuted,
  });

  static const light = AppPalette(
    surfaceAlt: AppColors.lightSurfaceAlt,
    border: AppColors.lightBorder,
    textMuted: AppColors.lightTextSecondary,
  );

  static const dark = AppPalette(
    surfaceAlt: AppColors.darkSurfaceAlt,
    border: AppColors.darkBorder,
    textMuted: AppColors.darkTextSecondary,
  );

  @override
  AppPalette copyWith({Color? surfaceAlt, Color? border, Color? textMuted}) {
    return AppPalette(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  Color get warningFg => Theme.of(this).brightness == Brightness.dark
      ? AppColors.warning
      : const Color(0xFFB45309);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        textPrimary: AppColors.lightTextPrimary,
        palette: AppPalette.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        textPrimary: AppColors.darkTextPrimary,
        palette: AppPalette.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required AppPalette palette,
  }) {
    final isDark = brightness == Brightness.dark;
    final activeBrand = isDark ? AppColors.brandBright : AppColors.brand;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: activeBrand,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      error: AppColors.error,
      outline: palette.border,
      outlineVariant: palette.border,
    );

    final textTheme = _textTheme(textPrimary, palette.textMuted);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final buttonText = textTheme.labelLarge;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: palette.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.surfaceAlt,
          disabledForegroundColor: palette.textMuted,
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(color: palette.border, width: 1.5),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: const Size(44, 44),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
        prefixIconColor: palette.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppColors.brandBright : AppColors.brand,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: isDark ? AppColors.brand.withValues(alpha: 0.25) : AppColors.brandSoft,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        labelStyle: textTheme.labelMedium,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: isDark ? AppColors.brand.withValues(alpha: 0.25) : AppColors.brandSoft,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? (isDark ? AppColors.brandBright : AppColors.brand) : palette.textMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? textPrimary : palette.textMuted,
          );
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: palette.surfaceAlt,
        circularTrackColor: palette.surfaceAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : null,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor:
              isDark ? AppColors.brand.withValues(alpha: 0.25) : AppColors.brandSoft,
          selectedForegroundColor: isDark ? Colors.white : AppColors.brandDark,
          side: BorderSide(color: palette.border),
          textStyle: textTheme.labelMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textMuted,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minVerticalPadding: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: AppColors.error),
    );
  }

  static TextStyle monoStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextTheme _textTheme(Color primary, Color muted) {
    final base = GoogleFonts.interTextTheme();
    TextStyle? s(TextStyle? style, double size, FontWeight weight,
            {double height = 1.35, double spacing = 0, Color? color}) =>
        style?.copyWith(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: color ?? primary,
        );

    TextStyle heading(double size, FontWeight weight,
            {double height = 1.18, double spacing = -0.4}) =>
        GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: primary,
        );

    return base.copyWith(
      displaySmall: heading(34, FontWeight.w700, height: 1.12, spacing: -1.0),
      headlineLarge: heading(30, FontWeight.w700, height: 1.15, spacing: -0.8),
      headlineMedium: heading(26, FontWeight.w700, height: 1.18, spacing: -0.6),
      headlineSmall: heading(22, FontWeight.w700, height: 1.22, spacing: -0.4),
      titleLarge: heading(19, FontWeight.w700, height: 1.25, spacing: -0.2),
      titleMedium: s(base.titleMedium, 16, FontWeight.w600, spacing: -0.1),
      titleSmall: s(base.titleSmall, 14, FontWeight.w600),
      bodyLarge: s(base.bodyLarge, 15.5, FontWeight.w400, height: 1.6),
      bodyMedium: s(base.bodyMedium, 14.5, FontWeight.w400, height: 1.5),
      bodySmall: s(base.bodySmall, 13, FontWeight.w500, height: 1.45, color: muted),
      labelLarge: s(base.labelLarge, 14.5, FontWeight.w600),
      labelMedium: s(base.labelMedium, 13, FontWeight.w600),
      labelSmall: s(base.labelSmall, 11.5, FontWeight.w600, spacing: 0.2),
    );
  }
}
