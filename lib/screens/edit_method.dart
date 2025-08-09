// Ajouter ces méthodes à la classe MKOptiquePOSApp dans main.dart

import 'package:flutter/material.dart';
import 'package:mk_optique/models.dart';

class MKOptiquePOSApp extends StatelessWidget {
  const MKOptiquePOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(); // Prevents "body might complete normally" error
  }

  // Méthode pour EditProductScreen
  Widget editProductScreen(BuildContext context, {required Product product}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Produit'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveProduct(context, product),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [_buildProductForm(context, product)]),
      ),
    );
  }

  // Méthode pour EditCustomerScreen
  Widget editCustomerScreen(
    BuildContext context, {
    required Customer customer,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Client'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveCustomer(context, customer),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [_buildCustomerForm(context, customer)]),
      ),
    );
  }

  // Méthode pour InvoiceDetailScreen
  Widget invoiceDetailScreen(BuildContext context, {required Invoice invoice}) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Facture ${invoice.invoiceNumber}'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printInvoice(context, invoice),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareInvoice(context, invoice),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInvoiceHeader(invoice),
            const SizedBox(height: 16),
            _buildInvoiceItems(invoice),
            const SizedBox(height: 16),
            _buildInvoiceSummary(invoice),
            const SizedBox(height: 16),
            _buildPaymentStatus(invoice),
          ],
        ),
      ),
    );
  }

  // Widgets helper pour les formulaires
  Widget _buildProductForm(BuildContext context, Product product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              initialValue: product.name,
              decoration: const InputDecoration(
                labelText: 'Nom du produit',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: product.sellPrice.toString(),
              decoration: const InputDecoration(
                labelText: 'Prix de vente',
                border: OutlineInputBorder(),
                suffixText: 'DA',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: product.quantity.toString(),
              decoration: const InputDecoration(
                labelText: 'Quantité en stock',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerForm(BuildContext context, Customer customer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              initialValue: customer.name,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: customer.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: customer.email,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceHeader(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Facture ${invoice.invoiceNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(invoice.paymentStatus.name.toUpperCase()),
                  backgroundColor: _getStatusColor(invoice.paymentStatus),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (invoice.customerName != null)
              Text('Client: ${invoice.customerName}'),
            Text('Date: ${invoice.createdAt.toString().split(' ')[0]}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItems(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Articles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...invoice.items.map(
              (item) => ListTile(
                title: Text(item.productName),
                subtitle: Text(
                  '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} DA',
                ),
                trailing: Text('${item.totalPrice.toStringAsFixed(2)} DA'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSummary(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sous-total:'),
                Text('${invoice.subtotal.toStringAsFixed(2)} DA'),
              ],
            ),
            if (invoice.discountAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remise:'),
                  Text('-${invoice.discountAmount.toStringAsFixed(2)} DA'),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '${invoice.totalAmount.toStringAsFixed(2)} DA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatus(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statut de Paiement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Montant payé:'),
                Text('${invoice.paidAmount.toStringAsFixed(2)} DA'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reste à payer:'),
                Text('${invoice.remainingAmount.toStringAsFixed(2)} DA'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Méthodes d'action
  void _saveProduct(BuildContext context, Product product) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Produit sauvegardé')));
    Navigator.pop(context);
  }

  void _saveCustomer(BuildContext context, Customer customer) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Client sauvegardé')));
    Navigator.pop(context);
  }

  void _printInvoice(BuildContext context, Invoice invoice) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impression de la facture...')),
    );
  }

  void _shareInvoice(BuildContext context, Invoice invoice) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Partage de la facture...')));
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paye:
        return Colors.green.shade100;
      case PaymentStatus.impaye:
        return Colors.red.shade100;
      case PaymentStatus.partiel:
        return Colors.orange.shade100;
      case PaymentStatus.annule:
        return Colors.grey.shade100;
    }
  }
}
