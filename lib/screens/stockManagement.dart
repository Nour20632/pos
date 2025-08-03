import 'package:flutter/material.dart';
import 'package:mk_optique/models.dart';
import 'package:mk_optique/services.dart';
import 'package:provider/provider.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion du Stock'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inventory), text: 'Stock'),
            Tab(icon: Icon(Icons.warning), text: 'Alertes'),
            Tab(icon: Icon(Icons.history), text: 'Mouvements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildStockTab(), _buildAlertsTab(), _buildMovementsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStockAdjustmentDialog,
        icon: const Icon(Icons.edit),
        label: const Text('Ajuster Stock'),
        backgroundColor: Colors.teal.shade600,
      ),
    );
  }

  Widget _buildStockTab() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: Consumer<ProductService>(
            builder: (context, productService, child) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: productService.products.length,
                itemBuilder: (context, index) {
                  final product = productService.products[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStockStatusColor(product),
                        child: Text(
                          '${product.quantity}',
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
                          Text(
                            'Seuil d\'alerte: ${product.minStockAlert}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _showQuantityDialog(product, false),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.green,
                            ),
                            onPressed: () => _showQuantityDialog(product, true),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    return Consumer<ProductService>(
      builder: (context, productService, child) {
        final lowStockProducts = productService.getLowStockProducts();

        if (lowStockProducts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'Aucune alerte de stock',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: lowStockProducts.length,
          itemBuilder: (context, index) {
            final product = lowStockProducts[index];
            return Card(
              color: product.quantity == 0
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              child: ListTile(
                leading: Icon(
                  product.quantity == 0 ? Icons.error : Icons.warning,
                  color: product.quantity == 0 ? Colors.red : Colors.orange,
                ),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  product.quantity == 0
                      ? 'Rupture de stock'
                      : 'Stock faible: ${product.quantity} restant(s)',
                ),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Réapprovisionner'),
                  onPressed: () => _showQuantityDialog(product, true),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMovementsTab() {
    return Consumer<StockService>(
      builder: (context, stockService, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stockService.recentMovements.length,
          itemBuilder: (context, index) {
            final movement = stockService.recentMovements[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getMovementColor(movement.movementType),
                  child: Icon(
                    _getMovementIcon(movement.movementType),
                    color: Colors.white,
                  ),
                ),
                title: Text(movement.reason ?? 'Mouvement de stock'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantité: ${movement.quantity}'),
                    Text(
                      '${movement.quantityBefore} → ${movement.quantityAfter}',
                    ),
                    Text(movement.createdAt.toString().split('.')[0]),
                  ],
                ),
                trailing: Text(
                  movement.movementType.name.toUpperCase(),
                  style: TextStyle(
                    color: _getMovementColor(movement.movementType),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
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
        decoration: InputDecoration(
          hintText: 'Rechercher un produit...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Color _getStockStatusColor(Product product) {
    if (product.quantity == 0) return Colors.red;
    if (product.isLowStock) return Colors.orange;
    return Colors.green;
  }

  Color _getMovementColor(StockMovementType type) {
    switch (type) {
      case StockMovementType.entree:
      case StockMovementType.retour:
        return Colors.green;
      case StockMovementType.sortie:
        return Colors.red;
      case StockMovementType.ajustement:
        return Colors.blue;
    }
  }

  IconData _getMovementIcon(StockMovementType type) {
    switch (type) {
      case StockMovementType.entree:
        return Icons.arrow_upward;
      case StockMovementType.sortie:
        return Icons.arrow_downward;
      case StockMovementType.retour:
        return Icons.undo;
      case StockMovementType.ajustement:
        return Icons.tune;
    }
  }

  void _showQuantityDialog(Product product, bool isAddition) {
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAddition ? 'Ajouter du Stock' : 'Retirer du Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Produit: ${product.name}'),
            Text('Stock actuel: ${product.quantity}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantité',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif',
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
            onPressed: () => _updateStock(
              product,
              quantityController.text,
              reasonController.text,
              isAddition,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showStockAdjustmentDialog() {
    // Implementation pour l'ajustement de stock
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonction d\'ajustement de stock à implémenter'),
      ),
    );
  }

  void _updateStock(
    Product product,
    String quantityStr,
    String reason,
    bool isAddition,
  ) async {
    final quantity = int.tryParse(quantityStr);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quantité invalide')));
      return;
    }

    final stockService = context.read<StockService>();
    final authService = context.read<AuthService>();
    final printerService = context.read<PrinterService>();

    Future<bool> result;
    if (isAddition) {
      result = stockService.addStock(
        product,
        quantity,
        null,
        reason.isEmpty ? 'Réapprovisionnement' : reason,
        authService.currentUser!.id!,
      );

      // Print labels for added stock
      if (printerService.isConnected) {
        for (int i = 0; i < quantity; i++) {
          await printerService.printBarcode(product);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$quantity étiquettes imprimées')),
        );
      }
    } else {
      result = stockService.removeStock(
        product,
        quantity,
        reason.isEmpty ? 'Sortie manuelle' : reason,
        authService.currentUser!.id!,
      );
    }

    result.then((success) {
      Navigator.pop(context);
      if (success) {
        context.read<ProductService>().loadProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock ${isAddition ? 'ajouté' : 'retiré'} avec succès',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la modification du stock'),
          ),
        );
      }
    });
  }
}
