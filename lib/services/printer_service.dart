// ==================== SERVICE D'IMPRESSION USB SMART AMÉLIORÉ ====================
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:jiffy/jiffy.dart';
import 'package:mk_optique/models.dart' as models;
import 'package:usb_serial/usb_serial.dart';

class UsbPrinterService extends ChangeNotifier {
  UsbDevice? _connectedDevice;
  UsbPort? _port;
  bool _isConnected = false;
  bool _isPrinting = false;
  String _lastError = '';
  List<UsbDevice> _availablePrinters = [];

  // Getters
  bool get isConnected => _isConnected;
  bool get isPrinting => _isPrinting;
  String get lastError => _lastError;
  UsbDevice? get connectedDevice => _connectedDevice;
  UsbDevice? get connectedPrinter => _connectedDevice;
  List<UsbDevice> get availablePrinters => _availablePrinters;
  String get name => _connectedDevice?.productName ?? '';
  String get macAdress => ''; // USB n'a pas d'adresse MAC

  /// Recherche des imprimantes USB disponibles
  Future<void> searchPrinters() async {
    _availablePrinters = await searchAvailablePrinters();
    notifyListeners();
  }

  Future<List<UsbDevice>> searchAvailablePrinters() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();

      // Filtrage des imprimantes thermiques et Smart
      List<UsbDevice> printers = devices.where((device) {
        String productName = (device.productName ?? '').toLowerCase();
        String manufacturerName = (device.manufacturerName ?? '').toLowerCase();

        // Critères de détection pour imprimantes Smart et thermiques
        return productName.contains('smart') ||
            productName.contains('thermal') ||
            productName.contains('printer') ||
            productName.contains('pos') ||
            productName.contains('receipt') ||
            productName.contains('label') ||
            manufacturerName.contains('smart') ||
            manufacturerName.contains('thermal') ||
            manufacturerName.contains('pos') ||
            // VID/PID pour imprimantes communes
            (device.vid == 0x0416 && device.pid == 0x5011) || // Smart
            (device.vid == 0x04B8) || // Epson
            (device.vid == 0x154F) || // Thermal printers génériques
            (device.vid == 0x0483) || // STMicroelectronics
            (device.vid == 0x1A86) || // QinHeng Electronics
            (device.vid == 0x067B) || // Prolific Technology
            (device.vid == 0x2120); // Smart POS printers
      }).toList();

      debugPrint('🖨️ Imprimantes USB trouvées: ${printers.length}');
      for (var printer in printers) {
        debugPrint(
          '  📄 ${printer.productName} (VID: ${printer.vid?.toRadixString(16)?.toUpperCase() ?? 'N/A'}, PID: ${printer.pid?.toRadixString(16)?.toUpperCase() ?? 'N/A'})',
        );
      }

      _availablePrinters = printers;
      return printers;
    } catch (e) {
      _lastError = 'Erreur lors de la recherche d\'imprimantes USB: $e';
      debugPrint('❌ $_lastError');
      _availablePrinters = [];
      return [];
    }
  }

  /// Connexion à une imprimante USB
  Future<bool> connectToPrinter(UsbDevice device) async {
    try {
      _lastError = '';
      debugPrint('🔗 Tentative de connexion à: ${device.productName}');

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

      // Configuration du port série avec différents baud rates
      final baudRates = [9600, 115200, 19200, 38400, 57600];
      bool configured = false;

      for (int baudRate in baudRates) {
        try {
          await port.setPortParameters(
            baudRate,
            UsbPort.DATABITS_8,
            UsbPort.STOPBITS_1,
            UsbPort.PARITY_NONE,
          );

          // Configuration des signaux de contrôle
          await port.setDTR(true);
          await port.setRTS(true);

          // Test de communication avec commande de reset
          await port.write(Uint8List.fromList([0x1B, 0x40])); // ESC @
          await Future.delayed(const Duration(milliseconds: 200));

          configured = true;
          debugPrint('✅ Port USB configuré avec succès à $baudRate baud');
          break;
        } catch (e) {
          debugPrint('⚠️ Échec configuration à $baudRate baud: $e');
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

      await _initializePrinter();
      notifyListeners();
      debugPrint('🖨️ Imprimante USB connectée: ${device.productName}');
      return true;
    } catch (e) {
      _lastError = 'Erreur de connexion à l\'imprimante USB: $e';
      debugPrint('❌ $_lastError');
      return false;
    }
  }

  /// Initialisation de l'imprimante avec les commandes ESC/POS
  Future<void> _initializePrinter() async {
    if (_port == null) return;

    try {
      List<int> initCommands = [];

      // Séquence d'initialisation complète
      initCommands.addAll([0x1B, 0x40]); // ESC @ - Reset complet
      await Future.delayed(const Duration(milliseconds: 300));

      initCommands.addAll([
        0x1B,
        0x74,
        0x02,
      ]); // ESC t 2 - Code page PC850 (Français)
      initCommands.addAll([
        0x1B,
        0x52,
        0x02,
      ]); // ESC R 2 - Jeu de caractères français
      initCommands.addAll([0x1B, 0x61, 0x00]); // ESC a 0 - Alignement gauche
      initCommands.addAll([0x1B, 0x45, 0x00]); // ESC E 0 - Désactiver gras
      initCommands.addAll([0x1B, 0x4D, 0x00]); // ESC M 0 - Police normale
      initCommands.addAll([0x1D, 0x21, 0x00]); // GS ! 0 - Taille normale

      await _port!.write(Uint8List.fromList(initCommands));
      await Future.delayed(const Duration(milliseconds: 200));

      debugPrint('✅ Imprimante initialisée avec succès');
    } catch (e) {
      debugPrint('❌ Erreur d\'initialisation: $e');
    }
  }

  /// Déconnexion de l'imprimante
  Future<void> disconnect() async {
    _isConnected = false;
    _isPrinting = false;

    if (_port != null) {
      try {
        await _port!.close();
      } catch (e) {
        debugPrint('⚠️ Erreur lors de la fermeture du port USB: $e');
      }
      _port = null;
    }

    _connectedDevice = null;
    _lastError = '';
    notifyListeners();
    debugPrint('🔌 Imprimante USB déconnectée');
  }

  /// Impression d'étiquettes de code-barres avec design amélioré
  Future<bool> printBarcode(
    String barcode, {
    String? productName,
    String? brand,
    double? price,
    int quantity = 1,
  }) async {
    if (!_isConnected || _port == null) {
      _lastError = 'Imprimante USB non connectée';
      return false;
    }

    try {
      _isPrinting = true;
      _lastError = '';
      notifyListeners();

      debugPrint('🏷️ Impression de $quantity étiquette(s) pour: $productName');

      for (int i = 0; i < quantity; i++) {
        List<int> bytes = await _generateBarcodeLabel(
          barcode,
          productName: productName,
          brand: brand,
          price: price,
        );

        // Envoi par blocs pour éviter les problèmes de buffer
        await _sendDataInChunks(bytes);

        // Délai entre les étiquettes
        if (i < quantity - 1) {
          await Future.delayed(const Duration(milliseconds: 800));
        }
      }

      _isPrinting = false;
      notifyListeners();

      await SystemSound.play(SystemSoundType.click);
      debugPrint('✅ $quantity étiquette(s) imprimée(s) avec succès');
      return true;
    } catch (e) {
      _isPrinting = false;
      _lastError = 'Erreur d\'impression d\'étiquettes: $e';
      notifyListeners();
      debugPrint('❌ $_lastError');
      return false;
    }
  }

  /// Génération d'une étiquette de code-barres avec design professionnel
  Future<List<int>> _generateBarcodeLabel(
    String barcode, {
    String? productName,
    String? brand,
    double? price,
  }) async {
    List<int> bytes = [];

    try {
      // Initialisation
      bytes.addAll([0x1B, 0x40]); // Reset
      bytes.addAll([0x1B, 0x74, 0x02]); // Code page PC850
      bytes.addAll([0x1B, 0x61, 0x01]); // Centrer

      // En-tête élégant avec nom de la boutique
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
      bytes.addAll([0x1D, 0x21, 0x11]); // Double hauteur et largeur
      bytes.addAll(_encodeText('MK OPTIQUE'));
      bytes.addAll([0x1D, 0x21, 0x00]); // Taille normale
      bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
      bytes.addAll([0x0A]); // Saut de ligne

      // Ligne décorative
      bytes.addAll(_encodeText('═══════════════════════════════'));
      bytes.addAll([0x0A]);

      // Nom du produit (limité et formaté proprement)
      if (productName != null && productName.isNotEmpty) {
        bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
        String formattedName = _formatProductName(productName);
        bytes.addAll(_encodeText(formattedName));
        bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
        bytes.addAll([0x0A]);
      }

      // Marque si disponible
      if (brand != null && brand.isNotEmpty) {
        bytes.addAll(_encodeText('Marque: $brand'));
        bytes.addAll([0x0A]);
      }

      // Prix si disponible
      if (price != null && price > 0) {
        bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
        bytes.addAll(_encodeText('Prix: ${price.toStringAsFixed(2)} DA'));
        bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
        bytes.addAll([0x0A]);
      }

      bytes.addAll([0x0A]); // Espace avant le code-barres

      // Configuration du code-barres CODE128 optimisée
      bytes.addAll([0x1D, 0x48, 0x02]); // Position du texte: en dessous
      bytes.addAll([0x1D, 0x77, 0x03]); // Largeur des barres: 3 (plus épais)
      bytes.addAll([0x1D, 0x68, 0x60]); // Hauteur: 96 points (plus grand)
      bytes.addAll([0x1D, 0x66, 0x00]); // Police A pour le texte

      // Impression du code-barres CODE128
      bytes.addAll([0x1D, 0x6B, 0x49]); // GS k I (CODE128)
      bytes.add(barcode.length); // Longueur des données
      bytes.addAll(utf8.encode(barcode)); // Données du code-barres

      bytes.addAll([0x0A, 0x0A]); // Espaces après le code-barres

      // Date d'impression
      String dateStr =
          DateTime.now().day.toString().padLeft(2, '0') +
          '/' +
          DateTime.now().month.toString().padLeft(2, '0') +
          '/' +
          DateTime.now().year.toString();
      bytes.addAll(_encodeText('Imprimé le: $dateStr'));
      bytes.addAll([0x0A, 0x0A, 0x0A]); // Espaces finaux

      // Coupe du papier
      bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // Coupe complète

      return bytes;
    } catch (e) {
      debugPrint('❌ Erreur génération étiquette: $e');
      return [];
    }
  }

  /// Formatage du nom du produit pour l'étiquette
  String _formatProductName(String name) {
    // Limiter à 32 caractères et découper intelligemment
    if (name.length <= 32) return name;

    List<String> words = name.split(' ');
    String result = '';

    for (String word in words) {
      if ((result + word).length <= 32) {
        result += (result.isEmpty ? '' : ' ') + word;
      } else {
        break;
      }
    }

    return result.isEmpty ? name.substring(0, 32) : result;
  }

  /// Impression de facture améliorée
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
      await _sendDataInChunks(bytes);

      _isPrinting = false;
      notifyListeners();

      await SystemSound.play(SystemSoundType.click);
      debugPrint('📄 Facture imprimée avec succès');
      return true;
    } catch (e) {
      _isPrinting = false;
      _lastError = 'Erreur d\'impression de facture: $e';
      notifyListeners();
      debugPrint('❌ $_lastError');
      return false;
    }
  }

  /// Génération des bytes pour la facture avec mise en page améliorée
  Future<List<int>> _generateInvoiceBytes(models.Invoice invoice) async {
    List<int> bytes = [];

    // Initialisation
    bytes.addAll([0x1B, 0x40]); // Reset
    bytes.addAll([0x1B, 0x74, 0x02]); // Code page PC850

    // En-tête MK OPTIQUE avec style
    bytes.addAll([0x1B, 0x61, 0x01]); // Centrer
    bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
    bytes.addAll([0x1D, 0x21, 0x11]); // Double taille
    bytes.addAll(_encodeText('MK OPTIQUE'));
    bytes.addAll([0x1D, 0x21, 0x00]); // Taille normale
    bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
    bytes.addAll([0x0A, 0x0A]);

    // Informations de contact
    bytes.addAll(_encodeText('Rue Didouche Mourad'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('à côté Protection Civile El-Hadjar'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('Tél: 06.63.90.47.96'));
    bytes.addAll([0x0A, 0x0A]);

    // Ligne de séparation élégante
    bytes.addAll([0x1B, 0x61, 0x00]); // Alignement gauche
    bytes.addAll(_encodeText('═══════════════════════════════════'));
    bytes.addAll([0x0A, 0x0A]);

    // Numéro de facture avec mise en évidence
    bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
    bytes.addAll([0x1D, 0x21, 0x01]); // Double hauteur
    bytes.addAll(_encodeText('FACTURE N° ${invoice.invoiceNumber}'));
    bytes.addAll([0x1D, 0x21, 0x00]); // Taille normale
    bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
    bytes.addAll([0x0A, 0x0A]);

    // Informations client dans un cadre
    bytes.addAll(_encodeText('┌─ INFORMATIONS CLIENT ─────────────┐'));
    bytes.addAll([0x0A]);

    String clientName = invoice.customerName?.isNotEmpty == true
        ? invoice.customerName!
        : '................................';
    bytes.addAll(_encodeText('│ Client: $clientName'));
    bytes.addAll([0x0A]);

    String clientPhone = invoice.customerPhone?.isNotEmpty == true
        ? invoice.customerPhone!
        : '................................';
    bytes.addAll(_encodeText('│ Tél: $clientPhone'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('└────────────────────────────────────┘'));
    bytes.addAll([0x0A, 0x0A]);

    // Détails des articles si présents
    if (invoice.items.isNotEmpty) {
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
      bytes.addAll(_encodeText('DÉTAILS DE LA COMMANDE:'));
      bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('─────────────────────────────────────'));
      bytes.addAll([0x0A]);

      for (var item in invoice.items) {
        String itemName = item.productName ?? 'Article';
        double itemPrice = item.unitPrice ?? 0.0;
        int itemQuantity = item.quantity ?? 1;
        double totalItem = itemPrice * itemQuantity;

        bytes.addAll(_encodeText('• $itemName'));
        bytes.addAll([0x0A]);
        bytes.addAll(
          _encodeText(
            '  ${itemQuantity} x ${itemPrice.toStringAsFixed(2)} DA = ${totalItem.toStringAsFixed(2)} DA',
          ),
        );
        bytes.addAll([0x0A]);
      }
      bytes.addAll(_encodeText('─────────────────────────────────────'));
      bytes.addAll([0x0A]);
    }

    // Totaux avec mise en évidence
    bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
    bytes.addAll([0x1D, 0x21, 0x01]); // Double hauteur
    bytes.addAll(
      _encodeText('TOTAL: ${invoice.totalAmount.toStringAsFixed(2)} DA'),
    );
    bytes.addAll([0x1D, 0x21, 0x00]); // Taille normale
    bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
    bytes.addAll([0x0A]);

    double reste = invoice.remainingAmount ?? 0.0;
    if (reste > 0) {
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
      bytes.addAll(
        _encodeText('Reste à payer: ${reste.toStringAsFixed(2)} DA'),
      );
      bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
    }
    bytes.addAll([0x0A, 0x0A]);

    // Champs à remplir
    bytes.addAll(_encodeText('Arrhes: .................................'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('Teinte: .................................'));
    bytes.addAll([0x0A, 0x0A]);

    // Date et heure
    String dateStr = Jiffy.parseFromDateTime(
      invoice.createdAt,
    ).format(pattern: 'dd/MM/yyyy à HH:mm');
    bytes.addAll(_encodeText('Date: $dateStr'));
    bytes.addAll([0x0A, 0x0A]);

    // Prescription optique si nécessaire
    if (_isOpticalInvoice(invoice)) {
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
      bytes.addAll(_encodeText('PRESCRIPTION OPTIQUE:'));
      bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OD (Vision de loin): ....................'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OG (Vision de loin): ....................'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OD (Vision de près): ....................'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('OG (Vision de près): ....................'));
      bytes.addAll([0x0A, 0x0A]);
    }

    // Conditions de vente avec encadré
    bytes.addAll([0x1B, 0x61, 0x01]); // Centrer
    bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
    bytes.addAll(_encodeText('CONDITIONS DE VENTE'));
    bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('Toute commande confirmée ne pourra'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('être annulée passé le délai de'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('03 mois. La maison décline toute'));
    bytes.addAll([0x0A]);
    bytes.addAll(_encodeText('responsabilité.'));
    bytes.addAll([0x0A, 0x0A, 0x0A]);

    // Coupe du papier
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // Coupe complète

    return bytes;
  }

  /// Envoi des données par blocs pour améliorer la fiabilité
  Future<void> _sendDataInChunks(List<int> bytes) async {
    const int chunkSize = 64;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      List<int> chunk = bytes.sublist(i, end);
      await _port!.write(Uint8List.fromList(chunk));
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  /// Test d'impression avec design amélioré
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

      // Test d'impression avec style
      bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
      bytes.addAll([0x1D, 0x21, 0x11]); // Double taille
      bytes.addAll(_encodeText('TEST D\'IMPRESSION'));
      bytes.addAll([0x1D, 0x21, 0x00]); // Taille normale
      bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
      bytes.addAll([0x0A, 0x0A]);

      bytes.addAll([0x1B, 0x45, 0x01]); // Gras ON
      bytes.addAll(_encodeText('MK OPTIQUE'));
      bytes.addAll([0x1B, 0x45, 0x00]); // Gras OFF
      bytes.addAll([0x0A]);

      String dateStr = DateTime.now().toString().substring(0, 19);
      bytes.addAll(_encodeText('Date: $dateStr'));
      bytes.addAll([0x0A, 0x0A]);

      bytes.addAll(_encodeText('✓ Imprimante USB Smart connectée !'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('✓ Caractères français: àéèçù'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('✓ Communication USB OK'));
      bytes.addAll([0x0A]);
      bytes.addAll(_encodeText('✓ Prêt pour l\'impression'));
      bytes.addAll([0x0A, 0x0A, 0x0A]);

      bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // Coupe

      await _sendDataInChunks(bytes);

      _isPrinting = false;
      notifyListeners();

      await SystemSound.play(SystemSoundType.click);
      debugPrint('✅ Test d\'impression réussi');
      return true;
    } catch (e) {
      _isPrinting = false;
      _lastError = 'Erreur lors du test d\'impression: $e';
      notifyListeners();
      debugPrint('❌ $_lastError');
      return false;
    }
  }

  /// Vérification si la facture concerne l'optique
  bool _isOpticalInvoice(models.Invoice invoice) {
    for (var item in invoice.items) {
      bool hasPrescription = false;
      final prescription = item.hasPrescription;

      if (prescription != null) {
        if (prescription is bool) {
          hasPrescription = prescription;
        } else if (prescription is int) {
          hasPrescription = prescription == 1;
        } else if (prescription is String) {
          hasPrescription =
              prescription.toLowerCase() == 'true' || prescription == '1';
        }
      }

      if (hasPrescription) return true;
    }
    return false;
  }

  /// Encodage du texte avec gestion des caractères français
  List<int> _encodeText(String text) {
    try {
      // Conversion des caractères français pour l'impression
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
          .replaceAll('û', 'û')
          .replaceAll('À', 'À')
          .replaceAll('É', 'É')
          .replaceAll('È', 'È')
          .replaceAll('Ç', 'Ç');

      return latin1.encode(processedText);
    } catch (e) {
      debugPrint('❌ Erreur d\'encodage du texte: $e');
      // Fallback: remplacer les caractères non supportés par '?'
      return latin1.encode(text.replaceAll(RegExp(r'[^\x00-\x7F]'), '?'));
    }
  }

  /// Obtenir le statut détaillé de l'imprimante
  Map<String, dynamic> getPrinterStatus() {
    return {
      'isConnected': _isConnected,
      'isPrinting': _isPrinting,
      'deviceName': _connectedDevice?.productName ?? 'Aucune',
      'manufacturerName': _connectedDevice?.manufacturerName ?? 'Inconnu',
      'vid': _connectedDevice?.vid?.toRadixString(16)?.toUpperCase() ?? '0000',
      'pid': _connectedDevice?.pid?.toRadixString(16)?.toUpperCase() ?? '0000',
      'printerType': 'Imprimante thermique USB Smart',
      'lastError': _lastError,
      'connectionTime': _isConnected ? DateTime.now().toString() : null,
    };
  }

  /// Obtenir les informations détaillées d'un périphérique
  Map<String, String> getDeviceInfo(UsbDevice device) {
    return {
      'name': device.productName ?? 'Périphérique USB',
      'productName': device.productName ?? 'Inconnu',
      'manufacturerName': device.manufacturerName ?? 'Inconnu',
      'vid': device.vid?.toRadixString(16)?.toUpperCase() ?? '0000',
      'pid': device.pid?.toRadixString(16)?.toUpperCase() ?? '0000',
      'macAdress': '', // USB n'utilise pas d'adresse MAC
      'type': 'USB',
    };
  }

  /// Méthode pour imprimer un produit (compatibilité)
  Future<bool> printBarcode(dynamic product) async {
    if (product is models.Product) {
      return await printBarcode(
        product.barcode ?? '',
        productName: product.name,
        brand: product.brand,
        price: product.sellPrice,
      );
    } else if (product is String) {
      return await printBarcode(product);
    }
    return false;
  }
}
