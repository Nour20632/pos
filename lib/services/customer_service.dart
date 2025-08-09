import 'package:flutter/foundation.dart';
import '../database.dart';
import '../models.dart' as models;

/// Service de gestion des clients
class CustomerService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  List<models.Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  CustomerService(this._databaseHelper) {
    loadCustomers();
  }

  // Getters
  List<models.Customer> get customers => _filteredCustomers();
  List<models.Customer> get allCustomers => _customers;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  List<models.Customer> _filteredCustomers() {
    if (_searchQuery.isEmpty) return _customers;

    return _customers.where((customer) {
      return customer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (customer.phone?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          (customer.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
    }).toList();
  }

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _customers = await _databaseHelper.getAllCustomers();
      debugPrint('${_customers.length} clients chargés');
    } catch (e) {
      debugPrint('Erreur chargement clients: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  Future<List<models.Customer>> searchCustomers(String query) async {
    if (query.isEmpty) return _customers;
    return await _databaseHelper.searchCustomers(query);
  }

  Future<models.Customer?> getCustomerById(int id) async {
    return await _databaseHelper.getCustomerById(id);
  }

  Future<models.Customer?> getCustomerByPhone(String phone) async {
    try {
      final results = await _databaseHelper.searchCustomers(phone);
      return results.where((c) => c.phone == phone).firstOrNull;
    } catch (e) {
      debugPrint('Erreur recherche client par téléphone: $e');
      return null;
    }
  }

  Future<bool> addCustomer(models.Customer customer) async {
    try {
      final id = await _databaseHelper.insertCustomer(customer);
      await loadCustomers();
      debugPrint('Client ajouté: ${customer.name} (ID: $id)');
      return true;
    } catch (e) {
      debugPrint('Erreur ajout client: $e');
      return false;
    }
  }

  Future<bool> updateCustomer(models.Customer customer) async {
    try {
      await _databaseHelper.updateCustomer(customer);
      await loadCustomers();
      debugPrint('Client mis à jour: ${customer.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour client: $e');
      return false;
    }
  }

  Future<bool> deleteCustomer(int customerId) async {
    try {
      await _databaseHelper.deleteCustomer(customerId);
      await loadCustomers();
      debugPrint('Client supprimé: ID $customerId');
      return true;
    } catch (e) {
      debugPrint('Erreur suppression client: $e');
      return false;
    }
  }

  List<models.Customer> getRecentCustomers({int limit = 10}) {
    final sorted = List<models.Customer>.from(_customers)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  List<models.Customer> getCustomersByGender(models.Gender gender) {
    return _customers.where((c) => c.gender == gender).toList();
  }

  Map<String, dynamic> getCustomerStats() {
    final totalCustomers = _customers.length;
    final maleCustomers = _customers
        .where((c) => c.gender == models.Gender.homme)
        .length;
    final femaleCustomers = _customers
        .where((c) => c.gender == models.Gender.femme)
        .length;
    final customersWithPhone = _customers
        .where((c) => c.phone != null && c.phone!.isNotEmpty)
        .length;
    final customersWithEmail = _customers
        .where((c) => c.email != null && c.email!.isNotEmpty)
        .length;

    return {
      'totalCustomers': totalCustomers,
      'maleCustomers': maleCustomers,
      'femaleCustomers': femaleCustomers,
      'customersWithPhone': customersWithPhone,
      'customersWithEmail': customersWithEmail,
      'phonePercentage': totalCustomers > 0
          ? (customersWithPhone / totalCustomers * 100).round()
          : 0,
      'emailPercentage': totalCustomers > 0
          ? (customersWithEmail / totalCustomers * 100).round()
          : 0,
    };
  }
}