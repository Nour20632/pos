import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/enhanced_printer_service.dart';
import 'package:mk_optique/models.dart';
import 'package:mk_optique/services.dart';
import 'package:provider/provider.dart';

class OpticalSaleScreen extends StatefulWidget {
  final Cart cart;
  final Customer? customer;

  const OpticalSaleScreen({super.key, required this.cart, this.customer});

  @override
  State<OpticalSaleScreen> createState() => _OpticalSaleScreenState();
}

class _OpticalSaleScreenState extends State<OpticalSaleScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les informations client
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  // Contrôleurs pour les prescriptions OD (Œil Droit)
  final _odVlSphereController = TextEditingController();
  final _odVlCylinderController = TextEditingController();
  final _odVlAxisController = TextEditingController();
  final _odVpSphereController = TextEditingController();
  final _odVpCylinderController = TextEditingController();
  final _odVpAxisController = TextEditingController();

  // Contrôleurs pour les prescriptions OG (Œil Gauche)
  final _ogVlSphereController = TextEditingController();
  final _ogVlCylinderController = TextEditingController();
  final _ogVlAxisController = TextEditingController();
  final _ogVpSphereController = TextEditingController();
  final _ogVpCylinderController = TextEditingController();
  final _ogVpAxisController = TextEditingController();

  // Contrôleurs pour les informations de paiement
  final _totalAmountController = TextEditingController();
  final _advancePaymentController = TextEditingController();
  final _tintController = TextEditingController();

  // Variables d'état
  String _paymentMethod = 'cash';
  final bool _isLoading = false;
  double _remainingAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // Initialiser les informations client
    if (widget.customer != null) {
      _customerNameController.text = widget.customer!.name;
      _customerPhoneController.text = widget.customer!.phone ?? '';
    }

    // Initialiser le montant total
    _totalAmountController.text = widget.cart.total.toStringAsFixed(2);
    _advancePaymentController.text = '0';

    // Calculer le montant restant
    _calculateRemainingAmount();

    // Écouter les changements des montants
    _totalAmountController.addListener(_calculateRemainingAmount);
    _advancePaymentController.addListener(_calculateRemainingAmount);
  }

  void _calculateRemainingAmount() {
    final total = double.tryParse(_totalAmountController.text) ?? 0.0;
    final advance = double.tryParse(_advancePaymentController.text) ?? 0.0;
    setState(() {
      _remainingAmount = total - advance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vente Optique'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _previewInvoice,
            tooltip: 'Aperçu facture',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCartSummary(),
              const SizedBox(height: 24),
              _buildCustomerSection(),
              const SizedBox(height: 24),
              _buildPrescriptionSection(),
              const SizedBox(height: 24),
              _buildPaymentSection(),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartSummary() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.visibility, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Produits sélectionnés',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.cart.items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.product.name} x${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${(item.unitPrice * item.quantity).toStringAsFixed(2)} DA',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.cart.total.toStringAsFixed(2)} DA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Informations Client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Nom du client *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Le nom du client est requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerPhoneController,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.visibility_outlined, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Prescription Optique',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // OD (Œil Droit)
            _buildEyeSection('OD (Œil Droit)', Colors.blue.shade50, [
              _buildPrescriptionRow(
                'VL',
                _odVlSphereController,
                _odVlCylinderController,
                _odVlAxisController,
              ),
              _buildPrescriptionRow(
                'VP',
                _odVpSphereController,
                _odVpCylinderController,
                _odVpAxisController,
              ),
            ]),

            const SizedBox(height: 16),

            // OG (Œil Gauche)
            _buildEyeSection('OG (Œil Gauche)', Colors.green.shade50, [
              _buildPrescriptionRow(
                'VL',
                _ogVlSphereController,
                _ogVlCylinderController,
                _ogVlAxisController,
              ),
              _buildPrescriptionRow(
                'VP',
                _ogVpSphereController,
                _ogVpCylinderController,
                _ogVpAxisController,
              ),
            ]),

            const SizedBox(height: 16),

            // Teinte
            TextFormField(
              controller: _tintController,
              decoration: const InputDecoration(
                labelText: 'Teinte',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.palette),
                hintText: 'Ex: Bleu, Gris, Photochromique...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEyeSection(
    String title,
    Color backgroundColor,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPrescriptionRow(
    String label,
    TextEditingController sphereController,
    TextEditingController cylinderController,
    TextEditingController axisController,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: sphereController,
              decoration: const InputDecoration(
                labelText: 'Sphère',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: cylinderController,
              decoration: const InputDecoration(
                labelText: 'Cylindre',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: axisController,
              decoration: const InputDecoration(
                labelText: 'Axe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Informations de Paiement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _totalAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Prix total *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sell),
                      suffixText: 'DA',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Prix requis';
                      }
                      if (double.tryParse(value!) == null) {
                        return 'Prix invalide';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _advancePaymentController,
                    decoration: const InputDecoration(
                      labelText: 'Arrhes versées',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                      suffixText: 'DA',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _remainingAmount > 0
                    ? Colors.orange.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _remainingAmount > 0
                      ? Colors.orange.shade300
                      : Colors.green.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Montant restant:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_remainingAmount.toStringAsFixed(2)} DA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _remainingAmount > 0
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Méthode de paiement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'cash',
                  label: Text('Espèces'),
                  icon: Icon(Icons.money),
                ),
                ButtonSegment(
                  value: 'card',
                  label: Text('Carte'),
                  icon: Icon(Icons.credit_card),
                ),
                ButtonSegment(
                  value: 'mixed',
                  label: Text('Mixte'),
                  icon: Icon(Icons.payments),
                ),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _paymentMethod = selection.first;
                });
              },
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
          child: OutlinedButton.icon(
            icon: const Icon(Icons.preview),
            label: const Text('Aperçu'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
            onPressed: _previewInvoice,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print),
            label: const Text('Imprimer & Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: _isLoading ? null : _processOpticalSale,
          ),
        ),
      ],
    );
  }

  void _previewInvoice() {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      builder: (context) => _OpticalInvoicePreviewDialog(
        customerName: _customerNameController.text,
        customerPhone: _customerPhoneController.text,
        cart: widget.cart,
        totalAmount: double.tryParse(_totalAmountController.text) ?? 0.0,
        advancePayment: double.tryParse(_advancePaymentController.text) ?? 0.0,
        remainingAmount: _remainingAmount,
        tint: _tintController.text,
        prescriptions: _getPrescriptions(),
        paymentMethod: _paymentMethod,
      ),
    );
  }

  Map<String, String> _getPrescriptions() {
    return {
      'od_vl':
          '${_odVlSphereController.text} ${_odVlCylinderController.text} ${_odVlAxisController.text}',
      'od_vp':
          '${_odVpSphereController.text} ${_odVpCylinderController.text} ${_odVpAxisController.text}',
      'og_vl':
          '${_ogVlSphereController.text} ${_ogVlCylinderController.text} ${_ogVlAxisController.text}',
      'og_vp':
          '${_ogVpSphereController.text} ${_ogVpCylinderController.text} ${_ogVpAxisController.text}',
    };
  }

  void _processOpticalSale() async {
    try {
      final authService = context.read<AuthService>();
      final invoiceService = context.read<InvoiceService>();

      final invoice = await invoiceService.createOpticalInvoice(
        cart: widget.cart,
        customer: widget.customer,
        userId: authService.currentUser!.id.toString(),
      );

      if (invoice != null) {
        // Imprimer la facture optique
        final printerService = context.read<UsbPrinterService>();
        if (printerService.isConnected) {
          bool printed = await printerService.printInvoice(invoice);
          if (!printed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Facture enregistrée mais erreur d\'impression'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imprimante non connectée'),
              backgroundColor: Colors.orange,
            ),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vente optique enregistrée avec succès!'),
              backgroundColor: Colors.green,
            ),
          );

          // Retourner à l'écran de vente principal
          context.pop();
        }
      } else {
        throw Exception('Erreur lors de l\'enregistrement de la facture');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _odVlSphereController.dispose();
    _odVlCylinderController.dispose();
    _odVlAxisController.dispose();
    _odVpSphereController.dispose();
    _odVpCylinderController.dispose();
    _odVpAxisController.dispose();
    _ogVlSphereController.dispose();
    _ogVlCylinderController.dispose();
    _ogVlAxisController.dispose();
    _ogVpSphereController.dispose();
    _ogVpCylinderController.dispose();
    _ogVpAxisController.dispose();
    _totalAmountController.dispose();
    _advancePaymentController.dispose();
    _tintController.dispose();
    super.dispose();
  }
}

// Dialogue d'aperçu de la facture optique
class _OpticalInvoicePreviewDialog extends StatelessWidget {
  final String customerName;
  final String customerPhone;
  final Cart cart;
  final double totalAmount;
  final double advancePayment;
  final double remainingAmount;
  final String tint;
  final Map<String, String> prescriptions;
  final String paymentMethod;

  const _OpticalInvoicePreviewDialog({
    required this.customerName,
    required this.customerPhone,
    required this.cart,
    required this.totalAmount,
    required this.advancePayment,
    required this.remainingAmount,
    required this.tint,
    required this.prescriptions,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aperçu Facture Optique'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête MK OPTIQUE
              Center(
                child: Column(
                  children: [
                    Text(
                      'MK OPTIQUE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade600,
                      ),
                    ),
                    const Text('Rue Didouche Mourad'),
                    const Text('à côté protection Civile el-hadjar'),
                    const Text('MOB: 06.63.90.47.96'),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Informations client
              Text('M: $customerName'),
              if (customerPhone.isNotEmpty) Text('N° tél: $customerPhone'),

              const SizedBox(height: 16),

              // Prix et paiement
              Text('Prix: ${totalAmount.toStringAsFixed(2)} DA'),
              Text('Reste: ${remainingAmount.toStringAsFixed(2)} DA'),
              Text('Arrhes: ${advancePayment.toStringAsFixed(2)} DA'),
              if (tint.isNotEmpty) Text('Teinte: $tint'),

              const SizedBox(height: 16),

              // Date
              Text(
                'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              ),

              const SizedBox(height: 16),

              // Prescriptions
              if (prescriptions['od_vl']?.trim().isNotEmpty ?? false)
                Text('OD: VL ${prescriptions['od_vl']}'),
              if (prescriptions['og_vl']?.trim().isNotEmpty ?? false)
                Text('OG: VL ${prescriptions['og_vl']}'),
              if (prescriptions['od_vp']?.trim().isNotEmpty ?? false)
                Text('OD: VP ${prescriptions['od_vp']}'),
              if (prescriptions['og_vp']?.trim().isNotEmpty ?? false)
                Text('OG: VP ${prescriptions['og_vp']}'),

              const SizedBox(height: 16),

              // Message de bas de page
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Toute commande confirmée ne pourra être',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'annulée passé le délai de 03 Mois',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      'la maison décline toute responsabilité',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}
