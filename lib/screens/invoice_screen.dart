import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jiffy/jiffy.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/invoice_service.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _searchQuery = '';
  PaymentStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Factures'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrer',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => context.read<InvoiceService>().loadInvoices(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(child: _buildInvoicesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/sale/new'),
        backgroundColor: const Color(0xFF1E3A8A),
        tooltip: 'Nouvelle Vente',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Rechercher une facture...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(_selectedStatus?.name ?? 'Tous les statuts'),
            selected: _selectedStatus != null,
            onSelected: (bool selected) {
              if (selected) {
                _showStatusFilterDialog();
              } else {
                setState(() => _selectedStatus = null);
              }
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(
              _startDate != null && _endDate != null
                  ? '${Jiffy.parseFromDateTime(_startDate!).format(pattern: 'dd/MM')} - ${Jiffy.parseFromDateTime(_endDate!).format(pattern: 'dd/MM')}'
                  : 'Période',
            ),
            selected: _startDate != null && _endDate != null,
            onSelected: (bool selected) {
              if (selected) {
                _showDateRangeDialog();
              } else {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    return Consumer<InvoiceService>(
      builder: (context, service, _) {
        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final invoices = service.invoices.where((invoice) {
          final matchesSearch =
              invoice.invoiceNumber.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (invoice.customerName?.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ??
                  false);
          final matchesStatus =
              _selectedStatus == null ||
              invoice.paymentStatus == _selectedStatus;
          final matchesDate =
              _startDate == null ||
              _endDate == null ||
              (invoice.createdAt.isAfter(_startDate!) &&
                  invoice.createdAt.isBefore(
                    _endDate!.add(const Duration(days: 1)),
                  ));
          return matchesSearch && matchesStatus && matchesDate;
        }).toList();

        if (invoices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Aucune facture trouvée',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: invoices.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final invoice = invoices[index];
            return _buildInvoiceCard(invoice);
          },
        );
      },
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final statusColor = _getStatusColor(invoice.paymentStatus);
    final dateStr = Jiffy.parseFromDateTime(
      invoice.createdAt,
    ).format(pattern: 'dd/MM/yyyy HH:mm');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => context.push('/invoices/detail/${invoice.id}'),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.receipt, color: statusColor),
        ),
        title: Text(
          'Facture ${invoice.invoiceNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoice.customerName != null)
              Text('Client: ${invoice.customerName}'),
            Text('Date: $dateStr'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${invoice.totalAmount.toStringAsFixed(2)} DA',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(invoice.paymentStatus),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paye:
        return Colors.green;
      case PaymentStatus.partiel:
        return Colors.orange;
      case PaymentStatus.impaye:
        return Colors.red;
      case PaymentStatus.annule:
        return Colors.grey;
    }
  }

  String _getStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paye:
        return 'Payé';
      case PaymentStatus.partiel:
        return 'Partiel';
      case PaymentStatus.impaye:
        return 'Impayé';
      case PaymentStatus.annule:
        return 'Annulé';
    }
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtres'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Statut de paiement'),
              onTap: () {
                context.pop();
                _showStatusFilterDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Période'),
              onTap: () {
                context.pop();
                _showDateRangeDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _startDate = null;
                _endDate = null;
              });
              context.pop();
            },
            child: const Text('Réinitialiser'),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusFilterDialog() async {
    final status = await showDialog<PaymentStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filtrer par statut'),
        children: PaymentStatus.values.map((status) {
          return SimpleDialogOption(
            onPressed: () => context.pop(status),
            child: Text(_getStatusText(status)),
          );
        }).toList(),
      ),
    );

    if (status != null) {
      setState(() => _selectedStatus = status);
    }
  }

  Future<void> _showDateRangeDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}
