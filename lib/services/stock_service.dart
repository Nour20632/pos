import 'package:flutter/foundation.dart';
import '../database.dart';
import '../models.dart' as models;

/// Service de gestion du stock et des mouvements
class StockService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  List<models.StockMovement> _recentMovements = [];
  bool _isLoading = false;

  StockService(this._databaseHelper) {
    loadRecentMovements();
  }

  // Getters
  List<models.StockMovement> get recentMovements => _recentMovements;
  bool get isLoading => _isLoading;

  Future<void> loadRecentMovements() async {
    _isLoading = true;
    notifyListeners();

    try {
      _recentMovements = await _databaseHelper.getStockMovements(limit: 100);
      debugPrint('${_recentMovements.length} mouvements de stock chargés');
    } catch (e) {
      debugPrint('Erreur chargement mouvements: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addStock(
    models.Product product,
    int quantity,
    double? unitCost,
    String reason,
    int userId, {
    String? referenceNumber,
  }) async {
    if (quantity <= 0) return false;

    try {
      final movement = models.StockMovement(
        productId: product.id!,
        movementType: models.StockMovementType.entree,
        quantity: quantity,
        quantityBefore: product.quantity,
        quantityAfter: product.quantity + quantity,
        unitCost: unitCost,
        totalCost: unitCost != null ? unitCost * quantity : null,
        reason: reason,
        referenceNumber:
            referenceNumber ?? 'ENT-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
      );

      await _databaseHelper.addStockMovement(movement);
      await loadRecentMovements();
      debugPrint('Stock ajouté: +$quantity pour ${product.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur ajout stock: $e');
      return false;
    }
  }

  Future<bool> removeStock(
    models.Product product,
    int quantity,
    String reason,
    int userId, {
    String? referenceNumber,
  }) async {
    if (quantity <= 0 || product.quantity < quantity) return false;

    try {
      final movement = models.StockMovement(
        productId: product.id!,
        movementType: models.StockMovementType.sortie,
        quantity: quantity,
        quantityBefore: product.quantity,
        quantityAfter: product.quantity - quantity,
        reason: reason,
        referenceNumber:
            referenceNumber ?? 'SOR-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
      );

      await _databaseHelper.addStockMovement(movement);
      await loadRecentMovements();
      debugPrint('Stock retiré: -$quantity pour ${product.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur retrait stock: $e');
      return false;
    }
  }

  Future<bool> adjustStock(
    models.Product product,
    int newQuantity,
    String reason,
    int userId, {
    String? referenceNumber,
  }) async {
    if (newQuantity < 0) return false;

    try {
      final difference = newQuantity - product.quantity;
      final movement = models.StockMovement(
        productId: product.id!,
        movementType: models.StockMovementType.ajustement,
        quantity: difference.abs(),
        quantityBefore: product.quantity,
        quantityAfter: newQuantity,
        reason: reason,
        referenceNumber:
            referenceNumber ?? 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
      );

      await _databaseHelper.addStockMovement(movement);
      await loadRecentMovements();
      debugPrint(
        'Stock ajusté: ${product.quantity} → $newQuantity pour ${product.name}',
      );
      return true;
    } catch (e) {
      debugPrint('Erreur ajustement stock: $e');
      return false;
    }
  }

  Future<bool> returnStock(
    models.Product product,
    int quantity,
    String reason,
    int userId, {
    String? referenceNumber,
  }) async {
    if (quantity <= 0) return false;

    try {
      final movement = models.StockMovement(
        productId: product.id!,
        movementType: models.StockMovementType.retour,
        quantity: quantity,
        quantityBefore: product.quantity,
        quantityAfter: product.quantity + quantity,
        reason: reason,
        referenceNumber:
            referenceNumber ?? 'RET-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
      );

      await _databaseHelper.addStockMovement(movement);
      await loadRecentMovements();
      debugPrint('Stock retourné: +$quantity pour ${product.name}');
      return true;
    } catch (e) {
      debugPrint('Erreur retour stock: $e');
      return false;
    }
  }

  Future<List<models.StockMovement>> getProductMovements(int productId) async {
    return await _databaseHelper.getStockMovements(productId: productId);
  }

  Future<List<models.StockMovement>> getMovementsByPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _databaseHelper.getStockMovements(
      startDate: startDate,
      endDate: endDate,
      limit: 1000,
    );
  }

  Future<List<models.StockMovement>> getMovementsByType(
    models.StockMovementType type,
  ) async {
    return _recentMovements.where((m) => m.movementType == type).toList();
  }

  Map<String, dynamic> getStockStats() {
    final totalMovements = _recentMovements.length;
    final entries = _recentMovements
        .where((m) => m.movementType == models.StockMovementType.entree)
        .length;
    final exits = _recentMovements
        .where((m) => m.movementType == models.StockMovementType.sortie)
        .length;
    final adjustments = _recentMovements
        .where((m) => m.movementType == models.StockMovementType.ajustement)
        .length;
    final returns = _recentMovements
        .where((m) => m.movementType == models.StockMovementType.retour)
        .length;

    return {
      'totalMovements': totalMovements,
      'entries': entries,
      'exits': exits,
      'adjustments': adjustments,
      'returns': returns,
    };
  }
}