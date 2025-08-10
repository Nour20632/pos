import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';
import '../services/product_service.dart';

class EditProductScreen extends StatefulWidget {
  final int productId;
  const EditProductScreen({super.key, required this.productId});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  Product? _product;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _colorController;
  late TextEditingController _sizeController;
  late TextEditingController _sellPriceController;
  late TextEditingController _costPriceController;
  late TextEditingController _quantityController;
  late TextEditingController _minStockController;
  late TextEditingController _descriptionController;
  Category? _selectedCategory;
  bool _hasPrescription = false;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final service = context.read<ProductService>();
    final product = await service.getProductById(widget.productId);
    if (product != null) {
      setState(() {
        _product = product;
        _nameController = TextEditingController(text: product.name);
        _barcodeController = TextEditingController(text: product.barcode ?? '');
        _brandController = TextEditingController(text: product.brand ?? '');
        _modelController = TextEditingController(text: product.model ?? '');
        _colorController = TextEditingController(text: product.color ?? '');
        _sizeController = TextEditingController(text: product.size ?? '');
        _sellPriceController = TextEditingController(
          text: product.sellPrice.toString(),
        );
        _costPriceController = TextEditingController(
          text: product.costPrice?.toString() ?? '',
        );
        _quantityController = TextEditingController(
          text: product.quantity.toString(),
        );
        _minStockController = TextEditingController(
          text: product.minStockAlert.toString(),
        );
        _descriptionController = TextEditingController(
          text: product.description ?? '',
        );
        _selectedCategory = product.category;
        _hasPrescription = product.hasPrescription;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final service = context.read<ProductService>();
    final updated = _product!.copyWith(
      name: _nameController.text,
      barcode: _barcodeController.text,
      brand: _brandController.text,
      model: _modelController.text,
      color: _colorController.text,
      size: _sizeController.text,
      sellPrice: double.tryParse(_sellPriceController.text) ?? 0,
      costPrice: double.tryParse(_costPriceController.text),
      quantity: int.tryParse(_quantityController.text) ?? 0,
      minStockAlert: int.tryParse(_minStockController.text) ?? 0,
      description: _descriptionController.text,
      category: _selectedCategory,
      hasPrescription: _hasPrescription,
    );
    final ok = await service.updateProduct(updated);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produit sauvegardé')));
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final service = context.read<ProductService>();
    final ok = await service.deleteProduct(_product!.id!);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produit supprimé')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isWide = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Produit'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFormFields()),
                    const SizedBox(width: 32),
                    Expanded(child: _buildDetailsCard()),
                  ],
                )
              : Column(
                  children: [
                    _buildFormFields(),
                    const SizedBox(height: 24),
                    _buildDetailsCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nom du produit'),
          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _barcodeController,
          decoration: const InputDecoration(labelText: 'Code-barres'),
        ),
        const SizedBox(height: 12),
        Consumer<ProductService>(
          builder: (context, service, _) {
            return DropdownButtonFormField<Category>(
              value: _selectedCategory,
              items: service.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (c) => setState(() => _selectedCategory = c),
              decoration: const InputDecoration(labelText: 'Catégorie'),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Marque'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Modèle'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(labelText: 'Couleur'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(labelText: 'Taille'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _sellPriceController,
                decoration: const InputDecoration(labelText: 'Prix de vente'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _costPriceController,
                decoration: const InputDecoration(labelText: 'Prix d\'achat'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantité'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _minStockController,
                decoration: const InputDecoration(labelText: 'Stock minimum'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _hasPrescription,
          onChanged: (v) => setState(() => _hasPrescription = v),
          title: const Text('Nécessite une prescription'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _product!.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('Code-barres: ${_product!.barcode ?? "-"}'),
            Text('Catégorie: ${_selectedCategory?.name ?? "-"}'),
            Text('Marque: ${_brandController.text}'),
            Text('Modèle: ${_modelController.text}'),
            Text('Couleur: ${_colorController.text}'),
            Text('Taille: ${_sizeController.text}'),
            Text('Prix de vente: ${_sellPriceController.text} DA'),
            Text('Prix d\'achat: ${_costPriceController.text} DA'),
            Text('Quantité: ${_quantityController.text}'),
            Text('Stock minimum: ${_minStockController.text}'),
            Text('Prescription: ${_hasPrescription ? "Oui" : "Non"}'),
            if (_descriptionController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Description: ${_descriptionController.text}'),
              ),
          ],
        ),
      ),
    );
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
