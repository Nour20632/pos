import 'package:flutter/material.dart';

// ==================== COULEURS ====================
class AppColors {
  // Palette principale MK
  static const Color primary = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF42A5F5);

  static const Color secondary = Color(0xFF26A69A);
  static const Color secondaryDark = Color(0xFF00695C);
  static const Color secondaryLight = Color(0xFF4DB6AC);

  // Couleurs fonctionnelles
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Couleurs neutres
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF121212);
  static const Color onSurface = Color(0xFF212121);
  static const Color onSurfaceDark = Colors.white;

  // Couleurs texte
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textLight = Colors.white;

  // Couleurs bordures
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderFocus = Color(0xFF1E88E5);

  // Couleurs statut
  static const Color statusPaid = Color(0xFF4CAF50);
  static const Color statusUnpaid = Color(0xFFF44336);
  static const Color statusPartial = Color(0xFFFF9800);
  static const Color statusCancelled = Color(0xFF9E9E9E);

  // Couleurs stock
  static const Color stockNormal = Color(0xFF4CAF50);
  static const Color stockLow = Color(0xFFFF9800);
  static const Color stockOut = Color(0xFFF44336);

  // Couleurs ajoutées
  static const Color primaryColor = Colors.indigo;
  static const Color secondaryColor = Colors.blue;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color infoColor = Colors.lightBlue;
  static const Color textPrimaryColor = Colors.black87;
  static const Color textSecondaryColor = Colors.black54;
  static const Color backgroundColor = Colors.white;
  static const Color surfaceColor = Colors.white;
  static const Color statusCancelledColor = Colors.grey;
}

// ==================== DIMENSIONS ====================
class AppDimensions {
  // Marges et espacements
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
}
