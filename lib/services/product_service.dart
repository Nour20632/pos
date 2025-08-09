import 'package:flutter/foundation.dart';
import '../database.dart';
import '../models.dart' as models;

/// Service de gestion des produits et catégories
class ProductService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  List<models.Product> _products = [];
  List<models.Category> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int? _selectedCategoryId;

  ProductService(this._databaseHelper) {
    _initialize();
  }

  // Getters
  List<models.Product> get products => _filteredProducts();
  List<models.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;

  Future<void> _initialize() async {
    await loadCategories();
    await loadProducts();
  }

  List<models.Product> _filteredProducts() {
    List<models.Product> filtered = List.from(_products);

    // Filtrer par catégorie
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((p) => p.categoryId == _selectedCategoryId)
          .toList();
    }

    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false) ||
            (p.brand?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false) ||
            (p.model?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    return filtered;
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _databaseHelper.getAllProducts();
      debugPrint('${_products.length} produits chargés');
    } catch (e) {
      debugPrint('Erreur chargement produits: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    try {
      _categories = await _databaseHelper.getAllCategories();
      debugPrint('${_categories.length} catégories chargées');
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur chargement catégories: $e');
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(int? categoryId) {
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    notifyListeners();
  }

  Future<List<models.Product>> searchProducts(String query) async {
    if (query.isEmpty) return _products;
    return await _databaseHelper.searchProducts(query);
  }

  Future<models.Product?> getProductByBarcode(String barcode) async {
    return await _databaseHelper.getProductByBarcode(barcode);
  }

  Future<models.Product?> getProductById(int id) async {
    return await _databaseHelper.getProductById(id);
  }

  Future<bool> addProduct(models.Product product) async {
    try {
      await _databaseHelper.insertProduct(product);
      await loadProducts();
      debugPrint('Produit ajouté: ${product.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur ajout produit: $e');
      return false;
    }
  }

  Future<bool> updateProduct(models.Product product) async {
    try {
      await _databaseHelper.updateProduct(product);
      await loadProducts();
      debugPrint('Produit mis à jour: ${product.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour produit: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(int productId) async {
    try {
      await _databaseHelper.deleteProduct(productId);
      await loadProducts();
      debugPrint('Produit supprimé: ID $productId');
      return true;
    } catch (e) {
      debugPrint('Erreur suppression produit: $e');
      return false;
    }
  }

  Future<bool> addCategory(models.Category category) async {
    try {
      await _databaseHelper.insertCategory(category);
      await loadCategories();
      debugPrint('Catégorie ajoutée: ${category.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur ajout catégorie: $e');
      return false;
    }
  }

  Future<bool> updateCategory(models.Category category) async {
    try {
      await _databaseHelper.updateCategory(category);
      await loadCategories();
      debugPrint('Catégorie mise à jour: ${category.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur mise à jour catégorie: $e');
      return false;
    }
  }

  Future<String> generateBarcode() async {
    return await _databaseHelper.generateProductBarcode();
  }

  List<models.Product> getLowStockProducts() {
    return _products.where((p) => p.isLowStock).toList();
  }

  List<models.Product> getProductsByCategory(int categoryId) {
    return _products.where((p) => p.categoryId == categoryId).toList();
  }

  List<models.Product> getTopSellingProducts({int limit = 10}) {
    // Trier par quantité vendue (approximation basée sur le stock bas)
    final sorted = List<models.Product>.from(_products)
      ..sort(
        (a, b) => (a.minStockAlert - a.quantity).compareTo(
          b.minStockAlert - b.quantity,
        ),
      );
    return sorted.take(limit).toList();
  }

  double getTotalInventoryValue() {
    return _products.fold(
      0,
      (sum, product) => sum + (product.quantity * (product.costPrice ?? 0)),
    );
  }

  int getTotalProductCount() {
    return _products.fold(0, (sum, product) => sum + product.quantity);
  }

  Map<String, dynamic> getInventoryStats() {
    final totalProducts = _products.length;
    final activeProducts = _products.where((p) => p.quantity > 0).length;
    final lowStockProducts = getLowStockProducts();
    final outOfStockProducts = _products.where((p) => p.quantity == 0).length;

    return {
      'totalProducts': totalProducts,
      'activeProducts': activeProducts,
      'lowStockCount': lowStockProducts.length,
      'outOfStockCount': outOfStockProducts,
      'totalValue': getTotalInventoryValue(),
      'totalQuantity': getTotalProductCount(),
    };
  }
}