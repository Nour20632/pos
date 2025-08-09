import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  late TextEditingController _priceController;
  late TextEditingController _quantityController;

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
        _priceController = TextEditingController(
          text: product.sellPrice.toString(),
        );
        _quantityController = TextEditingController(
          text: product.quantity.toString(),
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final service = context.read<ProductService>();
    final updated = _product!.copyWith(
      name: _nameController.text,
      sellPrice: double.tryParse(_priceController.text) ?? 0,
      quantity: int.tryParse(_quantityController.text) ?? 0,
    );
    final ok = await service.updateProduct(updated);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produit sauvegardé')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Produit'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du produit'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Prix de vente (DA)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'Prix invalide'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantité en stock',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null
                    ? 'Quantité invalide'
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
