import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/invoice_service.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Invoice?>(
      future: context.read<InvoiceService>().getInvoiceById(invoiceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final invoice = snapshot.data;
        if (invoice == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Facture')),
            body: const Center(child: Text('Facture introuvable')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('Facture ${invoice.invoiceNumber}'),
            backgroundColor: Colors.green.shade800,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () {
                  // TODO: Impression
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impression à venir')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Partage
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Partage à venir')),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
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
                              label: Text(
                                invoice.paymentStatus.name.toUpperCase(),
                              ),
                              backgroundColor: _getStatusColor(
                                invoice.paymentStatus,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (invoice.customerName != null)
                          Text('Client: ${invoice.customerName}'),
                        Text(
                          'Date: ${invoice.createdAt.toString().split(' ')[0]}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Articles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...invoice.items.map(
                          (item) => ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} DA',
                            ),
                            trailing: Text(
                              '${item.totalPrice.toStringAsFixed(2)} DA',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
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
                              Text(
                                '-${invoice.discountAmount.toStringAsFixed(2)} DA',
                              ),
                            ],
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
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
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statut de Paiement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                            Text(
                              '${invoice.remainingAmount.toStringAsFixed(2)} DA',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
