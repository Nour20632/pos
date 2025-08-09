import 'package:flutter/foundation.dart';
import '../database.dart';
import '../models.dart' as models;

/// Service de gestion des prescriptions optiques
class PrescriptionService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;

  PrescriptionService(this._databaseHelper);

  Future<bool> addPrescription(models.Prescription prescription) async {
    try {
      final id = await _databaseHelper.insertPrescription(prescription);
      debugPrint('Prescription ajoutée: ID $id');
      return true;
    } catch (e) {
      debugPrint('Erreur ajout prescription: $e');
      return false;
    }
  }

  Future<List<models.Prescription>> getCustomerPrescriptions(
    int customerId,
  ) async {
    return await _databaseHelper.getCustomerPrescriptions(customerId);
  }

  Future<bool> updatePrescription(models.Prescription prescription) async {
    try {
      await _databaseHelper.updatePrescription(prescription);
      debugPrint('Prescription mise à jour: ID ${prescription.id}');
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour prescription: $e');
      return false;
    }
  }

  /// Calcule l'équivalent sphérique
  double calculateSphericalEquivalent(double? sphere, double? cylinder) {
    if (sphere == null) return 0;
    return sphere + ((cylinder ?? 0) / 2);
  }

  /// Génère un résumé textuel de la prescription
  String getPrescriptionSummary(models.Prescription prescription) {
    final odSummary = _getEyeSummary(
      'OD',
      prescription.odSphere,
      prescription.odCylinder,
      prescription.odAxis,
      prescription.odAdd,
    );
    final osSummary = _getEyeSummary(
      'OS',
      prescription.osSphere,
      prescription.osCylinder,
      prescription.osAxis,
      prescription.osAdd,
    );
    return '$odSummary\n$osSummary';
  }

  String _getEyeSummary(
    String eye,
    double? sphere,
    double? cylinder,
    int? axis,
    double? add,
  ) {
    List<String> parts = [eye];

    if (sphere != null) {
      parts.add('Sph: ${sphere.toStringAsFixed(2)}');
    }
    if (cylinder != null && cylinder != 0) {
      parts.add('Cyl: ${cylinder.toStringAsFixed(2)}');
    }
    if (axis != null && cylinder != null && cylinder != 0) {
      parts.add('Axe: $axis°');
    }
    if (add != null && add != 0) {
      parts.add('Add: ${add.toStringAsFixed(2)}');
    }

    return parts.join(' ');
  }

  /// Détermine si c'est un verre progressif
  bool isProgressiveLens(models.Prescription prescription) {
    return (prescription.odAdd != null && prescription.odAdd! > 0) ||
        (prescription.osAdd != null && prescription.osAdd! > 0);
  }

  /// Recommande le type de verre basé sur la prescription
  String getRecommendedLensType(models.Prescription prescription) {
    final odSe = calculateSphericalEquivalent(
      prescription.odSphere,
      prescription.odCylinder,
    );
    final osSe = calculateSphericalEquivalent(
      prescription.osSphere,
      prescription.osCylinder,
    );
    final maxSe = [odSe.abs(), osSe.abs()].reduce((a, b) => a > b ? a : b);

    if (isProgressiveLens(prescription)) {
      return 'Verre progressif';
    } else if (maxSe > 6.0) {
      return 'Verre haut indice (1.67 ou 1.74)';
    } else if (maxSe > 3.0) {
      return 'Verre aminci (1.60)';
    } else {
      return 'Verre standard (1.50)';
    }
  }

  /// Valide une prescription pour s'assurer qu'elle est cohérente
  List<String> validatePrescription(models.Prescription prescription) {
    List<String> errors = [];

    // Validation des valeurs sphériques
    if (prescription.odSphere != null) {
      if (prescription.odSphere!.abs() > 25.0) {
        errors.add('Valeur sphérique OD trop élevée');
      }
    }
    if (prescription.osSphere != null) {
      if (prescription.osSphere!.abs() > 25.0) {
        errors.add('Valeur sphérique OS trop élevée');
      }
    }

    // Validation des cylindres
    if (prescription.odCylinder != null) {
      if (prescription.odCylinder!.abs() > 8.0) {
        errors.add('Valeur cylindrique OD trop élevée');
      }
      if (prescription.odCylinder != 0 && prescription.odAxis == null) {
        errors.add('Axe manquant pour le cylindre OD');
      }
    }
    if (prescription.osCylinder != null) {
      if (prescription.osCylinder!.abs() > 8.0) {
        errors.add('Valeur cylindrique OS trop élevée');
      }
      if (prescription.osCylinder != 0 && prescription.osAxis == null) {
        errors.add('Axe manquant pour le cylindre OS');
      }
    }

    // Validation des axes
    if (prescription.odAxis != null) {
      if (prescription.odAxis! < 0 || prescription.odAxis! > 180) {
        errors.add('Axe OD doit être entre 0 et 180°');
      }
    }
    if (prescription.osAxis != null) {
      if (prescription.osAxis! < 0 || prescription.osAxis! > 180) {
        errors.add('Axe OS doit être entre 0 et 180°');
      }
    }

    // Validation des additions
    if (prescription.odAdd != null) {
      if (prescription.odAdd! < 0 || prescription.odAdd! > 4.0) {
        errors.add('Addition OD doit être entre 0 et 4.00');
      }
    }
    if (prescription.osAdd != null) {
      if (prescription.osAdd! < 0 || prescription.osAdd! > 4.0) {
        errors.add('Addition OS doit être entre 0 et 4.00');
      }
    }

    // Validation des distances pupillaires
    if (prescription.pdTotal != null) {
      if (prescription.pdTotal! < 50 || prescription.pdTotal! > 80) {
        errors.add('Distance pupillaire totale inhabituelle');
      }
    }

    return errors;
  }

  /// Calcule le prix estimé basé sur le type de verre recommandé
  double estimateLensPrice(models.Prescription prescription) {
    final lensType = getRecommendedLensType(prescription);
    
    // Tarifs approximatifs en DA
    switch (lensType) {
      case 'Verre progressif':
        return 15000.0;
      case 'Verre haut indice (1.67 ou 1.74)':
        return 8000.0;
      case 'Verre aminci (1.60)':
        return 5000.0;
      default:
        return 3000.0; // Verre standard
    }
  }
}