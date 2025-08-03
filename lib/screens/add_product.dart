import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';
import '../services.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _sizeController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController();
  final _descriptionController = TextEditingController();

  Category? _selectedCategory;
  bool _hasPrescription = false;
  bool _isLoading = false;
  String _inputMethod = ''; // 'manual' ou 'scanner'

  @override
  void initState() {
    super.initState();
    _generateBarcode();
    _minStockController.text = '5';
    _quantityController.text = '0';
    // Afficher le dialogue de méthode d'entrée
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInputMethodDialog();
    });
  }

  Future<void> _generateBarcode() async {
    final barcode = await context.read<ProductService>().generateBarcode();
    _barcodeController.text = barcode;
  }

  void _showInputMethodDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Méthode de saisie',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Comment souhaitez-vous ajouter ce produit ?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            _buildMethodTile(
              icon: Icons.edit,
              title: 'Saisie manuelle',
              subtitle: 'Saisir les informations manuellement',
              onTap: () {
                _inputMethod = 'manual';
                Navigator.pop(context);
                _prepareManualInput();
              },
            ),
            const SizedBox(height: 12),
            _buildMethodTile(
              icon: Icons.qr_code_scanner,
              title: 'Scanner code-barres',
              subtitle: 'Scanner le code-barres existant',
              onTap: () {
                _inputMethod = 'scanner';
                Navigator.pop(context);
                _scanExistingBarcode();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  void _prepareManualInput() {
    // Mode saisie manuelle - garder le code-barres généré
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mode saisie manuelle activé'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _scanExistingBarcode() async {
    final scannerService = context.read<ScannerService>();
    final scannedCode = await scannerService.scanBarcode();

    if (scannedCode != null && mounted) {
      _barcodeController.text = scannedCode;

      // Vérifier si le produit existe déjà
      final existingProduct = await context
          .read<ProductService>()
          .getProductByBarcode(scannedCode);

      if (existingProduct != null && mounted) {
        _showExistingProductDialog(existingProduct);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code-barres scanné avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showExistingProductDialog(Product existingProduct) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Produit existant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ce produit existe déjà :'),
            const SizedBox(height: 8),
            Text(
              existingProduct.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Prix: ${existingProduct.sellPrice.toStringAsFixed(2)} DA'),
            Text('Stock: ${existingProduct.quantity}'),
            const SizedBox(height: 16),
            const Text('Que souhaitez-vous faire ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generateBarcode(); // Générer nouveau code
            },
            child: const Text('Nouveau code'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Aller à l'écran d'ajout de stock
              _goToAddStock(existingProduct);
            },
            child: const Text('Ajouter stock'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _fillExistingProductData(existingProduct);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _fillExistingProductData(Product product) {
    _nameController.text = product.name;
    _brandController.text = product.brand ?? '';
    _modelController.text = product.model ?? '';
    _colorController.text = product.color ?? '';
    _sizeController.text = product.size ?? '';
    _sellPriceController.text = product.sellPrice.toString();
    _costPriceController.text = product.costPrice?.toString() ?? '';
    _quantityController.text = product.quantity.toString();
    _minStockController.text = product.minStockAlert.toString();
    _descriptionController.text = product.description ?? '';
    _selectedCategory = product.category;
    _hasPrescription = product.hasPrescription;
  }

  void _goToAddStock(Product product) {
    // Navigation vers l'écran d'ajout de stock
    context.push('/add-stock', extra: product);
  }

  Future<void> _printLabels(int quantity) async {
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

    final product = Product(
      name: _nameController.text,
      barcode: _barcodeController.text,
      sellPrice: double.tryParse(_sellPriceController.text) ?? 0,
      brand: _brandController.text.isNotEmpty ? _brandController.text : null,
      model: _modelController.text.isNotEmpty ? _modelController.text : null,
      color: _colorController.text.isNotEmpty ? _colorController.text : null,
      size: _sizeController.text.isNotEmpty ? _sizeController.text : null,
    );

    try {
      for (int i = 0; i < quantity; i++) {
        await printerService.printBarcode(product);
        // Petit délai entre les impressions
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
        title: const Text('Ajouter Produit'),
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
            onPressed: _scanExistingBarcode,
            tooltip: 'Scanner code-barres',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _showPrintDialog(),
            tooltip: 'Imprimer étiquettes',
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
              // Méthode d'entrée sélectionnée
              if (_inputMethod.isNotEmpty)
                Card(
                  color: AppColors.primary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          _inputMethod == 'manual'
                              ? Icons.edit
                              : Icons.qr_code_scanner,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _inputMethod == 'manual'
                              ? 'Mode: Saisie manuelle'
                              : 'Mode: Scanner activé',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _showInputMethodDialog,
                          child: const Text('Changer'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppDimensions.paddingM),

              // Informations de base
              _buildSectionTitle('Informations de base'),
              _buildTextField(
                controller: _nameController,
                label: 'Nom du produit *',
                icon: Icons.inventory_2,
                validator: (value) =>
                    value?.isEmpty == true ? 'Nom requis' : null,
              ),
              const SizedBox(height: AppDimensions.paddingM),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _barcodeController,
                      label: 'Code-barres',
                      icon: Icons.qr_code,
                      readOnly: false,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _generateBarcode,
                    tooltip: 'Générer nouveau code',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Catégorie
              Consumer<ProductService>(
                builder: (context, productService, child) {
                  return DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Catégorie',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: productService.categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.name),
                      );
                    }).toList(),
                    onChanged: (category) =>
                        setState(() => _selectedCategory = category),
                  );
                },
              ),
              const SizedBox(height: AppDimensions.paddingXL),

              // Détails produit
              _buildSectionTitle('Détails du produit'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _brandController,
                      label: 'Marque',
                      icon: Icons.business,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: _buildTextField(
                      controller: _modelController,
                      label: 'Modèle',
                      icon: Icons.model_training,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _colorController,
                      label: 'Couleur',
                      icon: Icons.palette,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: _buildTextField(
                      controller: _sizeController,
                      label: 'Taille',
                      icon: Icons.straighten,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),

              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: AppDimensions.paddingXL),

              // Prix et stock
              _buildSectionTitle('Prix et stock'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _sellPriceController,
                      label: 'Prix de vente *',
                      icon: Icons.sell,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Prix requis';
                        if (double.tryParse(value!) == null)
                          return 'Prix invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: _buildTextField(
                      controller: _costPriceController,
                      label: 'Prix d\'achat',
                      icon: Icons.shopping_cart,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _quantityController,
                      label: 'Quantité initiale',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: _buildTextField(
                      controller: _minStockController,
                      label: 'Stock minimum',
                      icon: Icons.warning,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),

              // Options
              Card(
                child: CheckboxListTile(
                  title: const Text('Nécessite une prescription'),
                  subtitle: const Text('Ce produit nécessite une ordonnance'),
                  value: _hasPrescription,
                  onChanged: (value) =>
                      setState(() => _hasPrescription = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),

              const SizedBox(height: AppDimensions.paddingXL),

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      readOnly: readOnly,
      validator: validator,
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
            onPressed: _isLoading ? null : _saveProduct,
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
                : const Text('Enregistrer'),
          ),
        ),
      ],
    );
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = Product(
        barcode: _barcodeController.text.isNotEmpty
            ? _barcodeController.text
            : null,
        name: _nameController.text.trim(),
        categoryId: _selectedCategory?.id,
        brand: _brandController.text.isNotEmpty
            ? _brandController.text.trim()
            : null,
        model: _modelController.text.isNotEmpty
            ? _modelController.text.trim()
            : null,
        color: _colorController.text.isNotEmpty
            ? _colorController.text.trim()
            : null,
        size: _sizeController.text.isNotEmpty
            ? _sizeController.text.trim()
            : null,
        sellPrice: double.parse(_sellPriceController.text),
        costPrice: _costPriceController.text.isNotEmpty
            ? double.parse(_costPriceController.text)
            : null,
        quantity: int.parse(_quantityController.text),
        minStockAlert: int.parse(_minStockController.text),
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        hasPrescription: _hasPrescription,
      );

      final success = await context.read<ProductService>().addProduct(product);

      if (mounted) {
        if (success) {
          // Imprimer automatiquement les étiquettes si quantité > 0
          final quantity = int.parse(_quantityController.text);
          if (quantity > 0) {
            await _printLabels(quantity);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produit ajouté avec succès'),
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
              content: Text('Erreur lors de l\'ajout du produit'),
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

  void _onSave() async {
    await _saveProduct();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    _sellPriceController.dispose();
    _costPriceController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
