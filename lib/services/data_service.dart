import 'package:flutter/foundation.dart';
import 'package:mk_optique/database.dart';

class DataService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String _lastError = '';

  DataService(this._databaseHelper);

  // Getters
  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  String get lastError => _lastError;

  Future<String?> exportDatabase() async {
    try {
      _isBackingUp = true;
      _lastError = '';
      notifyListeners();

      final jsonData = await _databaseHelper.exportDatabaseToJson();

      _isBackingUp = false;
      notifyListeners();

      debugPrint('Base de données exportée avec succès');
      return jsonData;
    } catch (e) {
      _lastError = 'Erreur export base de données: $e';
      _isBackingUp = false;
      debugPrint(_lastError);
      notifyListeners();
      return null;
    }
  }

  Future<bool> importDatabase(String jsonData) async {
    try {
      _isRestoring = true;
      _lastError = '';
      notifyListeners();

      final success = await _databaseHelper.importDatabaseFromJson(jsonData);

      _isRestoring = false;
      notifyListeners();

      if (success) {
        debugPrint('Base de données importée avec succès');
      } else {
        _lastError = 'Échec de l\'importation';
      }

      return success;
    } catch (e) {
      _lastError = 'Erreur import base de données: $e';
      _isRestoring = false;
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  Future<bool> validateData() async {
    try {
      final errors = await _databaseHelper.validateData();

      if (errors.isNotEmpty) {
        _lastError = 'Erreurs de validation: ${errors.join(', ')}';
        debugPrint(_lastError);
        return false;
      }

      debugPrint('Validation des données réussie');
      return true;
    } catch (e) {
      _lastError = 'Erreur validation données: $e';
      debugPrint(_lastError);
      return false;
    }
  }

  Future<void> performMaintenance() async {
    try {
      await _databaseHelper.performMaintenance();
      debugPrint('Maintenance de la base de données effectuée');
    } catch (e) {
      _lastError = 'Erreur maintenance: $e';
      debugPrint(_lastError);
    }
  }

  Future<Map<String, int>> getTableCounts() async {
    try {
      return await _databaseHelper.getTableCounts();
    } catch (e) {
      debugPrint('Erreur comptage tables: $e');
      return {};
    }
  }

  Future<bool> isDatabaseEmpty() async {
    try {
      return await _databaseHelper.isDatabaseEmpty();
    } catch (e) {
      debugPrint('Erreur vérification base vide: $e');
      return false;
    }
  }

  void clearErrors() {
    _lastError = '';
    notifyListeners();
  }
}
