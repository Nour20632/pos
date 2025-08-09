import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/customer_service.dart';

class EditCustomerScreen extends StatefulWidget {
  final int customerId;
  const EditCustomerScreen({super.key, required this.customerId});

  @override
  State<EditCustomerScreen> createState() => _EditCustomerScreenState();
}

class _EditCustomerScreenState extends State<EditCustomerScreen> {
  Customer? _customer;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    final service = context.read<CustomerService>();
    final customer = await service.getCustomerById(widget.customerId);
    if (customer != null) {
      setState(() {
        _customer = customer;
        _nameController = TextEditingController(text: customer.name);
        _phoneController = TextEditingController(text: customer.phone ?? '');
        _emailController = TextEditingController(text: customer.email ?? '');
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final service = context.read<CustomerService>();
    final updated = _customer!.copyWith(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
    );
    final ok = await service.updateCustomer(updated);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client sauvegardé')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _customer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Client'),
        backgroundColor: Colors.indigo.shade800,
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
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Téléphone'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
