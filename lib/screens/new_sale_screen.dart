import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/models.dart';
import 'package:mk_optique/services/auth_service.dart';
import 'package:mk_optique/services/invoice_service.dart';
import 'package:mk_optique/services/printer_service.dart';
import 'package:mk_optique/services/product_service.dart';
import 'package:mk_optique/services/scanner_service.dart';
import 'package:provider/provider.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final Cart _cart = Cart();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Product> _filteredProducts = [];
  Customer? _selectedCustomer;

  // Variables pour le paiement à crédit
  bool _isCreditSale = false;
  int _creditDurationMonths = 12;
  double _downPayment = 0.0;
  final TextEditingController _downPaymentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _setupBarcodeScanning();
      // Focus sur la barre de recherche pour le scanner Smart
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _initializeData() async {
    try {
      await context.read<ProductService>().loadProducts();
      // Connecter automatiquement aux appareils Smart
      await _connectSmartDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du chargement des données'),
          ),
        );
      }
    }
  }

  Future<void> _connectSmartDevices() async {
    final scannerService = context.read<ScannerService>();
    final printerService = context.read<UsbPrinterService>();

    // Rechercher et connecter le scanner Smart
    try {
      final scanners = await scannerService.searchAvailableScanners();
      if (scanners.isNotEmpty) {
        bool connected = await scannerService.connectToScanner(scanners.first);
        if (connected && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Scanner Smart connecté: ${scanners.first.productName}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur connexion scanner: $e');
    }

    // Rechercher et connecter l'imprimante Smart
    try {
      final printers = await printerService.searchAvailablePrinters();
      if (printers.isNotEmpty) {
        bool connected = await printerService.connectToPrinter(printers.first);
        if (connected && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imprimante Smart connectée: ${printers.first.productName}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur connexion imprimante: $e');
    }
  }

  void _setupBarcodeScanning() {
    final scannerService = context.read<ScannerService>();

    // Écouter les codes-barres scannés
    scannerService.barcodeStream.listen((barcode) {
      _handleScannedBarcode(barcode);
    });

    // Écouter les produits trouvés
    scannerService.productStream.listen((product) {
      if (product != null) {
        _addToCart(product);
      }
    });

    // Écouter aussi les entrées clavier du scanner Smart
    _searchController.addListener(() {
      String text = _searchController.text;
      if (text.length >= 8 && RegExp(r'^\d+$').hasMatch(text)) {
        // Probable code-barres saisi par le scanner Smart
        _handleScannedBarcode(text);
        _searchController.clear();
      }
    });
  }

  void _handleScannedBarcode(String barcode) async {
    final productService = context.read<ProductService>();
    final product = await productService.getProductByBarcode(barcode);

    if (product != null && mounted) {
      _addToCart(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} ajouté au panier'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produit non trouvé'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProductService, UsbPrinterService>(
      builder: (context, productService, printerService, _) {
        if (productService.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (productService.products.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nouvelle Vente')),
            body: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aucun produit disponible',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: _initializeData,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildDeviceStatus(),
              Expanded(flex: 2, child: _buildProductsList()),
              _buildCartSummary(),
              Expanded(child: _buildCartItems()),
            ],
          ),
          bottomNavigationBar: _buildActionButtons(),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Nouvelle Vente'),
      backgroundColor: Colors.blue.shade800,
      foregroundColor: Colors.white,
      leading: context.canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            )
          : IconButton(
              icon: const Icon(Icons.home),
              onPressed: () => context.go('/dashboard'),
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _scanBarcode,
          tooltip: 'Scanner manuel',
        ),
        IconButton(
          icon: const Icon(Icons.person_add),
          onPressed: _selectCustomer,
          tooltip: 'Sélectionner client',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showDeviceSettings,
          tooltip: 'Paramètres appareils',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4)],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Scanner ou rechercher un produit...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Consumer<ScannerService>(
            builder: (context, scannerService, child) {
              return Icon(
                scannerService.isConnected
                    ? Icons.qr_code_scanner
                    : Icons.qr_code_scanner_outlined,
                color: scannerService.isConnected ? Colors.green : Colors.grey,
              );
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: _searchProducts,
        onSubmitted: (value) {
          if (value.isNotEmpty && RegExp(r'^\d+$').hasMatch(value)) {
            _handleScannedBarcode(value);
            _searchController.clear();
          }
        },
      ),
    );
  }

  Widget _buildDeviceStatus() {
    return Consumer2<ScannerService, UsbPrinterService>(
      builder: (context, scannerService, printerService, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildStatusChip(
                'Scanner',
                scannerService.isConnected,
                scannerService.connectedDevice?.productName ?? 'Déconnecté',
              ),
              const SizedBox(width: 8),
              _buildStatusChip(
                'Imprimante',
                printerService.isConnected,
                printerService.connectedDevice?.productName ?? 'Déconnectée',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String label, bool isConnected, String deviceName) {
    return Expanded(
      child: Chip(
        avatar: Icon(
          isConnected ? Icons.check_circle : Icons.error_outline,
          color: isConnected ? Colors.green : Colors.red,
          size: 16,
        ),
        label: Text(
          '$label: ${isConnected ? 'OK' : 'Déconnecté'}',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: isConnected
            ? Colors.green.shade50
            : Colors.red.shade50,
      ),
    );
  }

  Widget _buildProductsList() {
    return Consumer<ProductService>(
      builder: (context, productService, child) {
        final products = _filteredProducts.isEmpty
            ? productService.products
            : _filteredProducts;

        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucun produit trouvé',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: product.isLowStock
                      ? Colors.red
                      : Colors.green,
                  child: Text(
                    product.quantity.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${product.brand ?? ''} - ${product.sellPrice.toStringAsFixed(2)} DA',
                    ),
                    if (product.creditPrice != null && product.creditPrice! > 0)
                      Text(
                        'Crédit: ${product.creditPrice!.toStringAsFixed(2)} DA',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (product.barcode != null)
                      Text(
                        'Code: ${product.barcode}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => _addToCart(product),
                ),
                onTap: () => _addToCart(product),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
        ),
        boxShadow: [
          BoxShadow(color: Colors.blue.shade600.withAlpha(77), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Articles: ${_cart.totalItems}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                'Total: ${_cart.total.toStringAsFixed(2)} DA',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_selectedCustomer != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Client: ${_selectedCustomer!.name}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
          if (_isCreditSale) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payment, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Vente à crédit - $_creditDurationMonths mois',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItems() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Panier vide',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const Text(
              'Scanner ou ajouter des produits',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cart.items.length,
      itemBuilder: (context, index) {
        final item = _cart.items[index];
        final priceToShow =
            _isCreditSale &&
                item.product.creditPrice != null &&
                item.product.creditPrice! > 0
            ? item.product.creditPrice!
            : item.unitPrice;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                item.quantity.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(item.product.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${priceToShow.toStringAsFixed(2)} DA x ${item.quantity}'),
                if (_isCreditSale && item.product.creditPrice != null)
                  Text(
                    'Prix crédit appliqué',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  'Total: ${(priceToShow * item.quantity).toStringAsFixed(2)} DA',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => _updateQuantity(item, -1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${item.quantity}'),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _updateQuantity(item, 1),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeFromCart(item),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle pour vente à crédit
          SwitchListTile(
            title: const Text('Vente à crédit'),
            subtitle: Text(
              _isCreditSale ? 'Mode crédit activé' : 'Mode comptant',
            ),
            value: _isCreditSale,
            onChanged: (value) {
              setState(() {
                _isCreditSale = value;
                if (!value) {
                  _downPayment = 0.0;
                  _downPaymentController.clear();
                } else {
                  // Vérifier qu'un client est sélectionné pour le crédit
                  if (_selectedCustomer == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Veuillez sélectionner un client pour la vente à crédit',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    _isCreditSale = false;
                    return;
                  }
                }
                // Recalculer les prix du panier
                _updateCartPricesForCreditMode();
              });
            },
            activeColor: Colors.orange,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text('Vider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: _clearCart,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: Icon(_isCreditSale ? Icons.credit_card : Icons.payment),
                  label: Text(
                    _isCreditSale ? 'Vente Crédit' : 'Vente Comptant',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isCreditSale
                        ? Colors.orange
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: _cart.isEmpty ? null : _finalizeSale,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Méthodes d'interaction...

  void _scanBarcode() async {
    final scannerService = context.read<ScannerService>();

    if (!scannerService.isConnected) {
      // Try to connect a scanner
      final scanners = await scannerService.searchAvailableScanners();
      if (scanners.isNotEmpty) {
        if (!mounted) return;
        bool connected = await scannerService.connectToScanner(scanners.first);
        if (!connected) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de connecter le scanner')),
          );
          return;
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Aucun scanner trouvé')));
        return;
      }
    }

    // Scanner is connected, ask to scan
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanner prêt - Veuillez scanner un code-barres'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _selectCustomer() async {
    // Navigation vers la sélection de client ou dialogue simple
    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => _CustomerSelectionDialog(),
    );

    if (result != null) {
      setState(() {
        _selectedCustomer = result;
      });
    }
  }

  void _showDeviceSettings() {
    showDialog(context: context, builder: (context) => _DeviceSettingsDialog());
  }

  void _searchProducts(String query) {
    final productService = context.read<ProductService>();
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = [];
      });
    } else {
      setState(() {
        _filteredProducts = productService.products
            .where(
              (product) =>
                  product.name.toLowerCase().contains(query.toLowerCase()) ||
                  (product.brand?.toLowerCase().contains(query.toLowerCase()) ??
                      false) ||
                  (product.barcode?.contains(query) ?? false),
            )
            .toList();
      });
    }
  }

  void _addToCart(Product product) {
    if (product.quantity > 0) {
      // Utiliser le prix crédit si mode crédit activé et prix crédit disponible
      double priceToUse = product.sellPrice;
      if (_isCreditSale &&
          product.creditPrice != null &&
          product.creditPrice! > 0) {
        priceToUse = product.creditPrice!;
      }

      _cart.addItem(product, unitPrice: priceToUse); // تم تغيير هذا السطر
      setState(() {});

      // Son de succès
      SystemSound.play(SystemSoundType.click);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} ajouté au panier'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produit en rupture de stock'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // في الجزء الخاص بـ _processCashSale (حول السطر 917)
  void _processCashSale() async {
    try {
      final authService = context.read<AuthService>();
      final invoiceService = context.read<InvoiceService>();
      final printerService = context.read<UsbPrinterService>();

      if (authService.currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Utilisateur non connecté')),
        );
        return;
      }

      // Définir le type de paiement comme comptant
      _cart.setPaymentType(PaymentType.comptant); // تم تغيير هذا السطر
      _cart.setCustomer(_selectedCustomer); // تم تغيير هذا السطر

      // Créer la facture
      final success = await invoiceService.createInvoice(
        _cart,
        authService.currentUser!.id!,
        customer: _selectedCustomer,
      );

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la création de la facture'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;

      // Imprimer la facture si l'imprimante est connectée
      if (printerService.isConnected) {
        // Récupérer la facture créée pour l'impression
        final invoiceNumber = await invoiceService.generateInvoiceNumber();
        final invoice = await invoiceService.getInvoiceByNumber(invoiceNumber);
        if (invoice != null) {
          bool printed = await printerService.printInvoice(invoice);
          if (!printed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vente enregistrée mais erreur d\'impression'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vente comptant enregistrée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
      _resetSale();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _updateQuantity(CartItem item, int change) {
    final newQuantity = item.quantity + change;
    if (newQuantity > 0 && newQuantity <= item.product.quantity) {
      item.quantity = newQuantity;
      setState(() {});
    } else if (newQuantity <= 0) {
      _removeFromCart(item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantité insuffisante en stock')),
      );
    }
  }

  void _removeFromCart(CartItem item) {
    _cart.removeItem(item.product.id!);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.product.name} retiré du panier')),
    );
  }

  void _updateCartPricesForCreditMode() {
    if (_isCreditSale) {
      // Appliquer les prix crédit aux produits qui en ont
      for (var item in _cart.items) {
        if (item.product.creditPrice != null && item.product.creditPrice! > 0) {
          item.unitPrice = item.product.creditPrice!;
        }
      }
    } else {
      // Revenir aux prix normaux
      for (var item in _cart.items) {
        item.unitPrice = item.product.sellPrice;
      }
    }
    setState(() {});
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier'),
        content: const Text('Êtes-vous sûr de vouloir vider le panier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _cart.clear();
              setState(() {});
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Panier vidé')));
            },
            child: const Text('Vider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _finalizeSale() {
    if (_cart.isEmpty) return;

    if (_isCreditSale) {
      _showCreditSaleDialog();
    } else {
      _showCashSaleDialog();
    }
  }

  void _showCashSaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finaliser la vente comptant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Articles: ${_cart.totalItems}'),
            Text('Total: ${_cart.total.toStringAsFixed(2)} DA'),
            if (_selectedCustomer != null)
              Text('Client: ${_selectedCustomer!.name}'),
            const SizedBox(height: 16),
            const Text('Confirmer la vente comptant ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _processCashSale();
            },
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreditSaleDialog() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner un client pour la vente à crédit',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CreditSaleDialog(
        cart: _cart,
        customer: _selectedCustomer!,
        onConfirm: (duration, downPayment) {
          _creditDurationMonths = duration;
          _downPayment = downPayment;
          _processCreditSale();
        },
      ),
    );
  }

  void _processCreditSale() async {
    try {
      final authService = context.read<AuthService>();
      final invoiceService = context.read<InvoiceService>();
      final printerService = context.read<UsbPrinterService>();

      if (authService.currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Utilisateur non connecté')),
        );
        return;
      }

      if (_selectedCustomer == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client requis pour la vente à crédit')),
        );
        return;
      }

      // Calculer les détails du crédit
      final totalAmount = _cart.total;
      final financedAmount = totalAmount - _downPayment;
      final monthlyPayment = financedAmount / _creditDurationMonths;

      // Configurer le panier pour le crédit
      _cart.setPaymentType(PaymentType.credit); // تم تغيير هذا السطر
      _cart.setCustomer(_selectedCustomer); // تم تغيير هذا السطر
      _cart.setCreditSale(true); // تم تغيير هذا السطر
      _cart.setCreditDuration(_creditDurationMonths); // تم تغيير هذا السطر
      _cart.setMonthlyPayment(monthlyPayment); // تم تغيير هذا السطر
      _cart.setDownPayment(_downPayment); // تم تغيير هذا السطر

      // Créer la facture avec contrat de crédit
      final success = await invoiceService.createInvoice(
        _cart,
        authService.currentUser!.id!,
        customer: _selectedCustomer,
      );

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la création de la vente à crédit'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;

      // Imprimer la facture et le contrat si l'imprimante est connectée
      if (printerService.isConnected) {
        final invoiceNumber = await invoiceService.generateInvoiceNumber();
        final invoice = await invoiceService.getInvoiceByNumber(invoiceNumber);
        if (invoice != null) {
          bool printed = await printerService.printInvoice(invoice);
          if (!printed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vente enregistrée mais erreur d\'impression'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vente à crédit enregistrée!\n'
            'Mensualité: ${monthlyPayment.toStringAsFixed(2)} DA x $_creditDurationMonths mois',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      _resetSale();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _resetSale() {
    _cart.clear();
    _selectedCustomer = null;
    _isCreditSale = false;
    _downPayment = 0.0;
    _creditDurationMonths = 12;
    _downPaymentController.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _downPaymentController.dispose();
    super.dispose();
  }
}

// Dialogue de sélection de client
class _CustomerSelectionDialog extends StatefulWidget {
  @override
  State<_CustomerSelectionDialog> createState() =>
      _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      // Charger les clients depuis la base de données
      // Cette partie dépend de votre service de clients
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterCustomers(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = _customers;
      });
    } else {
      setState(() {
        _filteredCustomers = _customers
            .where(
              (customer) =>
                  customer.name.toLowerCase().contains(query.toLowerCase()) ||
                  (customer.phone?.contains(query) ?? false),
            )
            .toList();
      });
    }
  }

  void _createNewCustomer() {
    if (_nameController.text.isNotEmpty) {
      final newCustomer = Customer(
        name: _nameController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
      );
      Navigator.pop(context, newCustomer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélection Client'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Création d'un nouveau client
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nouveau client',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du client *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (optionnel)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _createNewCustomer,
                        child: const Text('Créer et sélectionner'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Recherche dans les clients existants
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Rechercher un client existant',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterCustomers,
            ),
            const SizedBox(height: 8),
            // Liste des clients
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Aucun client trouvé',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              customer.name.substring(0, 1).toUpperCase(),
                            ),
                          ),
                          title: Text(customer.name),
                          subtitle: customer.phone != null
                              ? Text(customer.phone!)
                              : null,
                          onTap: () => Navigator.pop(context, customer),
                        );
                      },
                    ),
            ),
            // Client Cash rapide
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.attach_money, color: Colors.white),
              ),
              title: const Text('Client Cash'),
              subtitle: const Text('Vente comptant sans client spécifique'),
              onTap: () =>
                  Navigator.pop(context, Customer(name: 'Client Cash')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// Dialogue de vente à crédit
class _CreditSaleDialog extends StatefulWidget {
  final Cart cart;
  final Customer customer;
  final Function(int duration, double downPayment) onConfirm;

  const _CreditSaleDialog({
    required this.cart,
    required this.customer,
    required this.onConfirm,
  });

  @override
  State<_CreditSaleDialog> createState() => _CreditSaleDialogState();
}

class _CreditSaleDialogState extends State<_CreditSaleDialog> {
  int _selectedDuration = 12;
  double _downPayment = 0.0;
  final TextEditingController _downPaymentController = TextEditingController();

  final List<int> _durationOptions = [3, 6, 12, 18, 24, 36];

  @override
  void initState() {
    super.initState();
    _downPaymentController.addListener(() {
      final value = double.tryParse(_downPaymentController.text) ?? 0.0;
      if (value != _downPayment) {
        setState(() {
          _downPayment = value;
        });
      }
    });
  }

  double get _financedAmount => widget.cart.total - _downPayment;
  double get _monthlyPayment => _financedAmount / _selectedDuration;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuration Vente à Crédit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations client et commande
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Client: ${widget.customer.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total commande: ${widget.cart.total.toStringAsFixed(2)} DA',
                    ),
                    Text('Articles: ${widget.cart.totalItems}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Durée du crédit
            const Text(
              'Durée du crédit (mois):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _durationOptions.map((duration) {
                return ChoiceChip(
                  label: Text('$duration mois'),
                  selected: _selectedDuration == duration,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDuration = duration;
                      });
                    }
                  },
                  selectedColor: Colors.blue.shade100,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Acompte
            const Text(
              'Acompte (optionnel):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _downPaymentController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant de l\'acompte',
                suffixText: 'DA',
                border: const OutlineInputBorder(),
                helperText:
                    'Maximum: ${widget.cart.total.toStringAsFixed(2)} DA',
              ),
            ),
            const SizedBox(height: 16),

            // Récapitulatif des calculs
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Récapitulatif:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total commande:'),
                        Text('${widget.cart.total.toStringAsFixed(2)} DA'),
                      ],
                    ),
                    if (_downPayment > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Acompte:'),
                          Text('${_downPayment.toStringAsFixed(2)} DA'),
                        ],
                      ),
                      const Divider(),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant financé:'),
                        Text(
                          '${_financedAmount.toStringAsFixed(2)} DA',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mensualité ($_selectedDuration mois):'),
                        Text(
                          '${_monthlyPayment.toStringAsFixed(2)} DA',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          onPressed: _downPayment > widget.cart.total
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onConfirm(_selectedDuration, _downPayment);
                },
          child: const Text('Confirmer Crédit'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _downPaymentController.dispose();
    super.dispose();
  }
}

// Dialogue des paramètres des appareils
class _DeviceSettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paramètres Appareils Smart'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scanner Smart
            Consumer<ScannerService>(
              builder: (context, scannerService, child) {
                return Card(
                  child: ListTile(
                    leading: Icon(
                      scannerService.isConnected
                          ? Icons.qr_code_scanner
                          : Icons.qr_code_scanner_outlined,
                      color: scannerService.isConnected
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: const Text('Scanner Smart'),
                    subtitle: Text(
                      scannerService.isConnected
                          ? 'Connecté: ${scannerService.connectedDevice?.productName ?? "Scanner Smart"}'
                          : 'Déconnecté - Recherche automatique...',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        if (scannerService.isConnected) {
                          await scannerService.disconnect();
                        } else {
                          final scanners = await scannerService
                              .searchAvailableScanners();
                          if (scanners.isNotEmpty) {
                            await scannerService.connectToScanner(
                              scanners.first,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Aucun scanner Smart trouvé'),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        scannerService.isConnected
                            ? 'Déconnecter'
                            : 'Connecter',
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Imprimante Smart
            Consumer<UsbPrinterService>(
              builder: (context, printerService, child) {
                return Card(
                  child: ListTile(
                    leading: Icon(
                      printerService.isConnected
                          ? Icons.print
                          : Icons.print_outlined,
                      color: printerService.isConnected
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: const Text('Imprimante Smart'),
                    subtitle: Text(
                      printerService.isConnected
                          ? 'Connectée: ${printerService.connectedDevice?.productName ?? "Imprimante Smart"}'
                          : 'Déconnectée - Recherche automatique...',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        if (printerService.isConnected) {
                          await printerService.disconnect();
                        } else {
                          final printers = await printerService
                              .searchAvailablePrinters();
                          if (printers.isNotEmpty) {
                            await printerService.connectToPrinter(
                              printers.first,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Aucune imprimante Smart trouvée',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        printerService.isConnected
                            ? 'Déconnecter'
                            : 'Connecter',
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Informations sur les appareils Smart
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Appareils Smart',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Scanner: Scan automatique des codes-barres\n'
                      '• Imprimante: Impression automatique des factures\n'
                      '• Connexion USB automatique au démarrage\n'
                      '• Status en temps réel',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Test d'impression
        Consumer<UsbPrinterService>(
          builder: (context, printerService, child) {
            return TextButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('Test Impression'),
              onPressed: printerService.isConnected
                  ? () async {
                      await printerService.testPrint();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Test d\'impression envoyé à l\'imprimante Smart',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  : null,
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
