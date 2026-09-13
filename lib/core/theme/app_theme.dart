import 'package:flutter/material.dart';
import 'open_file_colors.dart';

class AppTheme {
  AppTheme._();

  static TextTheme _buildTextTheme(Color primary, Color secondary, Color disabled) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        height: 40 / 32,
        letterSpacing: -0.25,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        height: 32 / 24,
        letterSpacing: 0,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 28 / 20,
        letterSpacing: 0,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        letterSpacing: 0.15,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: 0.5,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0.25,
        color: secondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        letterSpacing: 0.4,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.1,
        color: primary,
      ),
    );
  }

  static ThemeData get darkTheme {
    const colors = OpenFileColors.dark;
    final textTheme = _buildTextTheme(
      colors.textPrimary,
      colors.textSecondary,
      colors.textDisabled,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.surfaceApp,
      colorScheme: ColorScheme.dark(
        surface: colors.surfaceApp,
        onSurface: colors.textPrimary,
        primary: colors.accentPrimary,
        onPrimary: colors.accentOnAccent,
        secondary: colors.accentPrimaryDim,
        onSecondary: colors.accentOnAccent,
        error: colors.stateError,
        onError: colors.surfaceRoot,
        errorContainer: colors.stateErrorContainer,
        outline: colors.divider,
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfaceApp,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: colors.surfaceApp,
        elevation: 0,
        indicatorColor: colors.accentPrimary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.accentPrimary, size: 24);
          }
          return IconThemeData(color: colors.textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelLarge?.copyWith(
              color: colors.accentPrimary,
              fontWeight: FontWeight.w500,
            );
          }
          return textTheme.labelLarge?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w400,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
        dragHandleColor: colors.divider,
        dragHandleSize: const Size(32, 4),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        actionTextColor: colors.accentPrimary,
      ),
      extensions: const [colors],
    );
  }

  static ThemeData get lightTheme {
    const colors = OpenFileColors.light;
    final textTheme = _buildTextTheme(
      colors.textPrimary,
      colors.textSecondary,
      colors.textDisabled,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.surfaceApp,
      colorScheme: ColorScheme.light(
        surface: colors.surfaceApp,
        onSurface: colors.textPrimary,
        primary: colors.accentPrimary,
        onPrimary: colors.accentOnAccent,
        secondary: colors.accentPrimaryDim,
        onSecondary: colors.accentOnAccent,
        error: colors.stateError,
        onError: colors.surfaceCard,
        errorContainer: colors.stateErrorContainer,
        outline: colors.divider,
      ),
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surfaceApp,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: colors.surfaceApp,
        elevation: 0,
        indicatorColor: colors.accentPrimary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.accentPrimary, size: 24);
          }
          return IconThemeData(color: colors.textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelLarge?.copyWith(
              color: colors.accentPrimary,
              fontWeight: FontWeight.w500,
            );
          }
          return textTheme.labelLarge?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w400,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
        dragHandleColor: colors.divider,
        dragHandleSize: const Size(32, 4),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.divider, width: 0.5),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        actionTextColor: colors.accentPrimary,
      ),
      extensions: const [colors],
    );
  }
}
