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
          color: MRSColors.muted,
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
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1638), Color(0xFF183577)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2411245C),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -54,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .045),
                border: Border.all(color: Colors.white.withValues(alpha: .075)),
              ),
            ),
          ),
          Positioned(
            right: 38,
            bottom: -72,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MRSColors.teal.withValues(alpha: .11),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 3,
                      decoration: BoxDecoration(
                        color: MRSColors.teal,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        eyebrow.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .70),
                          fontSize: 10,
                          letterSpacing: 1.75,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 30,
                    height: 1.04,
                    letterSpacing: -1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: MRSColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MRSColors.border),
        boxShadow: const [
          BoxShadow(
            color: MRSColors.shadow,
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
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
