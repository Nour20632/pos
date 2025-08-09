import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database.dart';
import '../models.dart' as models;

/// Service d'authentification et de gestion des sessions utilisateurs
class AuthService extends ChangeNotifier {
  models.User? _currentUser;
  final DatabaseHelper _databaseHelper;
  bool _isAuthenticated = false;
  Timer? _sessionTimer;

  AuthService(this._databaseHelper) {
    _initializeSessionManagement();
  }

  // Getters
  models.User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isProprietaire => _currentUser?.role == models.UserRole.proprietaire;
  bool get isEmploye => _currentUser?.role == models.UserRole.employe;
  String? get userId => currentUser?.id?.toString();

  void _initializeSessionManagement() {
    // Vérifier la session au démarrage
    checkAuthenticationStatus();

    // Timer pour rafraîchir la session toutes les 30 minutes
    _sessionTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _refreshSession();
    });
  }

  Future<bool> login(String username, String password) async {
    try {
      final user = await _databaseHelper.authenticateUser(username, password);
      if (user != null && user.isActive) {
        _currentUser = user;
        _isAuthenticated = true;

        // Sauvegarder la session
        await _saveSession(user);

        debugPrint('Connexion réussie pour ${user.fullName}');
        notifyListeners();
        return true;
      }
      debugPrint('Échec de connexion: utilisateur non trouvé ou inactif');
    } catch (e) {
      debugPrint('Erreur de connexion: $e');
    }
    return false;
  }

  Future<void> logout() async {
    debugPrint('Déconnexion de ${_currentUser?.fullName}');

    _currentUser = null;
    _isAuthenticated = false;

    // Nettoyer la session
    await _clearSession();

    notifyListeners();
  }

  Future<void> checkAuthenticationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('is_authenticated') ?? false;
      final userId = prefs.getInt('current_user_id');
      final lastActivity = prefs.getInt('last_activity');

      if (isAuth && userId != null && lastActivity != null) {
        // Vérifier si la session n'a pas expiré (24 heures)
        final now = DateTime.now().millisecondsSinceEpoch;
        const sessionDuration = 24 * 60 * 60 * 1000; // 24 heures en ms

        if (now - lastActivity > sessionDuration) {
          debugPrint('Session expirée');
          await logout();
          return;
        }

        final users = await _databaseHelper.getAllUsers();
        final user = users
            .where((u) => u.id == userId && u.isActive)
            .firstOrNull;

        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          await _updateLastActivity();
          notifyListeners();
          debugPrint('Session restaurée pour ${user.fullName}');
        } else {
          debugPrint('Utilisateur non trouvé ou inactif');
          await logout();
        }
      }
    } catch (e) {
      debugPrint('Erreur vérification authentification: $e');
      await logout();
    }
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return false;

    try {
      // Vérifier l'ancien mot de passe
      final user = await _databaseHelper.authenticateUser(
        _currentUser!.username,
        oldPassword,
      );
      if (user == null) return false;

      // Mettre à jour avec le nouveau mot de passe
      final updatedUser = _currentUser!.copyWith(password: newPassword);
      await _databaseHelper.updateUser(updatedUser);

      _currentUser = updatedUser;
      notifyListeners();
      debugPrint('Mot de passe changé avec succès');
      return true;
    } catch (e) {
      debugPrint('Erreur changement mot de passe: $e');
      return false;
    }
  }

  Future<void> _saveSession(models.User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', user.id!);
    await prefs.setBool('is_authenticated', true);
    await prefs.setInt('last_activity', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.remove('is_authenticated');
    await prefs.remove('last_activity');
  }

  Future<void> _updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_activity', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _refreshSession() async {
    if (_isAuthenticated) {
      await _updateLastActivity();
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}
