import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models.dart';

class ScannerDevice {
  final String productName;
  final int vendorId;
  final int productId;

  ScannerDevice({
    required this.productName,
    required this.vendorId,
    required this.productId,
  });
}

class ScannerService extends ChangeNotifier {
  MobileScannerController? _controller;
  bool _isScanning = false;
  String? _lastScannedCode;
  String _lastError = '';
  Timer? _scanningTimer;

  bool _isConnected = false;
  ScannerDevice? _connectedDevice;
  final FlutterUsbPrinter _scanner = FlutterUsbPrinter();

  final _barcodeController = StreamController<String>.broadcast();
  final _productController = StreamController<Product?>.broadcast();

  // Getters
  bool get isScanning => _isScanning;
  String? get lastScannedCode => _lastScannedCode;
  String get lastError => _lastError;
  bool get isConnected => _isConnected;
  ScannerDevice? get connectedDevice => _connectedDevice;
  Stream<String> get barcodeStream => _barcodeController.stream;
  Stream<Product?> get productStream => _productController.stream;

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
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
        torchEnabled: false,
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

  Future<List<ScannerDevice>> searchAvailableScanners() async {
    try {
      final devices = await FlutterUsbPrinter.getUSBDeviceList();
      return devices
          .map(
            (device) => ScannerDevice(
              productName: device['productName'] ?? 'Unknown Scanner',
              vendorId: device['vendorId'] ?? 0,
              productId: device['productId'] ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching scanners: $e');
      return [];
    }
  }

  Future<bool> connectToScanner(ScannerDevice device) async {
    try {
      final connected = await _scanner.connect(
        device.vendorId,
        device.productId,
      );

      _isConnected = connected ?? false; // Handle nullable bool
      _connectedDevice = _isConnected ? device : null;
      notifyListeners();

      return _isConnected;
    } catch (e) {
      debugPrint('Error connecting to scanner: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _scanner.close();
      _isConnected = false;
      _connectedDevice = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting scanner: $e');
    }
  }

  @override
  void dispose() {
    _scanningTimer?.cancel();
    _controller?.dispose();
    _barcodeController.close();
    _productController.close();
    disconnect();
    super.dispose();
  }
}
