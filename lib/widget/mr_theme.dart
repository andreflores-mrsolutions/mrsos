import 'package:flutter/material.dart';

import 'colors.dart';

class MRTheme {
  const MRTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Manrope',
      colorScheme: const ColorScheme.light(
        primary: MRSColors.primary,
        onPrimary: Colors.white,
        secondary: MRSColors.teal,
        onSecondary: Colors.white,
        tertiary: MRSColors.accent,
        surface: MRSColors.surface,
        onSurface: MRSColors.text,
        error: MRSColors.dangerText,
        outline: MRSColors.border,
        outlineVariant: MRSColors.border,
      ),
      scaffoldBackgroundColor: MRSColors.bg,
    );

    final text = base.textTheme.apply(
      bodyColor: MRSColors.text,
      displayColor: MRSColors.text,
      fontFamily: 'Manrope',
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.35),
        bodyMedium: text.bodyMedium?.copyWith(
          height: 1.35,
          color: MRSColors.text,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MRSColors.surface,
        foregroundColor: MRSColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: MRSColors.primary),
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: MRSColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MRSColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MRSColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          color: MRSColors.muted,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: MRSColors.muted,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: MRSColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: MRSColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: MRSColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: MRSColors.dangerText),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: MRSColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: MRSColors.primary,
          side: const BorderSide(color: MRSColors.border),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MRSColors.accent,
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MRSColors.teal,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color:
                states.contains(WidgetState.selected)
                    ? MRSColors.accent
                    : MRSColors.muted,
          ),
        ),
        backgroundColor: MRSColors.surface,
        indicatorColor: MRSColors.blueSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Manrope',
            color:
                states.contains(WidgetState.selected)
                    ? MRSColors.primary
                    : MRSColors.muted,
            fontSize: 11,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : MRSColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? MRSColors.accent
                  : MRSColors.border,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MRSColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: MRSColors.border,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MRSColors.primary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: MRSColors.accent,
        linearTrackColor: MRSColors.blueSoft,
      ),
    );
  }
}

class MRPageIntro extends StatelessWidget {
  const MRPageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: MRSColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: MRSColors.muted,
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: MRSColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: trailing!,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 32,
              height: 1.12,
              letterSpacing: -1.3,
            ),
          ),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              subtitle,
              style: const TextStyle(
                color: MRSColors.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MRSectionCard extends StatelessWidget {
  const MRSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin ?? EdgeInsets.zero,
    child: Material(
      color: MRSColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MRSColors.border),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class MRIconBox extends StatelessWidget {
  const MRIconBox({
    super.key,
    required this.icon,
    this.color = MRSColors.accent,
    this.background = MRSColors.blueSoft,
    this.size = 46,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * .48),
    );
  }
}
