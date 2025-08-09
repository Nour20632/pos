// screens/optical_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jiffy/jiffy.dart';
import 'package:mk_optique/database.dart';
import 'package:mk_optique/optical_models.dart';
import 'package:mk_optique/services/printer_service.dart';

class OpticalOrdersScreen extends StatefulWidget {
  const OpticalOrdersScreen({Key? key}) : super(key: key);

  @override
  State<OpticalOrdersScreen> createState() => _OpticalOrdersScreenState();
}

class _OpticalOrdersScreenState extends State<OpticalOrdersScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final UsbPrinterService _printerService = UsbPrinterService();
  
  late TabController _tabController;
  List<OpticalOrder> _allOrders = [];
  List<OpticalOrder> _filteredOrders = [];
  String _selectedStatus = 'tous';
  bool _isLoading = true;

  final List<String> _statusOptions = [
    'tous',
    'nouveau',
    'en_cours',
    'pret',
    'livre',
    'annule',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    
    try {
      _allOrders = await _db.getAllOpticalOrders();
      _filterOrders();
    } catch (e) {
      _showErrorSnackBar('Erreur de chargement: $e');
    }
    
    setState(() => _isLoading = false);
  }

  void _filterOrders() {
    if (_selectedStatus == 'tous') {
      _filteredOrders = List.from(_allOrders);
    } else {
      _filteredOrders = _allOrders.where((order) => order.status == _selectedStatus).toList();
    }
    setState(() {});
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commandes Optiques'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Toutes'),
            Tab(icon: Icon(Icons.work), text: 'En cours'),
            Tab(icon: Icon(Icons.check_circle), text: 'Prêtes'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewOrder(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          _buildFilters(),
          
          // Liste des commandes
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(_allOrders),
                _buildOrdersList(_allOrders.where((o) => o.isInProgress).toList()),
                _buildOrdersList(_allOrders.where((o) => o.isReady).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Icon(Icons.filter_list, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filtrer par statut',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _statusOptions.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(_getStatusDisplayName(status)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedStatus = value!);
                _filterOrders();
              },
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${_filteredOrders.length} commande(s)',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OpticalOrder> orders) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucune commande optique',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur + pour créer une nouvelle commande',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(OpticalOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec numéro et statut
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.customerName ?? 'Client inconnu',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Informations principales
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.frameReference != null) ...[
                          Row(
                            children: [
                              Icon(Icons.grid_view, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Cadre: ${order.frameReference}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (order.lensType != null) ...[
                          Row(
                            children: [
                              Icon(Icons.lens, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Verres: ${order.lensType}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (order.finalPrice > 0) ...[
                        Text(
                          '${order.finalPrice.toStringAsFixed(0)} DA',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ] else if (order.estimatedPrice > 0) ...[
                        Text(
                          '~${order.estimatedPrice.toStringAsFixed(0)} DA',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        Jiffy.parseFromDateTime(order.orderDate).fromNow(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Date de livraison et actions
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule, 
                          size: 16, 
                          color: order.isOverdue ? Colors.red : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Livraison: ${order.estimatedDelivery != null ? Jiffy.parseFromDateTime(order.estimatedDelivery!).format(pattern: 'dd/MM/yyyy') : 'Non définie'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: order.isOverdue ? Colors.red : Colors.grey.shade600,
                            fontWeight: order.isOverdue ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) => _handleOrderAction(order, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info),
                            SizedBox(width: 8),
                            Text('Détails'),
                          ],
                        ),
                      ),
                      if (order.status != 'livre' && order.status != 'annule') ...[
                        const PopupMenuItem(
                          value: 'edit_price',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Modifier prix'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'change_status',
                          child: Row(
                            children: [
                              Icon(Icons.update),
                              SizedBox(width: 8),
                              Text('Changer statut'),
                            ],
                          ),
                        ),
                      ],
                      if (order.status == 'pret') ...[
                        const PopupMenuItem(
                          value: 'print_invoice',
                          child: Row(
                            children: [
                              Icon(Icons.print),
                              SizedBox(width: 8),
                              Text('Imprimer facture'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'nouveau':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        icon = Icons.fiber_new;
        break;
      case 'en_cours':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        icon = Icons.work;
        break;
      case 'pret':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'livre':
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.done_all;
        break;
      case 'annule':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            _getStatusDisplayName(status),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'tous':
        return 'Tous';
      case 'nouveau':
        return 'Nouveau';
      case 'en_cours':
        return 'En cours';
      case 'pret':
        return 'Prêt';
      case 'livre':
        return 'Livré';
      case 'annule':
        return 'Annulé';
      default:
        return status;
    }
  }

  Future<void> _createNewOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateOpticalOrderScreen(),
      ),
    );
    
    if (result == true) {
      _loadOrders();
    }
  }

  void _handleOrderAction(OpticalOrder order, String action) {
    switch (action) {
      case 'details':
        _showOrderDetails(order);
        break;
      case 'edit_price':
        _showEditPriceDialog(order);
        break;
      case 'change_status':
        _showChangeStatusDialog(order);
        break;
      case 'print_invoice':
        _printOrderInvoice(order);
        break;
    }
  }

  void _showOrderDetails(OpticalOrder order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(order: order),
    );
  }

  void _showEditPriceDialog(OpticalOrder order) {
    showDialog(
      context: context,
      builder: (context) => EditPriceDialog(
        order: order,
        onPriceUpdated: (newPrice, costPrice) async {
          try {
            final currentUser = await _getCurrentUser();
            await _db.updateOpticalOrderPrice(
              order.id!,
              newPrice,
              costPrice,
              currentUser?.id,
            );
            _loadOrders();
            _showSuccessSnackBar('Prix mis à jour avec succès');
          } catch (e) {
            _showErrorSnackBar('Erreur de mise à jour: $e');
          }
        },
      ),
    );
  }

  void _showChangeStatusDialog(OpticalOrder order) {
    showDialog(
      context: context,
      builder: (context) => ChangeStatusDialog(
        order: order,
        onStatusChanged: (newStatus, notes) async {
          try {
            final currentUser = await _getCurrentUser();
            await _db.updateOpticalOrderStatus(
              order.id!,
              newStatus,
              notes,
              currentUser?.id,
            );
            _loadOrders();
            _showSuccessSnackBar('Statut mis à jour avec succès');
          } catch (e) {
            _showErrorSnackBar('Erreur de mise à jour: $e');
          }
        },
      ),
    );
  }

  Future<void> _printOrderInvoice(OpticalOrder order) async {
    try {
      // Créer une facture pour cette commande si elle n'existe pas
      if (order.invoiceId == null) {
        await _createInvoiceForOrder(order);
      }
      
      // Imprimer la facture
      final invoice = await _db.getInvoiceById(order.invoiceId!);
      if (invoice != null) {
        final success = await _printerService.printInvoice(invoice);
        if (success) {
          _showSuccessSnackBar('Facture imprimée avec succès');
        } else {
          _showErrorSnackBar('Erreur d\'impression: ${_printerService.lastError}');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'impression: $e');
    }
  }

  Future<void> _createInvoiceForOrder(OpticalOrder order) async {
    final invoiceNumber = await _db.generateInvoiceNumber();
    final currentUser = await _getCurrentUser();
    
    final invoice = Invoice(
      invoiceNumber: invoiceNumber,
      customerId: order.customerId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      invoiceType: InvoiceType.vente,
      paymentType: PaymentType.comptant,
      totalAmount: order.finalPrice > 0 ? order.finalPrice : order.estimatedPrice,
      paidAmount: 0,
      remainingAmount: order.finalPrice > 0 ? order.finalPrice : order.estimatedPrice,
      paymentStatus: PaymentStatus.impaye,
      userId: currentUser?.id,
      createdAt: DateTime.now(),
    );

    final invoiceItems = [
      InvoiceItem(
        productName: 'Lunettes optiques - ${order.frameReference ?? "Cadre sélectionné"}',
        quantity: 1,
        unitPrice: order.finalPrice > 0 ? order.finalPrice : order.estimatedPrice,
        totalPrice: order.finalPrice > 0 ? order.finalPrice : order.estimatedPrice,
        hasPrescription: order.prescriptionId != null,
      ),
    ];

    final invoiceId = await _db.insertInvoice(invoice, invoiceItems);
    
    // Mettre à jour la commande avec l'ID de la facture
    await _db.database.then((db) => db.update(
      'optical_orders',
      {'invoice_id': invoiceId},
      where: 'id = ?',
      whereArgs: [order.id],
    ));
  }

  Future<User?> _getCurrentUser() async {
    // Implémentez selon votre système d'authentification
    return null;
  }
}

// ==================== DIALOG POUR LES DÉTAILS ====================

class OrderDetailsDialog extends StatelessWidget {
  final OpticalOrder order;

  const OrderDetailsDialog({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        maxHeight: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Row(
              children: [
                Icon(Icons.visibility, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Détails de la Commande',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const Divider(),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations générales
                    _buildInfoSection('Informations Générales', [
                      _buildInfoRow('Numéro', order.orderNumber),
                      _buildInfoRow('Client', order.customerName ?? 'Inconnu'),
                      _buildInfoRow('Téléphone', order.customerPhone ?? 'Non renseigné'),
                      _buildInfoRow('Statut', order.statusDisplayName),
                      _buildInfoRow('Date de commande', 
                          Jiffy.parseFromDateTime(order.orderDate).format(pattern: 'dd/MM/yyyy')),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Détails produit
                    _buildInfoSection('Détails du Produit', [
                      _buildInfoRow('Référence cadre', order.frameReference ?? 'Non spécifiée'),
                      _buildInfoRow('Type de verres', order.lensType ?? 'Non spécifié'),
                      if (order.specialNotes != null && order.specialNotes!.isNotEmpty)
                        _buildInfoRow('Notes spéciales', order.specialNotes!),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Prix et dates
                    _buildInfoSection('Prix et Échéances', [
                      if (order.estimatedPrice > 0)
                        _buildInfoRow('Prix estimé', '${order.estimatedPrice.toStringAsFixed(0)} DA'),
                      if (order.finalPrice > 0)
                        _buildInfoRow('Prix final', '${order.finalPrice.toStringAsFixed(0)} DA'),
                      if (order.estimatedDelivery != null)
                        _buildInfoRow('Livraison estimée', 
                            Jiffy.parseFromDateTime(order.estimatedDelivery!).format(pattern: 'dd/MM/yyyy')),
                      if (order.completionDate != null)
                        _buildInfoRow('Date d\'achèvement', 
                            Jiffy.parseFromDateTime(order.completionDate!).format(pattern: 'dd/MM/yyyy')),
                    ]),
                    
                    // Prescription si disponible
                    if (order.odSphere != null || order.osSphere != null) ...[
                      const SizedBox(height: 16),
                      _buildPrescriptionSection(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionSection() {
    return _buildInfoSection('Prescription Médicale', [
      if (order.odSphere != null || order.odCylinder != null || order.odAxis != null)
        _buildInfoRow('OD (Œil Droit)', 
            'SPH: ${order.odSphere?.toStringAsFixed(2) ?? "/"} '
            'CYL: ${order.odCylinder?.toStringAsFixed(2) ?? "/"} '
            'AXE: ${order.odAxis ?? "/"}°'),
      
      if (order.osSphere != null || order.osCylinder != null || order.osAxis != null)
        _buildInfoRow('OS (Œil Gauche)', 
            'SPH: ${order.osSphere?.toStringAsFixed(2) ?? "/"} '
            'CYL: ${order.osCylinder?.toStringAsFixed(2) ?? "/"} '
            'AXE: ${order.osAxis ?? "/"}°'),
      
      if (order.odAdd != null || order.osAdd != null)
        _buildInfoRow('Addition', 
            'OD: ${order.odAdd?.toStringAsFixed(2) ?? "/"} '
            'OS: ${order.osAdd?.toStringAsFixed(2) ?? "/"}'),
      
      if (order.pdTotal != null)
        _buildInfoRow('Distance pupillaire', '${order.pdTotal} mm'),
      
      if (order.pdRight != null && order.pdLeft != null)
        _buildInfoRow('DP séparée', 
            'Droite: ${order.pdRight} mm, Gauche: ${order.pdLeft} mm'),
    ]);
  }
}

// ==================== DIALOG POUR MODIFIER LE PRIX ====================

class EditPriceDialog extends StatefulWidget {
  final OpticalOrder order;
  final Function(double finalPrice, double? costPrice) onPriceUpdated;

  const EditPriceDialog({
    Key? key,
    required this.order,
    required this.onPriceUpdated,
  }) : super(key: key);

  @override
  State<EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<EditPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _finalPriceController;
  late final TextEditingController _costPriceController;

  @override
  void initState() {
    super.initState();
    _finalPriceController = TextEditingController(
      text: widget.order.finalPrice > 0 
          ? widget.order.finalPrice.toStringAsFixed(0)
          : widget.order.estimatedPrice.toStringAsFixed(0),
    );
    _costPriceController = TextEditingController(
      text: widget.order.costPrice > 0 
          ? widget.order.costPrice.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _finalPriceController.dispose();
    _costPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le Prix'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Commande: ${widget.order.orderNumber}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _finalPriceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Prix final (DA)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
                suffixText: 'DA',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Prix final requis';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Prix invalide';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _costPriceController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Prix de revient (DA) - Optionnel',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.price_change),
                suffixText: 'DA',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final finalPrice = double.parse(_finalPriceController.text);
              final costPrice = _costPriceController.text.isNotEmpty
                  ? double.parse(_costPriceController.text)
                  : null;
              
              widget.onPriceUpdated(finalPrice, costPrice);
              Navigator.pop(context);
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ==================== DIALOG POUR CHANGER LE STATUT ====================

class ChangeStatusDialog extends StatefulWidget {
  final OpticalOrder order;
  final Function(String newStatus, String? notes) onStatusChanged;

  const ChangeStatusDialog({
    Key? key,
    required this.order,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  State<ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<ChangeStatusDialog> {
  late String _selectedStatus;
  final _notesController = TextEditingController();

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': 'nouveau', 'label': 'Nouveau', 'icon': Icons.fiber_new, 'color': Colors.blue},
    {'value': 'en_cours', 'label': 'En cours', 'icon': Icons.work, 'color': Colors.orange},
    {'value': 'pret', 'label': 'Prêt', 'icon': Icons.check_circle, 'color': Colors.green},
    {'value': 'livre', 'label': 'Livré', 'icon': Icons.done_all, 'color': Colors.grey},
    {'value': 'annule', 'label': 'Annulé', 'icon': Icons.cancel, 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Changer le Statut'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commande: ${widget.order.orderNumber}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            'Nouveau statut:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statusOptions.map((option) {
              final isSelected = _selectedStatus == option['value'];
              return InkWell(
                onTap: () {
                  setState(() => _selectedStatus = option['value']);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? option['color'].withOpacity(0.2) : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected ? option['color'] : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option['icon'],
                        size: 16,
                        color: isSelected ? option['color'] : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        option['label'],
                        style: TextStyle(
                          color: isSelected ? option['color'] : Colors.grey.shade600,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optionnel)',
              hintText: 'Raison du changement, observations...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onStatusChanged(_selectedStatus, _notesController.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Confirmer'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}