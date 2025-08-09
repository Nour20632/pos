import 'package:flutter/material.dart';
import 'package:mk_optique/models.dart';
import 'package:mk_optique/services/customer_service.dart';
import 'package:provider/provider.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    // تحميل العملاء من الخدمة وليس فقط من متغير محلي
    context.read<CustomerService>().loadCustomers();
  }

  void _loadCustomers() {
    final customerService = context.read<CustomerService>();
    setState(() {
      _filteredCustomers = customerService.customers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CustomerService>().loadCustomers();
              _loadCustomers();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatsCard(),
          Expanded(child: _buildCustomersList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/add-customer'),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau Client'),
        backgroundColor: Colors.indigo.shade600,
      ),
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
          hintText: 'Rechercher un client...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: _filterCustomers,
      ),
    );
  }

  Widget _buildStatsCard() {
    return Consumer<CustomerService>(
      builder: (context, customerService, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade600, Colors.indigo.shade800],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.indigo.shade200, blurRadius: 8),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Clients',
                '${customerService.customers.length}',
                Icons.people,
              ),
              _buildStatItem(
                'Nouveaux ce mois',
                '${customerService.getRecentCustomers().length}',
                Icons.person_add,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCustomersList() {
    if (_filteredCustomers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucun client trouvé',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredCustomers[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                style: TextStyle(
                  color: Colors.indigo.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              customer.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.phone != null)
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(customer.phone!),
                    ],
                  ),
                if (customer.email != null)
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(customer.email!),
                    ],
                  ),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ajouté le ${customer.createdAt.toString().split(' ')[0]}',
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, customer),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('Voir détails')),
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                const PopupMenuItem(
                  value: 'prescriptions',
                  child: Text('Prescriptions'),
                ),
                const PopupMenuItem(
                  value: 'history',
                  child: Text('Historique'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _filterCustomers(String query) {
    final customerService = context.read<CustomerService>();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = customerService.customers;
      } else {
        _filteredCustomers = customerService.customers
            .where(
              (customer) =>
                  customer.name.toLowerCase().contains(query.toLowerCase()) ||
                  (customer.phone?.contains(query) ?? false) ||
                  (customer.email?.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ??
                      false),
            )
            .toList();
      }
    });
  }

  void _handleMenuAction(String action, Customer customer) {
    switch (action) {
      case 'view':
        _showCustomerDetails(customer);
        break;
      case 'edit':
        Navigator.pushNamed(context, '/edit-customer', arguments: customer);
        break;
      case 'prescriptions':
        Navigator.pushNamed(
          context,
          '/customer-prescriptions',
          arguments: customer,
        );
        break;
      case 'history':
        Navigator.pushNamed(context, '/customer-history', arguments: customer);
        break;
      case 'delete':
        _confirmDelete(customer);
        break;
    }
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.phone != null)
              _buildDetailRow('Téléphone', customer.phone!),
            if (customer.email != null)
              _buildDetailRow('Email', customer.email!),
            if (customer.address != null)
              _buildDetailRow('Adresse', customer.address!),
            if (customer.dateOfBirth != null)
              _buildDetailRow(
                'Date de naissance',
                customer.dateOfBirth.toString().split(' ')[0],
              ),
            if (customer.gender != null)
              _buildDetailRow('Genre', customer.gender!.name),
            _buildDetailRow(
              'Client depuis',
              customer.createdAt.toString().split(' ')[0],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/edit-customer',
                arguments: customer,
              );
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDelete(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le client'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${customer.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _deleteCustomer(customer),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(Customer customer) async {
    final customerService = context.read<CustomerService>();
    final success = await customerService.deleteCustomer(customer.id!);

    Navigator.pop(context);

    if (success) {
      _loadCustomers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client supprimé avec succès')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la suppression')),
      );
    }
  }
}
