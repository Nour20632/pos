import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/printer_service.dart';
import '../services/product_service.dart';

class LabelPrintingScreen extends StatefulWidget {
  const LabelPrintingScreen({super.key});

  @override
  State<LabelPrintingScreen> createState() => _LabelPrintingScreenState();
}

class _LabelPrintingScreenState extends State<LabelPrintingScreen> {
  Product? _selectedProduct;
  int _quantity = 1;
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductService>().products;
    final printerService = context.watch<UsbPrinterService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impression Étiquettes'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<Product>(
              value: _selectedProduct,
              items: products
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text('${p.name} (${p.barcode ?? "-"})'),
                    ),
                  )
                  .toList(),
              onChanged: (p) => setState(() => _selectedProduct = p),
              decoration: const InputDecoration(
                labelText: 'Sélectionner un produit',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Quantité d\'étiquettes :'),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: '1',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'pcs',
                    ),
                    onChanged: (v) =>
                        setState(() => _quantity = int.tryParse(v) ?? 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: Text(_isPrinting ? 'Impression...' : 'Imprimer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed:
                  _isPrinting ||
                      _selectedProduct == null ||
                      !printerService.isConnected
                  ? null
                  : () async {
                      setState(() => _isPrinting = true);
                      for (int i = 0; i < _quantity; i++) {
                        await printerService.printBarcode(
                          _selectedProduct!.barcode ?? '',
                        );
                      }
                      setState(() => _isPrinting = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Étiquettes imprimées avec succès'),
                          ),
                        );
                      }
                    },
            ),
            const SizedBox(height: 16),
            if (!printerService.isConnected)
              const Text(
                'Aucune imprimante connectée',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
