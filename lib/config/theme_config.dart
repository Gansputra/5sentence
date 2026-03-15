import 'package:flutter/material.dart';
import 'dart:ui';

class AppTheme {
  final String name;
  final Color seedColor;
  final Brightness brightness;

  AppTheme({
    required this.name,
    required this.seedColor,
    this.brightness = Brightness.light,
  });

  static List<AppTheme> themes = [
    AppTheme(name: 'Teal', seedColor: Colors.teal),
    AppTheme(name: 'Midnight', seedColor: const Color(0xFF1A237E), brightness: Brightness.dark),
    AppTheme(name: 'Sakura', seedColor: const Color(0xFFF48FB1)),
    AppTheme(name: 'Ocean', seedColor: const Color(0xFF0288D1)),
    AppTheme(name: 'Lavender', seedColor: const Color(0xFF9575CD)),
  ];

  static ThemeData getThemeData(AppTheme theme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.seedColor,
        brightness: theme.brightness,
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Color? color;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.borderRadius,
    this.color,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? theme.colorScheme.surface).withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: border ?? Border.all(
              color: (color ?? theme.colorScheme.outlineVariant).withOpacity(0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
