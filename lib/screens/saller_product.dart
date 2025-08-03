import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';
import '../services.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  String _selectedCategory = 'Toutes';
  bool _showOnlyAvailable = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      context.read<ProductService>().loadProducts();
      _didLoad = true;
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final products = context.read<ProductService>().products;
    setState(() {
      _filteredProducts = products.where((product) {
        // Filter by search query
        final matchesSearch =
            _searchQuery.isEmpty ||
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (product.barcode?.contains(_searchQuery) ?? false) ||
            (product.brand?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);

        // Filter by category
        final matchesCategory =
            _selectedCategory == 'Toutes' ||
            product.category?.name == _selectedCategory;

        // Filter by availability
        final matchesAvailability = !_showOnlyAvailable || product.quantity > 0;

        return matchesSearch && matchesCategory && matchesAvailability;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Consumer<ProductService>(
        builder: (context, productService, child) {
          if (productService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            );
          }

          if (productService.products.isEmpty) {
            return _buildEmptyState();
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildSearchAndFilters(),
                _buildCategoryTabs(),
                Expanded(child: _buildProductsList()),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Catalogue Produits',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.go('/seller-dashboard'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _scanProduct,
          tooltip: 'Scanner produit',
        ),
        IconButton(
          icon: Icon(
            _showOnlyAvailable ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _showOnlyAvailable = !_showOnlyAvailable;
            });
            _filterProducts();
          },
          tooltip: _showOnlyAvailable
              ? 'Afficher tous'
              : 'Produits disponibles',
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E3A8A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Rechercher produits...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterProducts();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterProducts();
              },
            ),
          ),
          const SizedBox(height: 16),

          // Filter toggle
          Row(
            children: [
              Icon(
                _showOnlyAvailable
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _showOnlyAvailable
                    ? 'Produits disponibles uniquement'
                    : 'Tous les produits',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = [
      'Toutes',
      'Verres de Vue',
      'Verres Solaires',
      'Montures Vue',
      'Montures Solaires',
      'Lentilles',
      'Accessoires',
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
                _filterProducts();
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF3B82F6),
              checkmarkColor: Colors.white,
              elevation: isSelected ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsList() {
    if (_filteredProducts.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsState();
    }

    final productsToShow = _filteredProducts.isEmpty
        ? context.read<ProductService>().products
        : _filteredProducts;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: productsToShow.length,
      itemBuilder: (context, index) {
        final product = productsToShow[index];
        return _buildProductCard(product, index);
      },
    );
  }

  Widget _buildProductCard(Product product, int index) {
    final isOutOfStock = product.quantity == 0;
    final isLowStock = product.isLowStock && !isOutOfStock;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _animationController.value) * 50),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isOutOfStock
                      ? Colors.red.withOpacity(0.3)
                      : isLowStock
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.transparent,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isOutOfStock
                        ? null
                        : () => _showProductDetails(product),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Product Image/Icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _getStockColor(product).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getProductIcon(product.category?.name),
                              color: _getStockColor(product),
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Product Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isOutOfStock
                                        ? Colors.grey
                                        : const Color(0xFF1E3A8A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (product.brand != null)
                                  Text(
                                    product.brand!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStockColor(
                                          product,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStockStatus(product),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getStockColor(product),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${product.sellPrice.toStringAsFixed(2)} DA',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Action Button
                          if (!isOutOfStock)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                color: Color(0xFF3B82F6),
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun produit disponible',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Le catalogue sera mis à jour prochainement',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun résultat trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez avec d\'autres mots-clés',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              _searchQuery = '';
              _selectedCategory = 'Toutes';
              _filterProducts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Réinitialiser les filtres'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getStockColor(Product product) {
    if (product.quantity == 0) return Colors.red;
    if (product.isLowStock) return Colors.orange;
    return Colors.green;
  }

  String _getStockStatus(Product product) {
    if (product.quantity == 0) return 'Rupture';
    if (product.isLowStock) return 'Stock bas';
    return 'Disponible';
  }

  IconData _getProductIcon(String? categoryName) {
    switch (categoryName) {
      case 'Verres de Vue':
      case 'Verres Solaires':
        return Icons.visibility;
      case 'Montures Vue':
      case 'Montures Solaires':
        return Icons.face_retouching_natural;
      case 'Lentilles':
        return Icons.lens;
      case 'Accessoires':
        return Icons.shopping_bag;
      case 'Montres':
        return Icons.watch;
      default:
        return Icons.inventory_2;
    }
  }

  void _showProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _getProductIcon(product.category?.name),
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(product.name, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null) ...[
              _buildDetailItem('Marque', product.brand!),
              const SizedBox(height: 12),
            ],
            _buildDetailItem(
              'Prix de vente',
              '${product.sellPrice.toStringAsFixed(2)} DA',
            ),
            const SizedBox(height: 12),
            _buildDetailItem(
              'Catégorie',
              product.category?.name ?? 'Non définie',
            ),
            const SizedBox(height: 12),
            _buildDetailItem('Statut', _getStockStatus(product)),
            if (product.barcode != null) ...[
              const SizedBox(height: 12),
              _buildDetailItem('Code-barres', product.barcode!),
            ],
            if (product.description != null &&
                product.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailItem('Description', product.description!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _scanProduct() async {
    try {
      final scannerService = context.read<ScannerService>();
      final barcode = await scannerService.scanBarcode();

      if (barcode != null && mounted) {
        final product = await context
            .read<ProductService>()
            .getProductByBarcode(barcode);
        if (product != null) {
          setState(() {
            _filteredProducts = [product];
            _searchController.text = barcode;
            _searchQuery = barcode;
          });
          _showProductDetails(product);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produit non trouvé'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du scan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
