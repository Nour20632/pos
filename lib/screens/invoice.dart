import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jiffy/jiffy.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/app_drawer.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<Invoice> _filteredInvoices = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInvoices();
  }

  void _loadInvoices() {
    final invoiceService = context.read<InvoiceService>();
    _filteredInvoices = invoiceService.invoices;
    _filterInvoices();
  }

  void _filterInvoices() {
    final invoices = context.read<InvoiceService>().invoices;
    final currentTab = _tabController.index;

    List<Invoice> filtered = invoices;

    // Filtrer par statut selon l'onglet
    switch (currentTab) {
      case 1: // Payées
        filtered = invoices.where((i) => i.isPaid).toList();
        break;
      case 2: // Impayées
        filtered = invoices
            .where((i) => i.isUnpaid || i.isPartiallyPaid)
            .toList();
        break;
      case 3: // Annulées
        filtered = invoices.where((i) => i.isCancelled).toList();
        break;
    }

    // Filtrer par recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (i) =>
                i.invoiceNumber.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (i.customerName?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    setState(() => _filteredInvoices = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factures'),
        backgroundColor: AppColors.primary,
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (_) => _filterInvoices(),
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'Payées'),
            Tab(text: 'Impayées'),
            Tab(text: 'Annulées'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            color: AppColors.surface,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher factures...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterInvoices();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterInvoices();
              },
            ),
          ),

          // Liste des factures
          Expanded(
            child: Consumer<InvoiceService>(
              builder: (context, invoiceService, child) {
                if (invoiceService.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_filteredInvoices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Aucune facture trouvée'
                              : 'Aucun résultat pour "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await invoiceService.loadInvoices();
                    _loadInvoices();
                  },
                  child: ListView.builder(
                    itemCount: _filteredInvoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _filteredInvoices[index];
                      return _buildInvoiceCard(invoice);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getStatusColor(invoice).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getStatusIcon(invoice), color: _getStatusColor(invoice)),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoice.customerName != null)
              Text('Client: ${invoice.customerName}'),
            Text(
              'Date: ${Jiffy.parseFromDateTime(invoice.createdAt).format(pattern: 'dd/MM/yyyy HH:mm')}',
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(invoice),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(invoice),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
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
            if (invoice.remainingAmount > 0)
              Text(
                'Reste: ${invoice.remainingAmount.toStringAsFixed(2)} DA',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
          ],
        ),
        onTap: () => context.go('/invoices/detail/${invoice.id}'),
      ),
    );
  }

  Color _getStatusColor(Invoice invoice) {
    switch (invoice.paymentStatus) {
      case PaymentStatus.paye:
        return AppColors.success;
      case PaymentStatus.partiel:
        return AppColors.warning;
      case PaymentStatus.annule:
        return AppColors.statusCancelled;
      case PaymentStatus.impaye:
      default:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(Invoice invoice) {
    switch (invoice.paymentStatus) {
      case PaymentStatus.paye:
        return Icons.check_circle;
      case PaymentStatus.partiel:
        return Icons.schedule;
      case PaymentStatus.annule:
        return Icons.cancel;
      case PaymentStatus.impaye:
      default:
        return Icons.error;
    }
  }

  String _getStatusText(Invoice invoice) {
    switch (invoice.paymentStatus) {
      case PaymentStatus.paye:
        return 'Payée';
      case PaymentStatus.partiel:
        return 'Partielle';
      case PaymentStatus.annule:
        return 'Annulée';
      case PaymentStatus.impaye:
      default:
        return 'Impayée';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
