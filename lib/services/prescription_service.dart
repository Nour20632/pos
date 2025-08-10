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
  
  
}