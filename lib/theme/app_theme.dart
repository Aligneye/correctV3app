import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Primary Brand Colors ────────────────────────────────────────────

  static const Color blue600 = Color(0xFF2563EB);
  static const Color purple600 = Color(0xFF9333EA);

  static const Color brandPrimary = blue600;
  static const Color brandSecondary = purple600;
  static const Color brandTertiary = Color(0xFF06B6D4);

  // ── Main Brand Gradient (blue-600 → purple-600) ─────────────────────

  static const LinearGradient brandGradient = LinearGradient(
    colors: [blue600, purple600],
  );

  // ── Mode-Specific Gradients ─────────────────────────────────────────

  static const LinearGradient trackingGradient = LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFF06B6D4)],
  );

  static const LinearGradient trainingGradient = LinearGradient(
    colors: [Color(0xFFC084FC), Color(0xFFEC4899)],
  );

  static const LinearGradient therapyGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFEF4444)],
  );

  static const LinearGradient meditationGradient = LinearGradient(
    colors: [Color(0xFF818CF8), Color(0xFF3B82F6)],
  );

  static const LinearGradient alignWalkGradient = LinearGradient(
    colors: [Color(0xFF2DD4BF), Color(0xFF10B981)],
  );

  static const LinearGradient ridingGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
  );

  // ── Status Colors ───────────────────────────────────────────────────

  static const Color goodPostureStart = Color(0xFF34D399);
  static const Color goodPostureEnd = Color(0xFF14B8A6);
  static const LinearGradient goodPostureGradient = LinearGradient(
    colors: [goodPostureStart, goodPostureEnd],
  );

  static const Color connectedBg = Color(0xFFDBEAFE);
  static const Color connectedText = Color(0xFF2563EB);

  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successText = Color(0xFF16A34A);

  // ── Text Colors ─────────────────────────────────────────────────────

  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // ── Surface & Background ────────────────────────────────────────────

  static const Color background = Color(0xFFFFFFFF);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color glassBorder = Color(0x80FFFFFF);
  static const Color inputBg = Color(0xFFF3F4F6);

  // ── Error / Destructive ─────────────────────────────────────────────

  static const Color destructive = Color(0xFFEF4444);

  // ── Border ──────────────────────────────────────────────────────────

  static const Color border = Color(0xFFE5E7EB);

  // ── Dark Palette ────────────────────────────────────────────────────

  static const Color _dkBg = Color(0xFF0F172A);
  static const Color _dkSurface = Color(0xFF1E293B);
  static const Color _dkBorder = Color(0xFF334155);
  static const Color _dkTextPrimary = Color(0xFFF1F5F9);
  static const Color _dkTextSecondary = Color(0xFF94A3B8);
  static const Color _dkInput = Color(0xFF1E293B);

  // ── Radii (rounded-2xl = 16, rounded-3xl = 24) ─────────────────────

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  // ── Page Background Gradient (blue-50 → white → purple-50) ─────────

  static LinearGradient pageBackgroundGradientFor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_dkBg, Color(0xFF131B2E), _dkBg],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF), Color(0xFFFAF5FF)],
    );
  }

  // ── Glass Card Decoration Helper ────────────────────────────────────

  static BoxDecoration glassCard({
    double radius = 16,
    Color? color,
    double opacity = 0.60,
  }) {
    return BoxDecoration(
      color: (color ?? cardSurface).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: glassBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 12,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  // ── Color Schemes ───────────────────────────────────────────────────

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: blue600,
    onPrimary: Color(0xFFFFFFFF),
    secondary: purple600,
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF06B6D4),
    onTertiary: Color(0xFFFFFFFF),
    error: destructive,
    onError: Color(0xFFFFFFFF),
    surface: cardSurface,
    onSurface: textPrimary,
    surfaceContainerHighest: Color(0xFFF1F5F9),
    onSurfaceVariant: textSecondary,
    outline: border,
    outlineVariant: Color(0xFFF3F4F6),
    inverseSurface: Color(0xFF1F2937),
    onInverseSurface: Color(0xFFFFFFFF),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: blue600,
    onPrimary: Color(0xFFFFFFFF),
    secondary: purple600,
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF06B6D4),
    onTertiary: Color(0xFFFFFFFF),
    error: Color(0xFFFB7185),
    onError: Color(0xFFFFFFFF),
    surface: _dkSurface,
    onSurface: _dkTextPrimary,
    surfaceContainerHighest: Color(0xFF334155),
    onSurfaceVariant: _dkTextSecondary,
    outline: _dkBorder,
    outlineVariant: Color(0xFF1E293B),
    inverseSurface: Color(0xFFF1F5F9),
    onInverseSurface: Color(0xFF0F172A),
  );

  // ── Theme Builder ───────────────────────────────────────────────────

  static ThemeData _buildTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _dkBg : background,
      fontFamily: 'Roboto',
    );

    final textTheme = base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            color: scheme.onSurface,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        );

    final btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );

    return base.copyWith(
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),

      iconTheme: IconThemeData(color: scheme.onSurface),
      dividerColor: scheme.outline,

      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(
            color: isDark ? scheme.outline : glassBorder,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _dkInput.withValues(alpha: 0.5) : inputBg,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: textMuted),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: btnShape,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: btnShape,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 2,
          shadowColor: blue600.withValues(alpha: 0.3),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: btnShape,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: btnShape,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXl),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.15),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        backgroundColor: scheme.primary.withValues(alpha: 0.08),
        labelStyle: TextStyle(
          color: scheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
      ),

      tabBarTheme: TabBarThemeData(
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusSm),
          color: scheme.surface,
        ),
        labelColor: scheme.onSurface,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerHeight: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? _dkTextSecondary : textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isDark
              ? _dkBorder.withValues(alpha: 0.8)
              : const Color(0xFFD1D5DB);
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return isDark ? _dkInput : inputBg;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 13),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: isDark
            ? _dkBorder
            : scheme.primary.withValues(alpha: 0.15),
        thumbColor: Colors.white,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 6,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.80),
        indicatorColor: scheme.primary.withValues(alpha: 0.08),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            );
          }
          return TextStyle(fontSize: 12, color: textMuted);
        }),
      ),

      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
    );
  }

  // ── Public Accessors ────────────────────────────────────────────────

  static ThemeData get lightTheme => _buildTheme(_lightScheme);
  static ThemeData get darkTheme => _buildTheme(_darkScheme);
}
