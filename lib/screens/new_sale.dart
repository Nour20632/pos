import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/models.dart';
import 'package:mk_optique/services.dart';
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
  String _saleType = 'general'; // 'general' or 'optical'
  Customer? _selectedCustomer;

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
    final scannerService = context.read<UsbScannerService>();
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
    final scannerService = context.read<UsbScannerService>();

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
    return Consumer3<ProductService, UsbScannerService, UsbPrinterService>(
      builder: (context, productService, scannerService, printerService, _) {
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
                // Fix overflow
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
              _buildSaleTypeSelector(),
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
      title: Text(_saleType == 'optical' ? 'Vente Optique' : 'Nouvelle Vente'),
      backgroundColor: _saleType == 'optical'
          ? Colors.purple.shade800
          : Colors.blue.shade800,
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

  Widget _buildSaleTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _saleType == 'optical'
              ? [Colors.purple.shade50, Colors.purple.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Type de vente:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'general',
                  label: Text('Général'),
                  icon: Icon(Icons.shopping_cart),
                ),
                ButtonSegment(
                  value: 'optical',
                  label: Text('Optique'),
                  icon: Icon(Icons.visibility),
                ),
              ],
              selected: {_saleType},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _saleType = selection.first;
                  _cart.clear(); // Vider le panier lors du changement de type
                });
              },
            ),
          ),
        ],
      ),
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
          suffixIcon: Consumer<UsbScannerService>(
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
    return Consumer2<UsbScannerService, UsbPrinterService>(
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
                    if (product.barcode != null)
                      Text(
                        'Code: ${product.barcode}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (product.hasPrescription && _saleType == 'optical')
                      const Icon(Icons.visibility, color: Colors.purple),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () => _addToCart(product),
                    ),
                  ],
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
    Color primaryColor = _saleType == 'optical'
        ? Colors.purple.shade600
        : Colors.blue.shade600;
    Color secondaryColor = _saleType == 'optical'
        ? Colors.purple.shade800
        : Colors.blue.shade800;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
        boxShadow: [
          // Replace deprecated withOpacity with withAlpha (0.3*255 ~ 77)
          BoxShadow(color: primaryColor.withAlpha(77), blurRadius: 8),
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
              color: _saleType == 'optical'
                  ? Colors.purple.shade300
                  : Colors.blue.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Panier vide',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              _saleType == 'optical'
                  ? 'Scanner ou ajouter des produits optiques'
                  : 'Scanner ou ajouter des produits',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cart.items.length,
      itemBuilder: (context, index) {
        final item = _cart.items[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _saleType == 'optical'
                  ? Colors.purple
                  : Colors.blue,
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
                Text(
                  '${item.unitPrice.toStringAsFixed(2)} DA x ${item.quantity}',
                ),
                Text(
                  'Total: ${(item.unitPrice * item.quantity).toStringAsFixed(2)} DA',
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
    Color primaryColor = _saleType == 'optical' ? Colors.purple : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
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
              icon: Icon(
                _saleType == 'optical' ? Icons.visibility : Icons.payment,
              ),
              label: Text(
                _saleType == 'optical' ? 'Vente Optique' : 'Finaliser Vente',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
              onPressed: _cart.isEmpty ? null : _finalizeSale,
            ),
          ),
        ],
      ),
    );
  }

  // Méthodes d'interaction...

  void _scanBarcode() async {
    final scannerService = context.read<UsbScannerService>();

    if (!scannerService.isConnected) {
      // Try to connect a scanner
      final scanners = await scannerService.searchAvailableScanners();
      if (scanners.isNotEmpty) {
        if (!mounted) return; // Add mounted check
        bool connected = await scannerService.connectToScanner(scanners.first);
        if (!connected) {
          if (!mounted) return; // Add mounted check
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de connecter le scanner')),
          );
          return;
        }
      } else {
        if (!mounted) return; // Add mounted check
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Aucun scanner trouvé')));
        return;
      }
    }

    // Scanner is connected, ask to scan
    if (!mounted) return; // Add mounted check
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
      _cart.addItem(product);
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

    if (_saleType == 'optical') {
      _showOpticalSaleDialog();
    } else {
      _showGeneralSaleDialog();
    }
  }

  void _showGeneralSaleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finaliser la vente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Articles: ${_cart.totalItems}'),
            Text('Total: ${_cart.total.toStringAsFixed(2)} DA'),
            if (_selectedCustomer != null)
              Text('Client: ${_selectedCustomer!.name}'),
            const SizedBox(height: 16),
            const Text('Confirmer la vente ?'),
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
              _processGeneralSale();
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

  void _showOpticalSaleDialog() {
    // Navigation vers l'écran de vente optique détaillée
    context.push(
      '/optical-sale',
      extra: {'cart': _cart, 'customer': _selectedCustomer},
    );
  }

  void _processGeneralSale() async {
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

      // Créer la facture - utiliser la méthode createInvoiceWithCustomer qui retourne Invoice?
      final invoice = await invoiceService.createInvoiceWithCustomer(
        cart: _cart,
        userId: authService.currentUser!.id!.toString(),
        customer: _selectedCustomer,
      );

      if (invoice == null) {
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vente enregistrée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
      _cart.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

// Dialogue de sélection de client
class _CustomerSelectionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélection Client'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Nom du client',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (name) {
                if (name.isNotEmpty) {
                  Navigator.pop(context, Customer(name: name));
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('ou sélectionner un client existant:'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('Client Cash'),
                    onTap: () =>
                        Navigator.pop(context, Customer(name: 'Client Cash')),
                  ),
                  // Ajouter d'autres clients de la base de données
                ],
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
      ],
    );
  }
}

// Dialogue des paramètres des appareils
class _DeviceSettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paramètres Appareils'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer<UsbScannerService>(
              builder: (context, scannerService, child) {
                return ListTile(
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
                        : 'Déconnecté',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      if (scannerService.isConnected) {
                        await scannerService.disconnect();
                      } else {
                        final scanners = await scannerService
                            .searchAvailableScanners();
                        if (scanners.isNotEmpty) {
                          await scannerService.connectToScanner(scanners.first);
                        }
                      }
                    },
                    child: Text(
                      scannerService.isConnected ? 'Déconnecter' : 'Connecter',
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            Consumer<UsbPrinterService>(
              builder: (context, printerService, child) {
                return ListTile(
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
                        : 'Déconnectée',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      if (printerService.isConnected) {
                        await printerService.disconnect();
                      } else {
                        final printers = await printerService
                            .searchAvailablePrinters();
                        if (printers.isNotEmpty) {
                          await printerService.connectToPrinter(printers.first);
                        }
                      }
                    },
                    child: Text(
                      printerService.isConnected ? 'Déconnecter' : 'Connecter',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        Consumer<UsbPrinterService>(
          builder: (context, printerService, child) {
            return TextButton(
              onPressed: printerService.isConnected
                  ? () async {
                      await printerService.testPrint();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test d\'impression envoyé'),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Test Impression'),
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
