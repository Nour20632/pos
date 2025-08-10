import 'package:flutter/foundation.dart';
import 'package:mk_optique/database.dart';

class ReportService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  bool _isLoading = false;
  Map<String, dynamic>? _cachedDashboardStats;
  DateTime? _lastStatsUpdate;

  ReportService(this._databaseHelper);

  // Getters
  bool get isLoading => _isLoading;

  Future<Map<String, dynamic>> getDashboardStats({
    bool forceRefresh = false,
  }) async {
    // Cache pour 5 minutes
    if (!forceRefresh &&
        _cachedDashboardStats != null &&
        _lastStatsUpdate != null &&
        DateTime.now().difference(_lastStatsUpdate!).inMinutes < 5) {
      return _cachedDashboardStats!;
    }

    _isLoading = true;
    // notifyListeners(); // <-- REMOVE or COMMENT OUT this line

    try {
      final stats = await _databaseHelper.getDashboardStats();
      _cachedDashboardStats = stats;
      _lastStatsUpdate = DateTime.now();
      debugPrint('Statistiques dashboard mises à jour');
      return stats;
    } catch (e) {
      debugPrint('Erreur stats dashboard: $e');
      return {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String groupBy = 'day',
    bool useCache = true,
  }) async {
    try {
      final report = await _databaseHelper.getSalesReport(
        startDate: startDate,
        endDate: endDate,
        groupBy: groupBy,
      );
      debugPrint('Rapport des ventes généré: ${report.length} entrées');
      return report;
    } catch (e) {
      debugPrint('Erreur rapport des ventes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProductSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    int? categoryId,
  }) async {
    try {
      final report = await _databaseHelper.getProductSalesReport(
        startDate: startDate,
        endDate: endDate,
        categoryId: categoryId,
      );
      debugPrint(
        'Rapport des ventes produits généré: ${report.length} produits',
      );
      return report;
    } catch (e) {
      debugPrint('Erreur rapport ventes produits: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getStockReport() async {
    try {
      final report = await _databaseHelper.getStockReport();
      debugPrint('Rapport de stock généré: ${report.length} produits');
      return report;
    } catch (e) {
      debugPrint('Erreur rapport de stock: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getFinancialSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final summary = await _databaseHelper.getFinancialSummary(
        startDate: startDate,
        endDate: endDate,
      );
      debugPrint(
        'Résumé financier généré pour ${startDate.toString().substring(0, 10)} - ${endDate.toString().substring(0, 10)}',
      );
      return summary;
    } catch (e) {
      debugPrint('Erreur résumé financier: $e');
      return {};
    }
  }

  Future<String> exportSalesReportToCsv({
    required DateTime startDate,
    required DateTime endDate,
    String groupBy = 'day',
  }) async {
    try {
      final data = await getSalesReport(
        startDate: startDate,
        endDate: endDate,
        groupBy: groupBy,
        useCache: false,
      );

      List<String> csvLines = [
        'Période,Nombre de Transactions,Ventes Totales,Vente Moyenne,Ventes Payées,Montant En Attente',
      ];

      for (final row in data) {
        csvLines.add(
          [
            row['period'] ?? '',
            row['transaction_count']?.toString() ?? '0',
            (row['total_sales'] as num?)?.toStringAsFixed(2) ?? '0.00',
            (row['average_sale'] as num?)?.toStringAsFixed(2) ?? '0.00',
            (row['paid_sales'] as num?)?.toStringAsFixed(2) ?? '0.00',
            (row['pending_amount'] as num?)?.toStringAsFixed(2) ?? '0.00',
          ].join(','),
        );
      }

      final csvContent = csvLines.join('\n');
      debugPrint('Export CSV généré: ${csvLines.length - 1} lignes de données');
      return csvContent;
    } catch (e) {
      debugPrint('Erreur export CSV: $e');
      return '';
    }
  }

  Future<String> exportStockReportToCsv() async {
    try {
      final data = await getStockReport();

      List<String> csvLines = [
        'Nom,Marque,Code-barres,Quantité,Seuil Min,Prix Vente,Prix Coût,Catégorie,Valeur Stock,Statut',
      ];

      for (final row in data) {
        csvLines.add(
          [
            _escapeCsvValue(row['name']?.toString() ?? ''),
            _escapeCsvValue(row['brand']?.toString() ?? ''),
            _escapeCsvValue(row['barcode']?.toString() ?? ''),
            row['quantity']?.toString() ?? '0',
            row['min_stock_alert']?.toString() ?? '0',
            (row['sell_price'] as num?)?.toStringAsFixed(2) ?? '0.00',
            (row['cost_price'] as num?)?.toStringAsFixed(2) ?? '0.00',
            _escapeCsvValue(row['category_name']?.toString() ?? ''),
            (row['stock_value'] as num?)?.toStringAsFixed(2) ?? '0.00',
            _escapeCsvValue(row['stock_status']?.toString() ?? ''),
          ].join(','),
        );
      }

      final csvContent = csvLines.join('\n');
      debugPrint(
        'Export CSV stock généré: ${csvLines.length - 1} lignes de données',
      );
      return csvContent;
    } catch (e) {
      debugPrint('Erreur export CSV stock: $e');
      return '';
    }
  }

  String _escapeCsvValue(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<Map<String, dynamic>> getCustomAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final salesReport = await getSalesReport(
        startDate: startDate,
        endDate: endDate,
      );
      final productSales = await getProductSalesReport(
        startDate: startDate,
        endDate: endDate,
      );
      final financialSummary = await getFinancialSummary(
        startDate: startDate,
        endDate: endDate,
      );

      // Calculer des métriques personnalisées
      final totalDays = endDate.difference(startDate).inDays + 1;
      final totalSales = financialSummary['totalRevenue'] as num? ?? 0;
      final averageDailySales = totalDays > 0 ? totalSales / totalDays : 0;

      // Top 5 des produits les plus vendus
      final topProducts = productSales.take(5).toList();

      // Tendance des ventes (croissance/décroissance)
      double salesTrend = 0;
      if (salesReport.length >= 2) {
        final firstPeriod = salesReport.first['total_sales'] as num? ?? 0;
        final lastPeriod = salesReport.last['total_sales'] as num? ?? 0;
        if (firstPeriod > 0) {
          salesTrend = ((lastPeriod - firstPeriod) / firstPeriod * 100);
        }
      }

      return {
        'totalDays': totalDays,
        'averageDailySales': averageDailySales,
        'topProducts': topProducts,
        'salesTrend': salesTrend,
        'totalTransactions': salesReport.fold(
          0,
          (sum, row) => sum + (row['transaction_count'] as int? ?? 0),
        ),
        'averageTransactionValue': totalDays > 0 && salesReport.isNotEmpty
            ? totalSales /
                  salesReport.fold(
                    0,
                    (sum, row) => sum + (row['transaction_count'] as int? ?? 0),
                  )
            : 0,
      };
    } catch (e) {
      debugPrint('Erreur analytics personnalisés: $e');
      return {};
    }
  }

  void clearCache() {
    _cachedDashboardStats = null;
    _lastStatsUpdate = null;
    debugPrint('Cache des rapports effacé');
  }
}

// ==================== SERVICE DE SAUVEGARDE ET DONNÉES ====================
