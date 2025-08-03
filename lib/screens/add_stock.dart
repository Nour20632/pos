import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';
import '../services.dart';

class AddStockScreen extends StatefulWidget {
  final Product? product;

  const AddStockScreen({super.key, this.product});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitCostController = TextEditingController();
  final _reasonController = TextEditingController();

  Product? _selectedProduct;
  bool _isLoading = false;
  List<Product> _searchResults = [];
  String _movementType = 'entree'; // 'entree', 'sortie', 'ajustement'

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _selectedProduct = widget.product;
      _searchController.text = widget.product!.name;
      _unitCostController.text = widget.product!.costPrice?.toString() ?? '';
    }
    _reasonController.text = 'Ajout de stock';
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final results = await context.read<ProductService>().searchProducts(query);
    setState(() => _searchResults = results);
  }

  Future<void> _scanProductBarcode() async {
    final scannerService = context.read<ScannerService>();
    final barcode = await scannerService.scanBarcode();

    if (barcode != null && mounted) {
      final product = await context.read<ProductService>().getProductByBarcode(
        barcode,
      );

      if (product != null) {
        setState(() {
          _selectedProduct = product;
          _searchController.text = product.name;
          _unitCostController.text = product.costPrice?.toString() ?? '';
          _searchResults = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produit trouvé: ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produit non trouvé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printLabels(int quantity) async {
    if (_selectedProduct == null) return;

    final printerService = context.read<PrinterService>();
    if (!printerService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune imprimante connectée'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      for (int i = 0; i < quantity; i++) {
        await printerService.printBarcode(_selectedProduct!);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$quantity étiquette(s) imprimée(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur d\'impression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion du Stock'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanProductBarcode,
            tooltip: 'Scanner produit',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type de mouvement
              _buildSectionTitle('Type de mouvement'),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Entrée de stock'),
                      subtitle: const Text('Ajouter des produits au stock'),
                      value: 'entree',
                      groupValue: _movementType,
                      onChanged: (value) => setState(() {
                        _movementType = value!;
                        _reasonController.text = 'Ajout de stock';
                      }),
                    ),
                    RadioListTile<String>(
                      title: const Text('Sortie de stock'),
                      subtitle: const Text('Retirer des produits du stock'),
                      value: 'sortie',
                      groupValue: _movementType,
                      onChanged: (value) => setState(() {
                        _movementType = value!;
                        _reasonController.text = 'Sortie de stock';
                      }),
                    ),
                    RadioListTile<String>(
                      title: const Text('Ajustement'),
                      subtitle: const Text('Corriger la quantité en stock'),
                      value: 'ajustement',
                      groupValue: _movementType,
                      onChanged: (value) => setState(() {
                        _movementType = value!;
                        _reasonController.text = 'Ajustement inventaire';
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),

              // Recherche/Sélection du produit
              _buildSectionTitle('Sélection du produit'),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Rechercher un produit',
                  hintText: 'Nom, code-barres, marque...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _selectedProduct != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _selectedProduct = null;
                              _searchController.clear();
                              _searchResults = [];
                            });
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _scanProductBarcode,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _searchProducts,
                validator: (value) => _selectedProduct == null
                    ? 'Veuillez sélectionner un produit'
                    : null,
              ),

              // Résultats de recherche
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final product = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(
                              product.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.brand != null)
                                Text('Marque: ${product.brand}'),
                              Text(
                                'Stock: ${product.quantity} | Prix: ${product.sellPrice.toStringAsFixed(2)} DA',
                              ),
                              if (product.barcode != null)
                                Text(
                                  'Code: ${product.barcode}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _selectedProduct = product;
                              _searchController.text = product.name;
                              _unitCostController.text =
                                  product.costPrice?.toString() ?? '';
                              _searchResults = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Produit sélectionné
              if (_selectedProduct != null) ...[
                const SizedBox(height: AppDimensions.paddingM),
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Produit sélectionné',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedProduct!.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedProduct!.brand != null)
                          Text('Marque: ${_selectedProduct!.brand}'),
                        Text('Stock actuel: ${_selectedProduct!.quantity}'),
                        Text(
                          'Prix de vente: ${_selectedProduct!.sellPrice.toStringAsFixed(2)} DA',
                        ),
                        if (_selectedProduct!.barcode != null)
                          Text('Code-barres: ${_selectedProduct!.barcode}'),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppDimensions.paddingXL),

              // Détails du mouvement
              _buildSectionTitle('Détails du mouvement'),

              if (_movementType == 'ajustement') ...[
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: 'Nouvelle quantité *',
                    hintText: 'Quantité finale souhaitée',
                    prefixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Quantité requise';
                    if (int.tryParse(value!) == null)
                      return 'Quantité invalide';
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText: _movementType == 'entree'
                        ? 'Quantité à ajouter *'
                        : 'Quantité à retirer *',
                    hintText: 'Nombre d\'unités',
                    prefixIcon: Icon(
                      _movementType == 'entree' ? Icons.add : Icons.remove,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Quantité requise';
                    final qty = int.tryParse(value!);
                    if (qty == null || qty <= 0) return 'Quantité invalide';

                    if (_movementType == 'sortie' && _selectedProduct != null) {
                      if (qty > _selectedProduct!.quantity) {
                        return 'Stock insuffisant (disponible: ${_selectedProduct!.quantity})';
                      }
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: AppDimensions.paddingM),

              if (_movementType == 'entree') ...[
                TextFormField(
                  controller: _unitCostController,
                  decoration: InputDecoration(
                    labelText: 'Prix unitaire d\'achat',
                    hintText: 'Coût par unité (optionnel)',
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: 'DA',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppDimensions.paddingM),
              ],

              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Motif',
                  hintText: 'Raison du mouvement de stock',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.isEmpty == true ? 'Motif requis' : null,
              ),

              const SizedBox(height: AppDimensions.paddingXL),

              // Options d'impression
              if (_movementType == 'entree') ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.print, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Options d\'impression',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Imprimer automatiquement les étiquettes pour les nouveaux articles ajoutés',
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _selectedProduct != null
                              ? () => _showPrintDialog()
                              : null,
                          icon: const Icon(Icons.print),
                          label: const Text('Imprimer étiquettes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingXL),
              ],

              // Boutons d'action
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              final goRouter = GoRouter.of(context);
              if (goRouter.canPop()) {
                goRouter.pop();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
            ),
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _executeStockMovement,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(AppDimensions.paddingM),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_getActionButtonText()),
          ),
        ),
      ],
    );
  }

  String _getActionButtonText() {
    switch (_movementType) {
      case 'entree':
        return 'Ajouter au stock';
      case 'sortie':
        return 'Retirer du stock';
      case 'ajustement':
        return 'Ajuster le stock';
      default:
        return 'Confirmer';
    }
  }

  void _showPrintDialog() {
    final quantityController = TextEditingController(
      text: _quantityController.text,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imprimer étiquettes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Combien d\'étiquettes voulez-vous imprimer ?'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Nombre d\'étiquettes',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                Navigator.pop(context);
                _printLabels(quantity);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Imprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeStockMovement() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stockService = context.read<StockService>();
      final authService = context.read<AuthService>();
      final productService = context.read<ProductService>();

      final quantity = int.parse(_quantityController.text);
      final unitCost = _unitCostController.text.isNotEmpty
          ? double.parse(_unitCostController.text)
          : null;
      final reason = _reasonController.text.trim();
      final userId = authService.currentUser!.id!;

      bool success = false;

      switch (_movementType) {
        case 'entree':
          success = await stockService.addStock(
            _selectedProduct!,
            quantity,
            unitCost,
            reason,
            userId,
          );
          break;
        case 'sortie':
          success = await stockService.removeStock(
            _selectedProduct!,
            quantity,
            reason,
            userId,
          );
          break;
        case 'ajustement':
          success = await stockService.adjustStock(
            _selectedProduct!,
            quantity,
            reason,
            userId,
          );
          break;
      }

      if (mounted) {
        if (success) {
          // Recharger les données du produit
          await productService.loadProducts();

          // Imprimer les étiquettes si c'est une entrée
          if (_movementType == 'entree') {
            final shouldPrint = await _showPrintConfirmationDialog(quantity);
            if (shouldPrint) {
              await _printLabels(quantity);
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getSuccessMessage()),
              backgroundColor: Colors.green,
            ),
          );

          final goRouter = GoRouter.of(context);
          if (goRouter.canPop()) {
            goRouter.pop();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erreur lors de l\'opération'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showPrintConfirmationDialog(int quantity) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Imprimer étiquettes'),
            content: Text(
              'Voulez-vous imprimer $quantity étiquette(s) pour ce produit ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Non'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Oui'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _getSuccessMessage() {
    switch (_movementType) {
      case 'entree':
        return 'Stock ajouté avec succès';
      case 'sortie':
        return 'Stock retiré avec succès';
      case 'ajustement':
        return 'Stock ajusté avec succès';
      default:
        return 'Opération terminée avec succès';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _unitCostController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}
