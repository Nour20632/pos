import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:jiffy/jiffy.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/capability_profile.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/enums.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/generator.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/pos_column.dart';
import 'package:thermal_printer/esc_pos_utils_platform/src/pos_styles.dart';
import 'package:usb_serial/usb_serial.dart';

import 'database.dart';
import 'models.dart' as models;

// ==================== SERVICE D'AUTHENTIFICATION ====================
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

// ==================== SERVICE IMPRESSION BLUETOOTH AMÉLIORÉ ====================
class BluetoothPrinterService extends ChangeNotifier {
  List<BluetoothInfo> _availablePrinters = [];
  BluetoothInfo? _connectedPrinter;
  bool _isConnected = false;
  bool _isPrinting = false;
  String _lastError = '';

  // Getters
  List<BluetoothInfo> get availablePrinters => _availablePrinters;
  BluetoothInfo? get connectedPrinter => _connectedPrinter;
  bool get isConnected => _isConnected;
  bool get isPrinting => _isPrinting;
  String get lastError => _lastError;

  Future<bool> initialize() async {
    try {
      // Vérifier les permissions Bluetooth
      if (Platform.isAndroid) {
        final bluetoothStatus = await Permission.bluetooth.request();
        final locationStatus = await Permission.location.request();

        if (bluetoothStatus != PermissionStatus.granted ||
            locationStatus != PermissionStatus.granted) {
          _lastError = 'Permissions Bluetooth requises';
          return false;
        }
      }

      return true;
    } catch (e) {
      _lastError = 'Erreur initialisation Bluetooth: $e';
      debugPrint(_lastError);
      return false;
    }
  }

  Future<void> searchPrinters() async {
    try {
      _lastError = '';
      debugPrint('Recherche d\'imprimantes Bluetooth...');

      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;

      // Filtrer les imprimantes potentielles
      _availablePrinters = devices.where((device) {
        final name = device.name.toLowerCase();
        return name.contains('printer') ||
            name.contains('thermal') ||
            name.contains('pos') ||
            name.contains('smart') ||
            name.contains('receipt') ||
            name.contains('mk');
      }).toList();

      debugPrint('${_availablePrinters.length} imprimante(s) trouvée(s)');
      notifyListeners();
    } catch (e) {
      _lastError = 'Erreur recherche imprimantes: $e';
      debugPrint(_lastError);
    }
  }

  Future<bool> connectToPrinter(BluetoothInfo printer) async {
    try {
      _lastError = '';
      _isPrinting = true;
      notifyListeners();

      debugPrint('Connexion à ${printer.name}...');

      final bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.macAdress,
      );

      _isConnected = connected;
      _connectedPrinter = connected ? printer : null;
      _isPrinting = false;

      if (connected) {
        debugPrint('Connexion réussie à ${printer.name}');
        await _testConnection();
      } else {
        _lastError = 'Échec de connexion à ${printer.name}';
      }

      notifyListeners();
      return connected;
    } catch (e) {
      _lastError = 'Erreur connexion imprimante: $e';
      _isPrinting = false;
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      _connectedPrinter = null;
      debugPrint('Imprimante déconnectée');
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur déconnexion imprimante: $e');
    }
  }

  Future<bool> _testConnection() async {
    try {
      // Test simple de connexion
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.text(
        'Test de connexion',
        styles: const PosStyles(align: PosAlign.center),
      );

      return await PrintBluetoothThermal.writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      debugPrint('Erreur test connexion: $e');
      return false;
    }
  }

  Future<bool> printInvoice(
    models.Invoice invoice, {
    models.PrintTemplate? template,
  }) async {
    if (!_isConnected) {
      _lastError = 'Aucune imprimante connectée';
      return false;
    }

    try {
      _isPrinting = true;
      _lastError = '';
      notifyListeners();

      final bytes = await _generateInvoiceReceipt(invoice, template);
      final result = await PrintBluetoothThermal.writeBytes(bytes);

      _isPrinting = false;
      notifyListeners();

      if (result) {
        await _playPrintSuccessSound();
        debugPrint('Facture ${invoice.invoiceNumber} imprimée avec succès');
      } else {
        _lastError = 'Échec impression facture';
      }

      return result;
    } catch (e) {
      _lastError = 'Erreur impression facture: $e';
      _isPrinting = false;
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  Future<bool> printProductLabel(
    models.Product product, {
    int quantity = 1,
  }) async {
    if (!_isConnected) {
      _lastError = 'Aucune imprimante connectée';
      return false;
    }

    try {
      _isPrinting = true;
      _lastError = '';
      notifyListeners();

      bool allSuccess = true;
      for (int i = 0; i < quantity; i++) {
        final bytes = await _generateProductLabel(product);
        final result = await PrintBluetoothThermal.writeBytes(bytes);

        if (!result) {
          allSuccess = false;
          break;
        }

        // Pause entre les étiquettes
        if (i < quantity - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      _isPrinting = false;
      notifyListeners();

      if (allSuccess) {
        await _playPrintSuccessSound();
        debugPrint('$quantity étiquette(s) imprimée(s) pour ${product.name}');
      } else {
        _lastError = 'Échec impression étiquettes';
      }

      return allSuccess;
    } catch (e) {
      _lastError = 'Erreur impression étiquettes: $e';
      _isPrinting = false;
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  Future<bool> printPrescription(
    models.Prescription prescription,
    models.Customer customer,
  ) async {
    if (!_isConnected) {
      _lastError = 'Aucune imprimante connectée';
      return false;
    }

    try {
      _isPrinting = true;
      _lastError = '';
      notifyListeners();

      final bytes = await _generatePrescriptionReceipt(prescription, customer);
      final result = await PrintBluetoothThermal.writeBytes(bytes);

      _isPrinting = false;
      notifyListeners();

      if (result) {
        await _playPrintSuccessSound();
        debugPrint('Prescription imprimée pour ${customer.name}');
      } else {
        _lastError = 'Échec impression prescription';
      }

      return result;
    } catch (e) {
      _lastError = 'Erreur impression prescription: $e';
      _isPrinting = false;
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  Future<bool> testPrint() async {
    if (!_isConnected) {
      _lastError = 'Aucune imprimante connectée';
      return false;
    }

    try {
      _isPrinting = true;
      _lastError = '';
      notifyListeners();

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.reset();

      // Test complet
      bytes += generator.text(
        'TEST D\'IMPRESSION',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );

      bytes += generator.text(
        'MK OPTIQUE',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.hr();

      bytes += generator.text(
        'Date: ${DateTime.now().toString().substring(0, 19)}',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.text(
        'Imprimante: ${_connectedPrinter?.name}',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.hr();

      bytes += generator.text(
        '✓ Connexion Bluetooth OK',
        styles: const PosStyles(align: PosAlign.left),
      );

      bytes += generator.text(
        '✓ Impression fonctionnelle',
        styles: const PosStyles(align: PosAlign.left),
      );

      bytes += generator.text(
        '✓ Caractères français: àéèç',
        styles: const PosStyles(align: PosAlign.left),
      );

      bytes += generator.feed(2);
      bytes += generator.cut();

      final result = await PrintBluetoothThermal.writeBytes(
        Uint8List.fromList(bytes),
      );

      _isPrinting = false;
      notifyListeners();

      if (result) {
        await _playPrintSuccessSound();
        debugPrint('Test d\'impression réussi');
      } else {
        _lastError = 'Échec test impression';
      }

      return result;
    } catch (e) {
      _lastError = 'Erreur test impression: $e';
      _isPrinting = false;
      debugPrint(_lastError);
      notifyListeners();
      return false;
    }
  }

  Future<Uint8List> _generateInvoiceReceipt(
    models.Invoice invoice,
    models.PrintTemplate? template,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.reset();

    // En-tête personnalisé ou par défaut
    if (template?.headerText != null) {
      final lines = template!.headerText!.split('\n');
      for (String line in lines) {
        bytes += generator.text(
          line,
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
    } else {
      bytes += generator.text(
        'MK OPTIQUE',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'Rue Didouche Mourad',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'à côté protection Civile el-hadjar',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'MOB: 06.63.90.47.96',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr();

    // Informations facture
    bytes += generator.text(
      'FACTURE N° ${invoice.invoiceNumber}',
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      'Date: ${Jiffy.parseFromDateTime(invoice.createdAt).format(pattern: 'dd/MM/yyyy à HH:mm')}',
    );

    // Informations client
    if (invoice.customerName != null && invoice.customerName!.isNotEmpty) {
      bytes += generator.text('Client: ${invoice.customerName}');
    } else {
      bytes += generator.text('Client: ..............................');
    }

    if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty) {
      bytes += generator.text('Tél: ${invoice.customerPhone}');
    } else {
      bytes += generator.text('Tél: ...................................');
    }

    bytes += generator.hr();

    // Articles si disponibles
    if (invoice.items.isNotEmpty) {
      bytes += generator.text('DÉTAILS:', styles: const PosStyles(bold: true));
      bytes += generator.hr(ch: '-');

      bytes += generator.row([
        PosColumn(text: 'Article', width: 6),
        PosColumn(text: 'Qté', width: 2),
        PosColumn(
          text: 'Prix',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr(ch: '-');

      for (final item in invoice.items) {
        bytes += generator.row([
          PosColumn(text: item.productName, width: 6),
          PosColumn(text: '${item.quantity}', width: 2),
          PosColumn(
            text: '${item.totalPrice.toStringAsFixed(2)} DA',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
      bytes += generator.hr(ch: '-');
    }

    // Totaux
    bytes += generator.row([
      PosColumn(text: 'Sous-total:', width: 8),
      PosColumn(
        text: '${invoice.subtotal.toStringAsFixed(2)} DA',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (invoice.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Remise:', width: 8),
        PosColumn(
          text: '-${invoice.discountAmount.toStringAsFixed(2)} DA',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (invoice.taxAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'TVA (19%):', width: 8),
        PosColumn(
          text: '${invoice.taxAmount.toStringAsFixed(2)} DA',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL:',
        width: 8,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: '${invoice.totalAmount.toStringAsFixed(2)} DA',
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    ]);

    // Informations paiement
    if (invoice.paymentType != models.PaymentType.comptant) {
      bytes += generator.hr();
      bytes += generator.text(
        'Payé: ${invoice.paidAmount.toStringAsFixed(2)} DA',
      );
      bytes += generator.text(
        'Reste: ${invoice.remainingAmount.toStringAsFixed(2)} DA',
      );
    }

    // Champs pour les informations optiques
    bytes += generator.hr();
    bytes += generator.text('Arrhes: .............................');
    bytes += generator.text('Teinte: .............................');

    // Prescription si nécessaire
    if (_isOpticalInvoice(invoice)) {
      bytes += generator.hr();
      bytes += generator.text(
        'PRESCRIPTION:',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text('OD (Vision de loin): ................');
      bytes += generator.text('OG (Vision de loin): ................');
      bytes += generator.text('OD (Vision de près): ................');
      bytes += generator.text('OG (Vision de près): ................');
    }

    bytes += generator.hr();

    // Pied de page
    if (template?.footerText != null) {
      final lines = template!.footerText!.split('\n');
      for (String line in lines) {
        bytes += generator.text(
          line,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
    } else {
      bytes += generator.text(
        'CONDITIONS DE VENTE',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Toute commande confirmée ne pourra',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'être annulée passé le délai de',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        '03 Mois. La maison décline toute',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'responsabilité.',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.feed(3);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> _generateProductLabel(models.Product product) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.reset();

    // Nom du produit
    bytes += generator.text(
      product.name,
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    // Code-barres (simulation textuelle)
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      bytes += generator.text(
        '||||| ${product.barcode!} |||||',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        product.barcode!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    // Prix
    bytes += generator.text(
      'Prix: ${product.sellPrice.toStringAsFixed(2)} DA',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    );

    // Informations supplémentaires
    if (product.brand != null && product.brand!.isNotEmpty) {
      bytes += generator.text(
        'Marque: ${product.brand}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (product.model != null && product.model!.isNotEmpty) {
      bytes += generator.text(
        'Modèle: ${product.model}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (product.color != null && product.color!.isNotEmpty) {
      bytes += generator.text(
        'Couleur: ${product.color}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr();
    bytes += generator.text(
      'MK OPTIQUE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> _generatePrescriptionReceipt(
    models.Prescription prescription,
    models.Customer customer,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.reset();

    // En-tête
    bytes += generator.text(
      'MK OPTIQUE',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'PRESCRIPTION OPTIQUE',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.hr();

    // Informations client
    bytes += generator.text(
      'Client: ${customer.name}',
      styles: const PosStyles(bold: true),
    );
    if (customer.phone != null) {
      bytes += generator.text('Tél: ${customer.phone}');
    }
    bytes += generator.text(
      'Date: ${Jiffy.parseFromDateTime(prescription.createdAt).format(pattern: 'dd/MM/yyyy')}',
    );

    if (prescription.doctorName != null) {
      bytes += generator.text('Prescripteur: ${prescription.doctorName}');
    }

    bytes += generator.hr();

    // Prescription OD (Œil droit)
    bytes += generator.text(
      'OEIL DROIT (OD)',
      styles: const PosStyles(bold: true),
    );
    if (prescription.odSphere != null) {
      bytes += generator.text(
        'Sphère: ${prescription.odSphere!.toStringAsFixed(2)}',
      );
    }
    if (prescription.odCylinder != null) {
      bytes += generator.text(
        'Cylindre: ${prescription.odCylinder!.toStringAsFixed(2)}',
      );
    }
    if (prescription.odAxis != null) {
      bytes += generator.text('Axe: ${prescription.odAxis}°');
    }
    if (prescription.odAdd != null) {
      bytes += generator.text(
        'Addition: ${prescription.odAdd!.toStringAsFixed(2)}',
      );
    }

    bytes += generator.feed(1);

    // Prescription OS (Œil gauche)
    bytes += generator.text(
      'OEIL GAUCHE (OS)',
      styles: const PosStyles(bold: true),
    );
    if (prescription.osSphere != null) {
      bytes += generator.text(
        'Sphère: ${prescription.osSphere!.toStringAsFixed(2)}',
      );
    }
    if (prescription.osCylinder != null) {
      bytes += generator.text(
        'Cylindre: ${prescription.osCylinder!.toStringAsFixed(2)}',
      );
    }
    if (prescription.osAxis != null) {
      bytes += generator.text('Axe: ${prescription.osAxis}°');
    }
    if (prescription.osAdd != null) {
      bytes += generator.text(
        'Addition: ${prescription.osAdd!.toStringAsFixed(2)}',
      );
    }

    bytes += generator.hr();

    // Distances pupillaires
    if (prescription.pdTotal != null) {
      bytes += generator.text(
        'Distance pupillaire: ${prescription.pdTotal!.toStringAsFixed(1)} mm',
      );
    }
    if (prescription.pdRight != null && prescription.pdLeft != null) {
      bytes += generator.text(
        'PD Droite: ${prescription.pdRight!.toStringAsFixed(1)} mm',
      );
      bytes += generator.text(
        'PD Gauche: ${prescription.pdLeft!.toStringAsFixed(1)} mm',
      );
    }

    // Informations verres
    if (prescription.lensType != null) {
      bytes += generator.text('Type de verre: ${prescription.lensType}');
    }
    if (prescription.lensMaterial != null) {
      bytes += generator.text('Matériau: ${prescription.lensMaterial}');
    }
    if (prescription.coating != null) {
      bytes += generator.text('Traitement: ${prescription.coating}');
    }

    // Notes
    if (prescription.notes != null && prescription.notes!.isNotEmpty) {
      bytes += generator.hr();
      bytes += generator.text('Notes:', styles: const PosStyles(bold: true));
      bytes += generator.text(prescription.notes!);
    }

    bytes += generator.feed(2);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  bool _isOpticalInvoice(models.Invoice invoice) {
    for (var item in invoice.items) {
      bool hasPrescription = false;
      if (item.hasPrescription != null) {
        if (item.hasPrescription is bool) {
          hasPrescription = item.hasPrescription as bool;
        } else if (item.hasPrescription is int) {
          hasPrescription = (item.hasPrescription as int) == 1;
        }
      }
      if (hasPrescription) return true;
    }
    return false;
  }

  Future<void> _playPrintSuccessSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('Erreur son impression: $e');
    }
  }

  // Obtenir le statut de l'imprimante
  Map<String, dynamic> getPrinterStatus() {
    return {
      'isConnected': _isConnected,
      'isPrinting': _isPrinting,
      'deviceName': _connectedPrinter?.name ?? 'Aucune',
      'macAddress': _connectedPrinter?.macAdress ?? 'N/A',
      'printerType': 'Imprimante thermique Bluetooth',
      'lastError': _lastError,
    };
  }
}

// ==================== SERVICE IMPRESSION USB SMART AMÉLIORÉ ====================
class UsbPrinterService extends ChangeNotifier {
  UsbDevice? _connectedDevice;
  UsbPort? _port;
  bool _isConnected = false;
  bool _isPrinting = false;
  String _lastError = '';

  // Getters
  bool get isConnected => _isConnected;
  bool get isPrinting => _isPrinting;
  String get lastError => _lastError;
  UsbDevice? get connectedDevice => _connectedDevice;

  Future<List<UsbDevice>> searchAvailablePrinters() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      // Filtrer les imprimantes Smart et autres imprimantes thermiques
      List<UsbDevice> printers = devices.where((device) {
        String productName = device.productName?.toLowerCase() ?? '';
        String manufacturerName = device.manufacturerName?.toLowerCase() ?? '';

        return productName.contains('smart') ||
            productName.contains('thermal') ||
            productName.contains('printer') ||
            productName.contains('pos') ||
            productName.contains('receipt') ||
            manufacturerName.contains('smart') ||
            manufacturerName.contains('thermal') ||
            // VID/PID pour imprimantes communes
            (device.vid == 0x0416 && device.pid == 0x5011) || // Smart
            (device.vid == 0x04B8) || // Epson
            (device.vid == 0x154F) || // Thermal printers
            (device.vid == 0x0483) || // STMicroelectronics
            (device.vid == 0x1A86) || // QinHeng Electronics
            (device.vid == 0x067B); // Prolific Technology
      }).toList();

      debugPrint('Imprimantes USB trouvées: ${printers.length}');
      for (var printer in printers) {
        debugPrint(
          '- ${printer.productName} (VID: ${printer.vid?.toRadixString(16) ?? 'N/A'}, PID: ${printer.pid?.toRadixString(16) ?? 'N/A'})',
        );
      }

      return printers;
    } catch (e) {
      _lastError = 'Erreur recherche imprimantes USB: $e';
      debugPrint(_lastError);
      return [];
    }
  }

  Future<bool> connectToPrinter(UsbDevice device) async {
    try {
      _lastError = '';

      final port = await device.create();
      if (port == null) {
        _lastError = 'Impossible de créer le port USB';
        return false;
      }

      bool openResult = await port.open();
      if (!openResult) {
        _lastError = 'Impossible d\'ouvrir le port USB';
        return false;
      }

      // Configuration du port série
      await port.setDTR(true);
      await port.setRTS(true);

      // Essayer différents baud rates
      final baudRates = [9600, 115200, 19200, 38400];
      bool configured = false;

      for (int baudRate in baudRates) {
        try {
          await port.setPortParameters(
            baudRate,
            UsbPort.DATABITS_8,
            UsbPort.STOPBITS_1,
            UsbPort.PARITY_NONE,
          );

          // Test de communication
          List<int> testCommand = [0x1B, 0x40]; // ESC @ (Reset)
          await port.write(Uint8List.fromList(testCommand));
          await Future.delayed(const Duration(milliseconds: 100));

          configured = true;
          debugPrint('Port USB configuré avec succès à $baudRate baud');
          break;
        } catch (e) {
          debugPrint('Échec configuration à $baudRate baud: $e');
          continue;
        }
      }

      if (!configured) {
        await port.close();
        _lastError = 'Impossible de configurer le port série';
        return false;
      }

      _connectedDevice = device;
      _port = port;
      _isConnected = true;

      await _sendInitializationCommands();
      notifyListeners();
      debugPrint('Imprimante USB connectée: ${device.productName}');
      return true;
    } catch (e) {
      _lastError = 'Erreur connexion imprimante USB: $e';
      debugPrint(_lastError);
      return false;
    }
  }

  Future<void> _sendInitializationCommands() async {
    if (_port == null) return;

    try {
      List<int> initCommands = [];
      initCommands.addAll([0x1B, 0x40]); // ESC @ - Reset
      initCommands.addAll([0x1B, 0x61, 0x00]); // ESC a 0 - Alignement gauche
      initCommands.addAll([0x1B, 0x45, 0x00]); // ESC E 0 - Désactiver gras
      initCommands.addAll([0x1B, 0x4D, 0x00]); // ESC M 0 - Police normale
      initCommands.addAll([0x1B, 0x74, 0x02]); // ESC t 2 - Code page PC850

      await _port!.write(Uint8List.fromList(initCommands));
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('Erreur initialisation USB: $e');
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _isPrinting = false;

    if (_port != null) {
      try {
        await _port!.close();
      } catch (e) {
        debugPrint('Erreur fermeture port USB: $e');
      }
      _port = null;
    }

    _connectedDevice = null;
    _lastError = '';
    notifyListeners();
    debugPrint('Imprimante USB déconnectée');
  }

  Future<bool> printInvoice(models.Invoice invoice) async {
    if (!_isConnected || _port == null) {
      _lastError = 'Imprimante USB non connectée';
      return false;
    }

    try {
      _isPrinting = true;
      _lastError = '';
      notifyListeners();

      List<int> bytes = await _generateInvoiceBytes(invoice);

      // Envoyer par petits blocs
      const int chunkSize = 64;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);
        await _port!.write(Uint8List.fromList(chunk));
        await Future.delayed(const Duration(milliseconds: 50));
      }

      _isPrinting = false;
      notifyListeners();

      await SystemSound.play(SystemSoundType.click);
      debugPrint('Facture USB imprimée avec succès');
      return true;
    } catch (e) {
      _isPrinting = false;
      _lastError = 'Erreur impression facture USB: $e';
      notifyListeners();
      debugPrint(_lastError);
      return false;
    }
  }

  Future<List<int>> _generateInvoiceBytes(models.Invoice invoice) async {
    List<int> bytes = [];

    // Initialisation
    bytes.addAll([0x1B, 0x40]); // ESC @ - Reset
    bytes.addAll([0x1B, 0x74, 0x02]); // ESC t 2 - Code page PC850

    // En-tête MK OPTIQUE
    bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1 - Centrer
    bytes.addAll([0x1B, 0x45, 0x01]); // ESC E 1 - Gras
    bytes.addAll([0x1D, 0x21, 0x11]); // GS ! - Double taille
    bytes.addAll(_encodeText('MK OPTIQUE'));
    bytes.addAll([0x1D, 0x21, 0x00]); // GS ! - Taille normale
    bytes.addAll([0x1B, 0x45, 0x00]); // ESC E 0 - Pas gras
    bytes.addAll([0x0A, 0x0A]);

    // Adresse
    bytes.addAll(_encodeText('Rue Didouche Mourad'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('à côté protection Civile el-hadjar'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('MOB: 06.63.90.47.96'));
    bytes.addAll([0x0A, 0x0A]);

    // Ligne de séparation
    bytes.addAll([0x1B, 0x61, 0x00]); // Alignement gauche
    bytes.addAll(_encodeText('================================'));
    bytes.addAll([0x0A, 0x0A]);

    // Numéro de facture
    bytes.addAll([0x1B, 0x45, 0x01]); // Gras
    bytes.addAll(_encodeText('FACTURE N° ${invoice.invoiceNumber}'));
    bytes.addAll([0x1B, 0x45, 0x00]); // Pas gras
    bytes.addAll([0x0A, 0x0A]);

    // Informations client
    if (invoice.customerName != null && invoice.customerName!.isNotEmpty) {
      bytes.addAll(_encodeText('Client: ${invoice.customerName}'));
    } else {
      bytes.addAll(_encodeText('Client: ..............................'));
    }
    bytes.addAll([0x0A]);

    if (invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty) {
      bytes.addAll(_encodeText('Tél: ${invoice.customerPhone}'));
    } else {
      bytes.addAll(_encodeText('Tél: ..................................'));
    }
    bytes.addAll([0x0A, 0x0A]);

    // Détails des articles
    if (invoice.items.isNotEmpty) {
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras
      bytes.addAll(_encodeText('DÉTAILS:'));
      bytes.addAll([0x1B, 0x45, 0x00]); // Pas gras
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('--------------------------------'));
      bytes.addAll([0x0A]);

      for (var item in invoice.items) {
        String itemName = item.productName ?? 'Article';
        double itemPrice = item.unitPrice ?? 0.0;
        int itemQuantity = item.quantity ?? 1;

        bytes.addAll(_encodeText(itemName));
        bytes.addAll([0x0A]);
        bytes.addAll(
          _encodeText(
            '  Qté: $itemQuantity x ${itemPrice.toStringAsFixed(2)} DA',
          ),
        );
        bytes.addAll([0x0A]);
      }
      bytes.addAll(_encodeText('--------------------------------'));
      bytes.addAll([0x0A]);
    }

    // Total
    bytes.addAll([0x1B, 0x45, 0x01]); // Gras
    bytes.addAll(
      _encodeText('TOTAL: ${invoice.totalAmount.toStringAsFixed(2)} DA'),
    );
    bytes.addAll([0x1B, 0x45, 0x00]); // Pas gras
    bytes.addAll([0x0A]);

    double reste = invoice.remainingAmount ?? 0.0;
    bytes.addAll(_encodeText('Reste à payer: ${reste.toStringAsFixed(2)} DA'));
    bytes.addAll([0x0A, 0x0A]);

    // Champs à remplir
    bytes.addAll(_encodeText('Arrhes: .............................'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('Teinte: .............................'));
    bytes.addAll([0x0A, 0x0A]);

    // Date
    String dateStr = Jiffy.parseFromDateTime(
      invoice.createdAt,
    ).format(pattern: 'dd/MM/yyyy à HH:mm');
    bytes.addAll(_encodeText('Date: $dateStr'));
    bytes.addAll([0x0A, 0x0A]);

    // Prescription optique si nécessaire
    if (_isOpticalInvoice(invoice)) {
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras
      bytes.addAll(_encodeText('PRESCRIPTION:'));
      bytes.addAll([0x1B, 0x45, 0x00]); // Pas gras
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OD (Vision de loin): ................'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OG (Vision de loin): ................'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OD (Vision de près): ................'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OG (Vision de près): ................'));
      bytes.addAll([0x0A, 0x0A]);
    }

    // Message de bas de page
    bytes.addAll([0x1B, 0x61, 0x01]); // Centrer
    bytes.addAll([0x1B, 0x45, 0x01]); // Gras
    bytes.addAll(_encodeText('CONDITIONS DE VENTE'));
    bytes.addAll([0x1B, 0x45, 0x00]); // Pas gras
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('Toute commande confirmée ne pourra'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('être annulée passé le délai de'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('03 Mois. La maison décline toute'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('responsabilité.'));
    bytes.addAll([0x0A, 0x0A, 0x0A, 0x0A]);

    // Coupe du papier
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // GS V B - Coupe complète

    return bytes;
  }

  bool _isOpticalInvoice(models.Invoice invoice) {
    for (var item in invoice.items) {
      bool hasPrescription = false;
      if (item.hasPrescription != null) {
        if (item.hasPrescription is bool) {
          hasPrescription = item.hasPrescription as bool;
        } else if (item.hasPrescription is int) {
          hasPrescription = (item.hasPrescription as int) == 1;
        }
      }
      if (hasPrescription) return true;
    }
    return false;
  }

  List<int> _encodeText(String text) {
    try {
      String processedText = text
          .replaceAll('à', 'à')
          .replaceAll('é', 'é')
          .replaceAll('è', 'è')
          .replaceAll('ç', 'ç')
          .replaceAll('ù', 'ù')
          .replaceAll('ô', 'ô')
          .replaceAll('â', 'â')
          .replaceAll('ê', 'ê')
          .replaceAll('î', 'î')
          .replaceAll('û', 'û');

      return latin1.encode(processedText);
    } catch (e) {
      debugPrint('Erreur encodage texte USB: $e');
      return latin1.encode(text.replaceAll(RegExp(r'[^\x00-\x7F]'), '?'));
    }
  }

  Future<bool> testPrint() async {
    if (!_isConnected || _port == null) {
      _lastError = 'Imprimante USB non connectée';
      return false;
    }

    try {
      _isPrinting = true;
      _lastError = '';
      notifyListeners();

      List<int> bytes = [];

      bytes.addAll([0x1B, 0x40]); // Reset
      bytes.addAll([0x1B, 0x74, 0x02]); // Code page PC850
      bytes.addAll([0x1B, 0x61, 0x01]); // Centrer

      // Test d'impression
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras
      bytes.addAll([0x1D, 0x21, 0x11]); // Double taille
      bytes.addAll(_encodeText('TEST D\'IMPRESSION'));
      bytes.addAll([0x1D, 0x21, 0x00]); // Taille normale
      bytes.addAll([0x1B, 0x45, 0x00]); // Pas gras
      bytes.addAll([0x0A, 0x0A]);

      bytes.addAll([0x1B, 0x45, 0x01]); // Gras
      bytes.addAll(_encodeText('MK OPTIQUE'));
      bytes.addAll([0x1B, 0x45, 0x00]); // Pas gras
      bytes.addAll([0x0A]);

      String dateStr = DateTime.now().toString().substring(0, 19);
      bytes.addAll(_encodeText('Date: $dateStr'));
      bytes.addAll([0x0A, 0x0A]);

      bytes.addAll(_encodeText('✓ Imprimante USB Smart connectée!'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('✓ Test caractères français: àéèç'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('✓ Communication USB OK'));
      bytes.addAll([0x0A, 0x0A, 0x0A, 0x0A]);

      bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // Coupe

      await _port!.write(Uint8List.fromList(bytes));

      _isPrinting = false;
      notifyListeners();

      await SystemSound.play(SystemSoundType.click);
      debugPrint('Test USB réussi');
      return true;
    } catch (e) {
      _isPrinting = false;
      _lastError = 'Erreur test impression USB: $e';
      notifyListeners();
      debugPrint(_lastError);
      return false;
    }
  }

  Map<String, dynamic> getPrinterStatus() {
    return {
      'isConnected': _isConnected,
      'isPrinting': _isPrinting,
      'deviceName': _connectedDevice?.productName ?? 'Aucune',
      'manufacturerName': _connectedDevice?.manufacturerName ?? 'Inconnu',
      'vid': _connectedDevice?.vid?.toRadixString(16) ?? '0000',
      'pid': _connectedDevice?.pid?.toRadixString(16) ?? '0000',
      'printerType': 'Imprimante thermique USB Smart',
      'lastError': _lastError,
    };
  }
}

// ==================== SERVICE SCANNER AMÉLIORÉ ====================
class ScannerService extends ChangeNotifier {
  MobileScannerController? _controller;
  bool _isScanning = false;
  String? _lastScannedCode;
  String _lastError = '';
  Timer? _scanningTimer;

  // Getters
  bool get isScanning => _isScanning;
  String? get lastScannedCode => _lastScannedCode;
  String get lastError => _lastError;

  Future<bool> initialize() async {
    try {
      // Demander les permissions caméra
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _lastError = 'Permission caméra requise';
        return false;
      }

      // Initialiser le contrôleur de scanner mobile
      _controller = MobileScannerController(
        formats: [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.upca,
          BarcodeFormat.upce,
        ],
        torchEnabled: false,
        useNewCameraSelector: true,
      );

      debugPrint('Scanner initialisé avec succès');
      return true;
    } catch (e) {
      _lastError = 'Erreur initialisation scanner: $e';
      debugPrint(_lastError);
      return false;
    }
  }

  Future<String?> scanBarcode() async {
    try {
      _lastError = '';

      // Scanner via la caméra avec flutter_barcode_scanner
      final barcode = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Annuler',
        true,
        ScanMode.BARCODE,
      );

      if (barcode != '-1' && barcode.isNotEmpty) {
        _lastScannedCode = barcode;
        await _playSuccessSound();
        notifyListeners();
        debugPrint('Code-barres scanné: $barcode');
        return barcode;
      }
    } catch (e) {
      _lastError = 'Erreur scan code-barres: $e';
      debugPrint(_lastError);
      await _playErrorSound();
    }
    notifyListeners();
    return null;
  }

  void startContinuousScanning() {
    if (_controller == null) return;

    _isScanning = true;
    notifyListeners();

    // Timer pour arrêter le scan automatiquement après 30 secondes
    _scanningTimer = Timer(const Duration(seconds: 30), () {
      stopContinuousScanning();
    });

    debugPrint('Scan continu démarré');
  }

  void stopContinuousScanning() {
    _isScanning = false;
    _scanningTimer?.cancel();
    _scanningTimer = null;
    notifyListeners();
    debugPrint('Scan continu arrêté');
  }

  Stream<BarcodeCapture>? get barcodeScanStream => _controller?.barcodes;

  void handleBarcodeDetection(List<Barcode> barcodes) {
    if (barcodes.isNotEmpty && _isScanning) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        _lastScannedCode = barcode.rawValue!;
        _playSuccessSound();
        stopContinuousScanning(); // Arrêter après une détection réussie
        notifyListeners();
        debugPrint('Code-barres détecté: ${barcode.rawValue}');
      }
    }
  }

  Future<bool> toggleTorch() async {
    try {
      if (_controller != null) {
        await _controller!.toggleTorch();
        return true;
      }
    } catch (e) {
      _lastError = 'Erreur activation torche: $e';
      debugPrint(_lastError);
    }
    return false;
  }

  Future<bool> switchCamera() async {
    try {
      if (_controller != null) {
        await _controller!.switchCamera();
        return true;
      }
    } catch (e) {
      _lastError = 'Erreur changement caméra: $e';
      debugPrint(_lastError);
    }
    return false;
  }

  Future<void> _playSuccessSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('Erreur son succès: $e');
    }
  }

  Future<void> _playErrorSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('Erreur son erreur: $e');
    }
  }

  void clearLastScannedCode() {
    _lastScannedCode = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanningTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}

// ==================== SERVICE PRODUITS AMÉLIORÉ ====================
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

// ==================== SERVICE STOCK AMÉLIORÉ ====================
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

// ==================== SERVICE CLIENTS AMÉLIORÉ ====================
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

// ==================== SERVICE FACTURES AMÉLIORÉ ====================
class InvoiceService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  List<models.Invoice> _invoices = [];
  bool _isLoading = false;
  models.InvoiceType? _selectedType;
  models.PaymentStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  InvoiceService(this._databaseHelper) {
    loadInvoices();
  }

  // Getters
  List<models.Invoice> get invoices => _filteredInvoices();
  List<models.Invoice> get allInvoices => _invoices;
  bool get isLoading => _isLoading;
  models.InvoiceType? get selectedType => _selectedType;
  models.PaymentStatus? get selectedStatus => _selectedStatus;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  List<models.Invoice> _filteredInvoices() {
    List<models.Invoice> filtered = List.from(_invoices);

    // Filtrer par type
    if (_selectedType != null) {
      filtered = filtered.where((i) => i.invoiceType == _selectedType).toList();
    }

    // Filtrer par statut de paiement
    if (_selectedStatus != null) {
      filtered = filtered
          .where((i) => i.paymentStatus == _selectedStatus)
          .toList();
    }

    // Filtrer par période
    if (_startDate != null) {
      filtered = filtered
          .where((i) => i.createdAt.isAfter(_startDate!))
          .toList();
    }
    if (_endDate != null) {
      filtered = filtered
          .where(
            (i) => i.createdAt.isBefore(_endDate!.add(const Duration(days: 1))),
          )
          .toList();
    }

    return filtered..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> loadInvoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _invoices = await _databaseHelper.getAllInvoices(limit: 500);
      debugPrint('${_invoices.length} factures chargées');
    } catch (e) {
      debugPrint('Erreur chargement factures: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void setFilters({
    models.InvoiceType? type,
    models.PaymentStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _selectedType = type;
    _selectedStatus = status;
    _startDate = startDate;
    _endDate = endDate;
    notifyListeners();
  }

  void clearFilters() {
    _selectedType = null;
    _selectedStatus = null;
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  Future<String> generateInvoiceNumber() async {
    return await _databaseHelper.generateInvoiceNumber();
  }

  Future<bool> createInvoice(models.Cart cart, int userId) async {
    if (cart.isEmpty) return false;

    try {
      final invoiceNumber = await generateInvoiceNumber();

      final invoice = models.Invoice(
        invoiceNumber: invoiceNumber,
        customerId: cart.customer?.id,
        customerName: cart.customer?.name,
        customerPhone: cart.customer?.phone,
        invoiceType: models.InvoiceType.vente,
        paymentType: cart.paymentType,
        subtotal: cart.subtotal,
        discountAmount: cart.totalDiscountAmount,
        taxAmount: cart.taxAmount,
        totalAmount: cart.total,
        paidAmount: cart.paymentType == models.PaymentType.comptant
            ? cart.total
            : 0,
        remainingAmount: cart.paymentType == models.PaymentType.comptant
            ? 0
            : cart.total,
        paymentStatus: cart.paymentType == models.PaymentType.comptant
            ? models.PaymentStatus.paye
            : models.PaymentStatus.impaye,
        notes: cart.notes,
        userId: userId,
      );

      final items = cart.items
          .map(
            (cartItem) => models.InvoiceItem(
              invoiceId: 0, // Sera défini par la base de données
              productId: cartItem.product.id,
              productName: cartItem.product.name,
              productBarcode: cartItem.product.barcode,
              quantity: cartItem.quantity,
              unitPrice: cartItem.unitPrice,
              discountAmount: cartItem.discountAmount,
              totalPrice: cartItem.total,
              hasPrescription: cartItem.hasPrescription,
            ),
          )
          .toList();

      await _databaseHelper.insertInvoice(invoice, items);
      await loadInvoices();
      debugPrint('Facture créée: ${invoice.invoiceNumber}');
      return true;
    } catch (e) {
      debugPrint('Erreur création facture: $e');
      return false;
    }
  }

  Future<models.Invoice?> getInvoiceById(int id) async {
    return await _databaseHelper.getInvoiceById(id);
  }

  Future<models.Invoice?> getInvoiceByNumber(String invoiceNumber) async {
    try {
      return _invoices
          .where((i) => i.invoiceNumber == invoiceNumber)
          .firstOrNull;
    } catch (e) {
      debugPrint('Erreur recherche facture par numéro: $e');
      return null;
    }
  }

  Future<bool> addPayment(int invoiceId, models.Payment payment) async {
    try {
      await _databaseHelper.insertPayment(payment);

      // Mettre à jour le statut de paiement
      final invoice = await _databaseHelper.getInvoiceById(invoiceId);
      if (invoice != null) {
        final payments = await _databaseHelper.getInvoicePayments(invoiceId);
        final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);

        models.PaymentStatus newStatus;
        if (totalPaid >= invoice.totalAmount) {
          newStatus = models.PaymentStatus.paye;
        } else if (totalPaid > 0) {
          newStatus = models.PaymentStatus.partiel;
        } else {
          newStatus = models.PaymentStatus.impaye;
        }

        await _databaseHelper.updateInvoicePaymentStatus(
          invoiceId,
          newStatus,
          totalPaid,
        );
      }

      await loadInvoices();
      debugPrint('Paiement ajouté pour facture ID: $invoiceId');
      return true;
    } catch (e) {
      debugPrint('Erreur ajout paiement: $e');
      return false;
    }
  }

  Future<List<models.Payment>> getInvoicePayments(int invoiceId) async {
    return await _databaseHelper.getInvoicePayments(invoiceId);
  }

  List<models.Invoice> getUnpaidInvoices() {
    return _invoices
        .where(
          (invoice) =>
              invoice.paymentStatus == models.PaymentStatus.impaye ||
              invoice.paymentStatus == models.PaymentStatus.partiel,
        )
        .toList();
  }

  List<models.Invoice> getTodayInvoices() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _invoices
        .where(
          (invoice) =>
              invoice.createdAt.isAfter(startOfDay) &&
              invoice.createdAt.isBefore(endOfDay),
        )
        .toList();
  }

  List<models.Invoice> getThisMonthInvoices() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    return _invoices
        .where(
          (invoice) =>
              invoice.createdAt.isAfter(startOfMonth) &&
              invoice.createdAt.isBefore(endOfMonth),
        )
        .toList();
  }

  double getTotalUnpaidAmount() {
    return getUnpaidInvoices().fold(
      0,
      (sum, invoice) => sum + invoice.remainingAmount,
    );
  }

  double getTodayTotalSales() {
    return getTodayInvoices().fold(
      0,
      (sum, invoice) => invoice.paymentStatus != models.PaymentStatus.annule
          ? sum + invoice.totalAmount
          : sum,
    );
  }

  double getThisMonthTotalSales() {
    return getThisMonthInvoices().fold(
      0,
      (sum, invoice) => invoice.paymentStatus != models.PaymentStatus.annule
          ? sum + invoice.totalAmount
          : sum,
    );
  }

  Map<String, dynamic> getInvoiceStats() {
    final totalInvoices = _invoices.length;
    final paidInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.paye)
        .length;
    final unpaidInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.impaye)
        .length;
    final partialInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.partiel)
        .length;
    final cancelledInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.annule)
        .length;

    final totalSales = _invoices.fold(
      0.0,
      (sum, i) => i.paymentStatus != models.PaymentStatus.annule
          ? sum + i.totalAmount
          : sum,
    );
    final totalPaid = _invoices.fold(0.0, (sum, i) => sum + i.paidAmount);
    final totalUnpaid = getTotalUnpaidAmount();

    return {
      'totalInvoices': totalInvoices,
      'paidInvoices': paidInvoices,
      'unpaidInvoices': unpaidInvoices,
      'partialInvoices': partialInvoices,
      'cancelledInvoices': cancelledInvoices,
      'totalSales': totalSales,
      'totalPaid': totalPaid,
      'totalUnpaid': totalUnpaid,
      'todaySales': getTodayTotalSales(),
      'monthSales': getThisMonthTotalSales(),
    };
  }
}

// ==================== SERVICE PRESCRIPTIONS AMÉLIORÉ ====================
class PrescriptionService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  List<models.Prescription> _prescriptions = [];
  bool _isLoading = false;

  PrescriptionService(this._databaseHelper);

  // Getters
  List<models.Prescription> get prescriptions => _prescriptions;
  bool get isLoading => _isLoading;

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

  double calculateSphericalEquivalent(double? sphere, double? cylinder) {
    if (sphere == null) return 0;
    return sphere + ((cylinder ?? 0) / 2);
  }

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

  bool isProgressiveLens(models.Prescription prescription) {
    return (prescription.odAdd != null && prescription.odAdd! > 0) ||
        (prescription.osAdd != null && prescription.osAdd! > 0);
  }

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
}

// ==================== SERVICE RAPPORTS AMÉLIORÉ ====================
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
    notifyListeners();

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

// ==================== SERVICE GESTIONNAIRE UNIFIÉ ====================
class MKOptiqueServiceManager extends ChangeNotifier {
  // Services principaux
  late final AuthService authService;
  late final BluetoothPrinterService bluetoothPrinterService;
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
      bluetoothPrinterService = BluetoothPrinterService();
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
      await bluetoothPrinterService.initialize();
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
      'bluetoothPrinter': bluetoothPrinterService.getPrinterStatus(),
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
    bluetoothPrinterService.dispose();
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
