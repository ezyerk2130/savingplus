import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF006D39);
  static const primaryContainer = Color(0xFF1DA75E);
  static const secondary = Color(0xFF904D00);
  static const surface = Color(0xFFF9F9FF);
  static const onBackground = Color(0xFF151C27);
  static const surfaceContainerLow = Color(0xFFF1F2F8);
  static const surfaceContainerHigh = Color(0xFFE8E9EF);
  static const cardWhite = Color(0xFFFFFFFF);
  static const error = Color(0xFFBA1A1A);
  static const success = Color(0xFF006D39);
  static const warning = Color(0xFFE8A317);
  static const onSurfaceVariant = Color(0xFF6B7280);
  static const ghostBorder = Color(0x26151C27); // 15% opacity
}

class AppGradients {
  static const primaryGradient = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryContainer],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double height;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? AppGradients.primaryGradient
              : const LinearGradient(colors: [Color(0xFF9E9E9E), Color(0xFFBDBDBD)]),
          borderRadius: BorderRadius.circular(100),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: DefaultTextStyle(
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

ThemeData buildAppTheme() {
  final headingFont = GoogleFonts.plusJakartaSans();
  final bodyFont = GoogleFonts.inter();

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.onBackground,
      error: AppColors.error,
      brightness: Brightness.light,
    ),
    textTheme: TextTheme(
      displayLarge: headingFont.copyWith(fontSize: 56, fontWeight: FontWeight.w600, color: AppColors.onBackground),
      displayMedium: headingFont.copyWith(fontSize: 45, fontWeight: FontWeight.w600, color: AppColors.onBackground),
      displaySmall: headingFont.copyWith(fontSize: 36, fontWeight: FontWeight.w600, color: AppColors.onBackground),
      headlineLarge: headingFont.copyWith(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.onBackground),
      headlineMedium: headingFont.copyWith(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.onBackground),
      headlineSmall: headingFont.copyWith(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onBackground),
      titleLarge: bodyFont.copyWith(fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.onBackground),
      titleMedium: bodyFont.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.onBackground),
      titleSmall: bodyFont.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground),
      bodyLarge: bodyFont.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.onBackground),
      bodyMedium: bodyFont.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onBackground),
      bodySmall: bodyFont.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant),
      labelLarge: bodyFont.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onBackground),
      labelMedium: bodyFont.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
      labelSmall: bodyFont.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: headingFont.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.onBackground,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.ghostBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.ghostBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: bodyFont.copyWith(color: AppColors.onSurfaceVariant, fontSize: 14),
      labelStyle: bodyFont.copyWith(color: AppColors.onSurfaceVariant, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: bodyFont.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.ghostBorder),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        foregroundColor: AppColors.onBackground,
        textStyle: bodyFont.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: bodyFont.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardWhite,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.cardWhite,
      indicatorColor: AppColors.primary.withOpacity(0.1),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return bodyFont.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary);
        }
        return bodyFont.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 24);
        }
        return const IconThemeData(color: AppColors.onSurfaceVariant, size: 24);
      }),
    ),
    dividerTheme: const DividerThemeData(
      color: Colors.transparent,
      space: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceContainerLow,
      selectedColor: AppColors.primary.withOpacity(0.12),
      labelStyle: bodyFont.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      shape: const StadiumBorder(),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}

/// Monospace text style for financial amounts
TextStyle moneyStyle({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
}) {
  return GoogleFonts.dmMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.onBackground,
  );
}
