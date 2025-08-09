import 'package:flutter/foundation.dart';
import 'package:mk_optique/services/data_service.dart';
import 'package:mk_optique/services/prescription_service.dart';
import 'package:mk_optique/services/printer_service.dart';
import 'package:mk_optique/services/report_service.dart';
import 'package:mk_optique/services/stock_service.dart';
import '../database.dart';

// Import all services
import 'auth_service.dart';
import 'scanner_service.dart';
import 'product_service.dart';
import 'customer_service.dart';
import 'invoice_service.dart';

class MKOptiqueServiceManager extends ChangeNotifier {
  // Services principaux
  late final AuthService authService;
  late final UsbPrinterService usbPrinterService;
  late final ScannerService scannerService;
  late final ProductService productService;
  late final StockService stockService;
  late final CustomerService customerService;
  late final InvoiceService invoiceService;
  late final PrescriptionService prescriptionService;
  late final ReportService reportService;
  late final DataService dataService;

  final DatabaseHelper _databaseHelper;
  bool _isInitialized = false;

  MKOptiqueServiceManager(this._databaseHelper) {
    _initializeServices();
  }

  bool get isInitialized => _isInitialized;

  void _initializeServices() {
    try {
      // Initialisation de tous les services
      authService = AuthService(_databaseHelper);
      usbPrinterService = UsbPrinterService();
      scannerService = ScannerService();
      productService = ProductService(_databaseHelper);
      stockService = StockService(_databaseHelper);
      customerService = CustomerService(_databaseHelper);
      invoiceService = InvoiceService(_databaseHelper);
      prescriptionService = PrescriptionService(_databaseHelper);
      reportService = ReportService(_databaseHelper);
      dataService = DataService(_databaseHelper);

      _isInitialized = true;
      debugPrint('Gestionnaire de services MK Optique initialisé avec succès');
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur initialisation services: $e');
      _isInitialized = false;
    }
  }

  Future<bool> initializeAll() async {
    try {
      // Initialiser la base de données
      await _databaseHelper.initDatabase();

      // Initialiser les services qui ont besoin d'une initialisation asynchrone
      await authService.checkAuthenticationStatus();
      await scannerService.initialize();

      debugPrint('Tous les services initialisés avec succès');
      return true;
    } catch (e) {
      debugPrint('Erreur initialisation globale: $e');
      return false;
    }
  }

  Future<void> performStartupTasks() async {
    try {
      // Vérifier et nettoyer les données si nécessaire
      await dataService.validateData();

      // Maintenance légère au démarrage
      await dataService.performMaintenance();

      // Charger les données essentielles
      await Future.wait([
        productService.loadProducts(),
        customerService.loadCustomers(),
        invoiceService.loadInvoices(),
      ]);

      debugPrint('Tâches de démarrage terminées');
    } catch (e) {
      debugPrint('Erreur tâches de démarrage: $e');
    }
  }

  Map<String, dynamic> getSystemStatus() {
    return {
      'isInitialized': _isInitialized,
      'authService': {
        'isAuthenticated': authService.isAuthenticated,
        'currentUser': authService.currentUser?.fullName,
        'userRole': authService.currentUser?.role.name,
      },
      'usbPrinter': usbPrinterService.getPrinterStatus(),
      'scanner': {
        'isScanning': scannerService.isScanning,
        'lastScannedCode': scannerService.lastScannedCode,
      },
      'database': {
        'isBackingUp': dataService.isBackingUp,
        'isRestoring': dataService.isRestoring,
      },
      'services': {
        'products': {
          'isLoading': productService.isLoading,
          'totalProducts': productService.products.length,
        },
        'customers': {
          'isLoading': customerService.isLoading,
          'totalCustomers': customerService.customers.length,
        },
        'invoices': {
          'isLoading': invoiceService.isLoading,
          'totalInvoices': invoiceService.invoices.length,
        },
      },
    };
  }

  @override
  void dispose() {
    // Disposer tous les services
    authService.dispose();
    usbPrinterService.dispose();
    scannerService.dispose();
    productService.dispose();
    stockService.dispose();
    customerService.dispose();
    invoiceService.dispose();
    prescriptionService.dispose();
    reportService.dispose();
    dataService.dispose();

    super.dispose();
  }
}
