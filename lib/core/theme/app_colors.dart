import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand colors - Ocean theme
  static const Color primary = Color(0xFF0077B6);
  static const Color primaryLight = Color(0xFF00B4D8);
  static const Color primaryDark = Color(0xFF03045E);

  // Secondary accent colors
  static const Color secondary = Color(0xFF00C896);
  static const Color secondaryLight = Color(0xFF48CAE4);

  // Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Dive-specific colors
  static const Color depthBlue = Color(0xFF0077B6);
  static const Color temperatureCold = Color(0xFF60A5FA);
  static const Color temperatureWarm = Color(0xFFFBBF24);
  static const Color nitrox = Color(0xFF22C55E);
  static const Color trimix = Color(0xFFA855F7);
  static const Color air = Color(0xFF6B7280);

  // Chart colors
  static const Color chartDepth = Color(0xFF0077B6);
  static const Color chartTemperature = Color(0xFFF59E0B);
  static const Color chartPressure = Color(0xFF22C55E);
  static const Color chartHeartRate = Color(0xFFEF4444);

  // Surface/background
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF1E293B);
}
