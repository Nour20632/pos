import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/app_drawer.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  List<Product> _filteredProducts = [];
  String _searchQuery = '';

  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      context.read<ProductService>().loadProducts();
      _didLoad = true;
    }
  }

  void _loadProducts() {
    final productService = context.read<ProductService>();
    setState(() {
      _filteredProducts = productService.products;
    });
    _filterProducts();
  }

  void _filterProducts() {
    final products = context.read<ProductService>().products;
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredProducts = products;
      } else {
        _filteredProducts = products
            .where(
              (p) =>
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (p.barcode?.contains(_searchQuery) ?? false) ||
                  (p.brand?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanProduct,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/products/add'),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            color: AppColors.surface,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher produits...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterProducts();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterProducts();
              },
            ),
          ),

          // Liste des produits
          Expanded(
            child: Consumer<ProductService>(
              builder: (context, productService, child) {
                if (productService.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Aucun produit trouvé'
                              : 'Aucun résultat pour "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/products/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getStockColor(product).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.inventory_2, color: _getStockColor(product)),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null)
              Text(
                '${product.brand} - ${product.sellPrice.toStringAsFixed(2)} DA',
              ),
            Text(
              'Stock: ${product.quantity} | ${_getStockStatus(product)}',
              style: TextStyle(
                color: _getStockColor(product),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, product),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Modifier'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'stock',
              child: ListTile(
                leading: Icon(Icons.add_box),
                title: Text('Ajuster Stock'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'label',
              child: ListTile(
                leading: Icon(Icons.label),
                title: Text('Imprimer Étiquette'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => context.go('/products/edit/${product.id}'),
      ),
    );
  }

  Color _getStockColor(Product product) {
    if (product.quantity == 0) return AppColors.error;
    if (product.isLowStock) return AppColors.warning;
    return AppColors.success;
  }

  String _getStockStatus(Product product) {
    if (product.quantity == 0) return 'En rupture';
    if (product.isLowStock) return 'Stock bas';
    return 'Stock normal';
  }

  void _handleMenuAction(String action, Product product) {
    switch (action) {
      case 'edit':
        context.go('/products/edit/${product.id}');
        break;
      case 'stock':
        _showStockDialog(product);
        break;
      case 'label':
        _printLabel(product);
        break;
    }
  }

  void _showStockDialog(Product product) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajuster Stock - ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock actuel: ${product.quantity}'),
            const SizedBox(height: AppDimensions.paddingM),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nouvelle quantité',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(quantityController.text);
              if (newQty != null) {
                _adjustStock(product, newQty);
                Navigator.pop(context);
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustStock(Product product, int newQuantity) async {
    final stockService = context.read<StockService>();
    final authService = context.read<AuthService>();

    final success = await stockService.adjustStock(
      product,
      newQuantity,
      'Ajustement manuel',
      authService.currentUser!.id!,
    );

    if (success) {
      await context.read<ProductService>().loadProducts();
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock ajusté avec succès')),
        );
      }
    }
  }

  Future<void> _printLabel(Product product) async {
    final printerService = context.read<PrinterService>();
    if (!printerService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune imprimante connectée')),
      );
      return;
    }

    final success = await printerService.printBarcode(product);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Étiquette imprimée avec succès'
                : 'Erreur lors de l\'impression',
          ),
        ),
      );
    }
  }

  Future<void> _scanProduct() async {
    final scannerService = context.read<ScannerService>();
    final barcode = await scannerService.scanBarcode();

    if (barcode != null && mounted) {
      final product = await context.read<ProductService>().getProductByBarcode(
        barcode,
      );
      if (product != null) {
        setState(() {
          _filteredProducts = [product];
          _searchController.text = barcode;
          _searchQuery = barcode;
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Produit non trouvé')));
      }
    }
  }
}
