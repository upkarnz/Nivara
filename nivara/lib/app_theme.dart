import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Brand seed ─────────────────────────────────────────────────────────────
  static const _seed = Color(0xFF6366F1); // indigo

  // ── Light palette ──────────────────────────────────────────────────────────
  // Warm lavender-tinted surfaces so white panels "pop" against the background.
  static const _lBackground  = Color(0xFFF4F3FF); // soft lavender mist
  static const _lSurface     = Color(0xFFFFFFFF); // pure white cards
  static const _lSurfaceVar  = Color(0xFFECEBFD); // tinted container
  static const _lPrimary     = Color(0xFF4F46E5); // rich indigo
  static const _lOnPrimary   = Color(0xFFFFFFFF);
  static const _lSecondary   = Color(0xFF7C3AED); // violet accent
  static const _lOnSecondary = Color(0xFFFFFFFF);
  static const _lTertiary    = Color(0xFF0EA5E9); // sky accent
  static const _lError       = Color(0xFFDC2626);
  static const _lOnBg        = Color(0xFF18183A); // deep navy text
  static const _lOnSurface   = Color(0xFF1E1E3F);
  static const _lOutline     = Color(0xFFCBC8EB); // subtle divider
  static const _lOutlineVar  = Color(0xFFE4E2F8);

  // ── Dark palette (unchanged) ───────────────────────────────────────────────
  static const _dBackground = Color(0xFF0F0F1A);

  // ── Shared ─────────────────────────────────────────────────────────────────
  static const _fontFamily = 'SF Pro Display';
  static const _cardRadius = Radius.circular(16);
  static const _inputRadius = Radius.circular(12);

  // ── Light theme ────────────────────────────────────────────────────────────

  static ThemeData get light {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary:           _lPrimary,
      onPrimary:         _lOnPrimary,
      primaryContainer:  Color(0xFFDDD9FF),
      onPrimaryContainer: Color(0xFF1A0080),
      secondary:         _lSecondary,
      onSecondary:       _lOnSecondary,
      secondaryContainer: Color(0xFFEFD6FF),
      onSecondaryContainer: Color(0xFF2E004E),
      tertiary:          _lTertiary,
      onTertiary:        _lOnPrimary,
      tertiaryContainer: Color(0xFFBAE6FD),
      onTertiaryContainer: Color(0xFF003048),
      error:             _lError,
      onError:           _lOnPrimary,
      errorContainer:    Color(0xFFFFDAD6),
      onErrorContainer:  Color(0xFF410002),
      surface:           _lSurface,
      onSurface:         _lOnSurface,
      surfaceContainerHighest: _lSurfaceVar,
      onSurfaceVariant:  Color(0xFF49466D),
      outline:           _lOutline,
      outlineVariant:    _lOutlineVar,
      shadow:            Color(0xFF000000),
      scrim:             Color(0xFF000000),
      inverseSurface:    Color(0xFF2E2C43),
      onInverseSurface:  Color(0xFFF4F3FF),
      inversePrimary:    Color(0xFFBBB3FF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: _lBackground,
      fontFamily: _fontFamily,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: _lSurface,
        foregroundColor: _lOnSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _lOutline,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _lOnSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: _lOnSurface, size: 22),
        actionsIconTheme: IconThemeData(color: Color(0xFF49466D), size: 22),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: Border(
          bottom: BorderSide(color: _lOutlineVar, width: 0.5),
        ),
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: _lSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(_cardRadius),
          side: BorderSide(color: _lOutlineVar, width: 1),
        ),
        margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),

      // ── Text ───────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge:   TextStyle(color: _lOnBg, fontWeight: FontWeight.w800, letterSpacing: -1.5),
        displayMedium:  TextStyle(color: _lOnBg, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        displaySmall:   TextStyle(color: _lOnBg, fontWeight: FontWeight.w700),
        headlineLarge:  TextStyle(color: _lOnBg, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: _lOnBg, fontWeight: FontWeight.w600),
        headlineSmall:  TextStyle(color: _lOnBg, fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: _lOnSurface, fontWeight: FontWeight.w700, fontSize: 18),
        titleMedium:    TextStyle(color: _lOnSurface, fontWeight: FontWeight.w600, fontSize: 15),
        titleSmall:     TextStyle(color: _lOnSurface, fontWeight: FontWeight.w600, fontSize: 13),
        bodyLarge:      TextStyle(color: _lOnSurface, fontSize: 16, height: 1.6),
        bodyMedium:     TextStyle(color: _lOnSurface, fontSize: 14, height: 1.5),
        bodySmall:      TextStyle(color: Color(0xFF49466D), fontSize: 12, height: 1.4),
        labelLarge:     TextStyle(color: _lPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        labelMedium:    TextStyle(color: Color(0xFF49466D), fontSize: 12),
        labelSmall:     TextStyle(color: Color(0xFF49466D), fontSize: 11),
      ),

      // ── Inputs ─────────────────────────────────────────────────────────────
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: _lSurfaceVar,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(_inputRadius),
          borderSide: BorderSide(color: _lOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(_inputRadius),
          borderSide: BorderSide(color: _lOutlineVar),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(_inputRadius),
          borderSide: BorderSide(color: _lPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(_inputRadius),
          borderSide: BorderSide(color: _lError, width: 1.5),
        ),
        labelStyle: TextStyle(color: Color(0xFF49466D), fontSize: 14),
        hintStyle: TextStyle(color: Color(0xFF9D9AC0), fontSize: 14),
        prefixIconColor: Color(0xFF49466D),
        suffixIconColor: Color(0xFF49466D),
      ),

      // ── Buttons ────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lPrimary,
          foregroundColor: _lOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(_cardRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _lPrimary,
          foregroundColor: _lOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(_cardRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lPrimary,
          side: const BorderSide(color: _lPrimary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(_cardRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lPrimary,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── FAB ────────────────────────────────────────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _lPrimary,
        foregroundColor: _lOnPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      // ── Chips ──────────────────────────────────────────────────────────────
      chipTheme: const ChipThemeData(
        backgroundColor: _lSurfaceVar,
        selectedColor: _lPrimary,
        disabledColor: _lOutlineVar,
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _lOnSurface,
        ),
        secondaryLabelStyle: TextStyle(color: _lOnPrimary),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: StadiumBorder(
          side: BorderSide(color: _lOutlineVar),
        ),
        elevation: 0,
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: _lOutlineVar,
        thickness: 0.5,
        space: 1,
      ),

      // ── ListTile ───────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: Color(0xFF49466D),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: _lOnSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF49466D),
          fontSize: 13,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── BottomNav ──────────────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lSurface,
        selectedItemColor: _lPrimary,
        unselectedItemColor: Color(0xFF9D9AC0),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // ── NavigationBar (Material 3) ─────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lSurface,
        indicatorColor: const Color(0xFFDDD9FF),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _lPrimary, size: 24);
          }
          return const IconThemeData(color: Color(0xFF9D9AC0), size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _lPrimary,
            );
          }
          return const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            color: Color(0xFF9D9AC0),
          );
        }),
        elevation: 8,
        shadowColor: const Color(0x1A4F46E5),
      ),

      // ── Switch ─────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _lPrimary : const Color(0xFFBBB8D8)),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFFDDD9FF)
                : _lOutlineVar),
      ),

      // ── Checkbox / Radio ───────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _lPrimary : Colors.transparent),
        checkColor: WidgetStateProperty.all(_lOnPrimary),
        side: const BorderSide(color: _lOutline, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? _lPrimary : const Color(0xFF49466D)),
      ),

      // ── Dialogs ────────────────────────────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: _lSurface,
        elevation: 4,
        shadowColor: Color(0x1A4F46E5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: _lOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF49466D),
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // ── BottomSheet ────────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 8,
        shadowColor: Color(0x1A4F46E5),
        dragHandleColor: Color(0xFFCBC8EB),
      ),

      // ── SnackBar ───────────────────────────────────────────────────────────
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF18183A),
        contentTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ── Tooltip ────────────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF18183A).withValues(alpha: 0.92),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // ── Progress indicators ────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _lPrimary,
        linearTrackColor: _lSurfaceVar,
        circularTrackColor: _lSurfaceVar,
      ),

      // ── Icon ───────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: Color(0xFF49466D), size: 22),
      primaryIconTheme: const IconThemeData(color: _lPrimary, size: 22),
    );
  }

  // ── Dark theme (unchanged) ─────────────────────────────────────────────────

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: _dBackground,
        fontFamily: _fontFamily,
      );
}
