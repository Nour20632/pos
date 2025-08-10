// screens/create_optical_order_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jiffy/jiffy.dart';
import 'package:mk_optique/database.dart';
import 'package:mk_optique/models.dart';
import 'package:mk_optique/optical_models.dart';
class CreateOpticalOrderScreen extends StatefulWidget {
  final Customer? selectedCustomer;
  final Prescription? selectedPrescription;

  const CreateOpticalOrderScreen({
    Key? key,
    this.selectedCustomer,
    this.selectedPrescription,
  }) : super(key: key);

  @override
  State<CreateOpticalOrderScreen> createState() => _CreateOpticalOrderScreenState();
}

class _CreateOpticalOrderScreenState extends State<CreateOpticalOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _db = DatabaseHelper();
  
  // Controllers
  final _frameReferenceController = TextEditingController();
  final _specialNotesController = TextEditingController();
  final _estimatedPriceController = TextEditingController();
  
  // Variables
  Customer? _selectedCustomer;
  Prescription? _selectedPrescription;
  String? _selectedLensType;
  DateTime _estimatedDelivery = DateTime.now().add(const Duration(days: 7));
  List<Customer> _customers = [];
  List<Prescription> _customerPrescriptions = [];
  List<LensType> _lensTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.selectedCustomer;
    _selectedPrescription = widget.selectedPrescription;
    _loadData();
  }

  @override
  void dispose() {
    _frameReferenceController.dispose();
    _specialNotesController.dispose();
    _estimatedPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _customers = await _db.getAllCustomers();
      _lensTypes = await _db.getAllLensTypes();
      
      if (_selectedCustomer != null) {
        await _loadCustomerPrescriptions(_selectedCustomer!.id!);
      }
    } catch (e) {
      _showErrorSnackBar('Erreur de chargement: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadCustomerPrescriptions(int customerId) async {
    try {
      _customerPrescriptions = await _db.getCustomerPrescriptions(customerId);
      setState(() {});
    } catch (e) {
      _showErrorSnackBar('Erreur de chargement des ordonnances: $e');
    }
  }

  Future<void> _saveOpticalOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      _showErrorSnackBar('Veuillez sélectionner un client');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orderNumber = await _db.generateOpticalOrderNumber();
      final currentUser = await _getCurrentUser(); // Implémentez cette méthode
      
      final order = OpticalOrder(
        orderNumber: orderNumber,
        customerId: _selectedCustomer!.id!,
        prescriptionId: _selectedPrescription?.id,
        frameReference: _frameReferenceController.text.trim(),
        lensType: _selectedLensType,
        specialNotes: _specialNotesController.text.trim(),
        estimatedPrice: double.tryParse(_estimatedPriceController.text) ?? 0.0,
        orderDate: DateTime.now(),
        estimatedDelivery: _estimatedDelivery,
        createdBy: currentUser?.id,
      );

      await _db.insertOpticalOrder(order);
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande $orderNumber créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Erreur de sauvegarde: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<User?> _getCurrentUser() async {
    // Implémentez selon votre système d'authentification
    // Retournez l'utilisateur connecté actuel
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Commande Optique'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveOpticalOrder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Client
                    _buildClientSection(),
                    const SizedBox(height: 20),
                    
                    // Section Prescription
                    _buildPrescriptionSection(),
                    const SizedBox(height: 20),
                    
                    // Section Détails de la commande
                    _buildOrderDetailsSection(),
                    const SizedBox(height: 20),
                    
                    // Section Prix et livraison
                    _buildPriceAndDeliverySection(),
                    const SizedBox(height: 30),
                    
                    // Boutons d'action
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildClientSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Informations Client',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<Customer>(
              value: _selectedCustomer,
              decoration: const InputDecoration(
                labelText: 'Sélectionner un client',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
              ),
              items: _customers.map((customer) {
                return DropdownMenuItem<Customer>(
                  value: customer,
                  child: Text('${customer.name} - ${customer.phone ?? ""}'),
                );
              }).toList(),
              onChanged: (customer) {
                setState(() {
                  _selectedCustomer = customer;
                  _selectedPrescription = null;
                  _customerPrescriptions = [];
                });
                if (customer != null) {
                  _loadCustomerPrescriptions(customer.id!);
                }
              },
              validator: (value) => value == null ? 'Client requis' : null,
            ),
            
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Client: ${_selectedCustomer!.name}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedCustomer!.phone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 20),
                          const SizedBox(width: 8),
                          Text('Tél: ${_selectedCustomer!.phone}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.visibility, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Prescription Médicale',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_customerPrescriptions.isNotEmpty) ...[
              DropdownButtonFormField<Prescription>(
                value: _selectedPrescription,
                decoration: const InputDecoration(
                  labelText: 'Sélectionner une prescription',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_services),
                ),
                items: _customerPrescriptions.map((prescription) {
                  final dateStr = Jiffy.parseFromDateTime(prescription.createdAt)
                      .format(pattern: 'dd/MM/yyyy');
                  return DropdownMenuItem<Prescription>(
                    value: prescription,
                    child: Text('Prescription du $dateStr'),
                  );
                }).toList(),
                onChanged: (prescription) {
                  setState(() => _selectedPrescription = prescription);
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Aucune prescription trouvée pour ce client.\nVous pouvez continuer sans prescription.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_selectedPrescription != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildPrescriptionRow('OD (Œil Droit)', 
                        _selectedPrescription!.odSphere, 
                        _selectedPrescription!.odCylinder,
                        _selectedPrescription!.odAxis),
                    const Divider(),
                    _buildPrescriptionRow('OS (Œil Gauche)', 
                        _selectedPrescription!.osSphere, 
                        _selectedPrescription!.osCylinder,
                        _selectedPrescription!.osAxis),
                    if (_selectedPrescription!.pdTotal != null) ...[
                      const Divider(),
                      Text('Distance pupillaire: ${_selectedPrescription!.pdTotal} mm'),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionRow(String eye, double? sphere, double? cylinder, int? axis) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(eye, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 10),
        if (sphere != null) Text('SPH: ${sphere.toStringAsFixed(2)}'),
        const SizedBox(width: 10),
        if (cylinder != null) Text('CYL: ${cylinder.toStringAsFixed(2)}'),
        const SizedBox(width: 10),
        if (axis != null) Text('AXE: $axis°'),
      ],
    );
  }

  Widget _buildOrderDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Détails de la Commande',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Référence du cadre
            TextFormField(
              controller: _frameReferenceController,
              decoration: const InputDecoration(
                labelText: 'Référence du cadre',
                hintText: 'Ex: Ray-Ban RB3025, Oakley OX8040...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grid_view),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Référence du cadre requise';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Type de verres
            DropdownButtonFormField<String>(
              value: _selectedLensType,
              decoration: const InputDecoration(
                labelText: 'Type de verres',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lens),
              ),
              items: _lensTypes.map((lensType) {
                return DropdownMenuItem<String>(
                  value: lensType.name,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lensType.name),
                      if (lensType.description != null)
                        Text(
                          lensType.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedLensType = value);
                
                // Auto-remplir le prix estimé selon le type de verre
                final selectedType = _lensTypes.firstWhere(
                  (type) => type.name == value,
                  orElse: () => LensType(name: '', createdAt: DateTime.now()),
                );
                if (selectedType.basePrice > 0) {
                  _estimatedPriceController.text = selectedType.basePrice.toStringAsFixed(0);
                }
              },
              validator: (value) => value == null ? 'Type de verres requis' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Notes spéciales
            TextFormField(
              controller: _specialNotesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes spéciales',
                hintText: 'Teinte, traitements spéciaux, instructions particulières...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_add),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndDeliverySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Prix et Livraison',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Prix estimé
            TextFormField(
              controller: _estimatedPriceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Prix estimé (DA)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
                suffixText: 'DA',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Prix estimé requis';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Prix invalide';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Date de livraison estimée
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _estimatedDelivery,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _estimatedDelivery = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de livraison estimée',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  Jiffy.parseFromDateTime(_estimatedDelivery).format(pattern: 'dd/MM/yyyy'),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Le prix final sera déterminé par le spécialiste après évaluation.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveOpticalOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Créer la Commande'),
          ),
        ),
      ],
    );
  }
}