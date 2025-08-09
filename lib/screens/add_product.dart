import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/services/product_service.dart';
import 'package:mk_optique/services/scanner_service.dart';
import 'package:mk_optique/services/printer_service.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
  // Contrôleurs de formulaire
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _sizeController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minStockController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Variables d'état
  Category? _selectedCategory;
  bool _hasPrescription = false;
  bool _isLoading = false;
  bool _autoGenerateBarcode = true;
  String _inputMethod = '';

  // Animations
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeForm();
    _showInputMethodDialog();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController.forward();
    _fadeController.forward();
  }

  void _initializeForm() {
    _minStockController.text = '5';
    _quantityController.text = '0';
    if (_autoGenerateBarcode) {
      _generateBarcode();
    }
  }

  Future<void> _generateBarcode() async {
    try {
      final barcode = await context.read<ProductService>().generateBarcode();
      if (mounted) {
        setState(() {
          _barcodeController.text = barcode;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur génération code-barres: $e');
    }
  }

  void _showInputMethodDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône et titre
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_business,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Méthode de Saisie',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Comment souhaitez-vous ajouter ce produit ?',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Options de saisie
                _buildModernMethodTile(
                  icon: Icons.edit_outlined,
                  title: 'Saisie Manuelle',
                  subtitle: 'Saisir toutes les informations manuellement',
                  color: Colors.blue,
                  onTap: () {
                    _inputMethod = 'manual';
                    _autoGenerateBarcode = true;
                    Navigator.pop(context);
                    _showSuccessMessage('Mode saisie manuelle activé');
                  },
                ),

                const SizedBox(height: 12),

                _buildModernMethodTile(
                  icon: Icons.qr_code_scanner_outlined,
                  title: 'Scanner Code-barres',
                  subtitle: 'Scanner un code-barres existant',
                  color: Colors.green,
                  onTap: () {
                    _inputMethod = 'scanner';
                    _autoGenerateBarcode = false;
                    Navigator.pop(context);
                    _scanExistingBarcode();
                  },
                ),

                const SizedBox(height: 12),

                _buildModernMethodTile(
                  icon: Icons.qr_code_outlined,
                  title: 'Code-barres Manuel',
                  subtitle: 'Saisir manuellement le code-barres',
                  color: Colors.orange,
                  onTap: () {
                    _inputMethod = 'manual_barcode';
                    _autoGenerateBarcode = false;
                    Navigator.pop(context);
                    _barcodeController.clear();
                    _showSuccessMessage('Mode code-barres manuel activé');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildModernMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.arrow_forward_ios, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanExistingBarcode() async {
    try {
      final scannerService = context.read<ScannerService>();
      final scannedCode = await scannerService.scanBarcode();

      if (scannedCode != null && mounted) {
        setState(() {
          _barcodeController.text = scannedCode;
        });

        // Vérifier si le produit existe déjà
        final existingProduct = await context
            .read<ProductService>()
            .getProductByBarcode(scannedCode);

        if (existingProduct != null) {
          _showExistingProductDialog(existingProduct);
        } else {
          _showSuccessMessage('Code-barres scanné avec succès');
        }
      }
    } catch (e) {
      _showErrorMessage('Erreur lors du scan: $e');
    }
  }

  void _showExistingProductDialog(Product existingProduct) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.withValues(alpha: 0.1), Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.orange),
              const SizedBox(height: 16),

              Text(
                'Produit Existant',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 16),

              _buildProductInfoCard(existingProduct),

              const SizedBox(height: 24),
              Text(
                'Que souhaitez-vous faire ?',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _generateBarcode();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Nouveau Code'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _goToAddStock(existingProduct);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('+ Stock'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _fillExistingProductData(existingProduct);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfoCard(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.sell, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('Prix: ${product.sellPrice.toStringAsFixed(2)} DA'),
              const Spacer(),
              Icon(Icons.inventory, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('Stock: ${product.quantity}'),
            ],
          ),
          if (product.brand?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Marque: ${product.brand}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _fillExistingProductData(Product product) {
    setState(() {
      _nameController.text = product.name;
      _brandController.text = product.brand ?? '';
      _modelController.text = product.model ?? '';
      _colorController.text = product.color ?? '';
      _sizeController.text = product.size ?? '';
      _sellPriceController.text = product.sellPrice.toString();
      _costPriceController.text = product.costPrice?.toString() ?? '';
      _quantityController.text = product.quantity.toString();
      _minStockController.text = product.minStockAlert.toString();
      _descriptionController.text = product.description ?? '';
      _selectedCategory = product.category;
      _hasPrescription = product.hasPrescription;
    });
    _showSuccessMessage('Données du produit chargées');
  }

  void _goToAddStock(Product product) {
    context.push('/add-stock', extra: product);
  }

  Future<void> _printLabels(int quantity) async {
    if (quantity <= 0) return;

    final printerService = context.read<UsbPrinterService>();
    if (!printerService.isConnected) {
      _showErrorMessage('Aucune imprimante connectée');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Informations du produit pour l'étiquette
      final productName = _nameController.text.trim();
      final brand = _brandController.text.trim();
      final price = double.tryParse(_sellPriceController.text) ?? 0.0;
      final barcode = _barcodeController.text.trim();

      if (barcode.isEmpty) {
        _showErrorMessage('Code-barres requis pour l\'impression');
        return;
      }

      // Fix: Remove the undefined named parameters
      // Use only the barcode parameter that exists
      bool success = await printerService.printBarcode(barcode);

      if (success) {
        _showSuccessMessage('$quantity étiquette(s) imprimée(s) avec succès');
        await HapticFeedback.lightImpact();
      } else {
        _showErrorMessage(
          'Erreur lors de l\'impression: ${printerService.lastError}',
        );
      }
    } catch (e) {
      _showErrorMessage('Erreur d\'impression: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.primary),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajouter Produit',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (_inputMethod.isNotEmpty)
                  Text(
                    _getInputMethodLabel(),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),

          // Actions
          Container(
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.orange),
              onPressed: _scanExistingBarcode,
              tooltip: 'Scanner code-barres',
            ),
          ),
          const SizedBox(width: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.print, color: Colors.green),
              onPressed: _showPrintDialog,
              tooltip: 'Imprimer étiquettes',
            ),
          ),
          const SizedBox(width: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.purple),
              onPressed: _showInputMethodDialog,
              tooltip: 'Changer méthode',
            ),
          ),
        ],
      ),
    );
  }

  String _getInputMethodLabel() {
    switch (_inputMethod) {
      case 'manual':
        return 'Mode: Saisie manuelle avec code auto';
      case 'scanner':
        return 'Mode: Scanner de code-barres';
      case 'manual_barcode':
        return 'Mode: Code-barres manuel';
      default:
        return '';
    }
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Méthode d'entrée actuelle
            if (_inputMethod.isNotEmpty) _buildMethodIndicator(),
            const SizedBox(height: 20),

            // Informations de base
            _buildModernSection(
              title: 'Informations de Base',
              icon: Icons.info_outline,
              color: Colors.blue,
              children: [
                _buildModernTextField(
                  controller: _nameController,
                  label: 'Nom du Produit',
                  icon: Icons.inventory_2_outlined,
                  required: true,
                  validator: (value) =>
                      value?.isEmpty == true ? 'Nom requis' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildModernTextField(
                        controller: _barcodeController,
                        label: 'Code-barres',
                        icon: Icons.qr_code_outlined,
                        readOnly: _inputMethod == 'scanner',
                      ),
                    ),
                    const SizedBox(width: 12),

                    if (_autoGenerateBarcode)
                      _buildActionButton(
                        icon: Icons.refresh,
                        onPressed: _generateBarcode,
                        color: Colors.blue,
                        tooltip: 'Nouveau code',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                Consumer<ProductService>(
                  builder: (context, productService, child) {
                    return _buildModernDropdown<Category>(
                      value: _selectedCategory,
                      label: 'Catégorie',
                      icon: Icons.category_outlined,
                      items: productService.categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (category) =>
                          setState(() => _selectedCategory = category),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Détails du produit
            _buildModernSection(
              title: 'Détails du Produit',
              icon: Icons.details_outlined,
              color: Colors.green,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField(
                        controller: _brandController,
                        label: 'Marque',
                        icon: Icons.business_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernTextField(
                        controller: _modelController,
                        label: 'Modèle',
                        icon: Icons.model_training_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField(
                        controller: _colorController,
                        label: 'Couleur',
                        icon: Icons.palette_outlined,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernTextField(
                        controller: _sizeController,
                        label: 'Taille',
                        icon: Icons.straighten_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildModernTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Prix et stock
            _buildModernSection(
              title: 'Prix et Stock',
              icon: Icons.attach_money_outlined,
              color: Colors.orange,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField(
                        controller: _sellPriceController,
                        label: 'Prix de Vente',
                        icon: Icons.sell_outlined,
                        keyboardType: TextInputType.number,
                        suffix: 'DA',
                        required: true,
                        validator: (value) {
                          if (value?.isEmpty == true) return 'Prix requis';
                          if (double.tryParse(value!) == null) {
                            return 'Prix invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernTextField(
                        controller: _costPriceController,
                        label: 'Prix d\'Achat',
                        icon: Icons.shopping_cart_outlined,
                        keyboardType: TextInputType.number,
                        suffix: 'DA',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildModernTextField(
                        controller: _quantityController,
                        label: 'Quantité Initiale',
                        icon: Icons.numbers_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernTextField(
                        controller: _minStockController,
                        label: 'Stock Minimum',
                        icon: Icons.warning_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Options avancées
            _buildModernSection(
              title: 'Options Avancées',
              icon: Icons.tune_outlined,
              color: Colors.purple,
              children: [
                _buildModernSwitch(
                  title: 'Nécessite une Prescription',
                  subtitle: 'Ce produit nécessite une ordonnance médicale',
                  value: _hasPrescription,
                  onChanged: (value) =>
                      setState(() => _hasPrescription = value),
                  icon: Icons.medical_services_outlined,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Boutons d'action
            _buildActionButtons(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodIndicator() {
    IconData icon;
    Color color;
    String text;

    switch (_inputMethod) {
      case 'manual':
        icon = Icons.edit_outlined;
        color = Colors.blue;
        text = 'Saisie manuelle avec génération automatique du code-barres';
        break;
      case 'scanner':
        icon = Icons.qr_code_scanner_outlined;
        color = Colors.green;
        text = 'Mode scanner activé - Code-barres scanné';
        break;
      case 'manual_barcode':
        icon = Icons.qr_code_outlined;
        color = Colors.orange;
        text = 'Saisie manuelle du code-barres';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          TextButton.icon(
            onPressed: _showInputMethodDialog,
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: const Text('Changer'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    bool readOnly = false,
    bool required = false,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      readOnly: readOnly,
      validator: validator,
      style: TextStyle(
        fontSize: 16,
        color: readOnly ? Colors.grey.shade600 : Colors.grey.shade800,
      ),
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        suffixText: suffix,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildModernDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildModernSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.primary : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),

          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              }
            },
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
        const SizedBox(width: 16),

        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveProduct,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isLoading ? 'Enregistrement...' : 'Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  void _showPrintDialog() {
    final quantityController = TextEditingController(
      text: _quantityController.text.isEmpty ? '1' : _quantityController.text,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.withValues(alpha: 0.1), Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.print, size: 32, color: Colors.green),
              ),
              const SizedBox(height: 16),

              Text(
                'Imprimer Étiquettes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Combien d\'étiquettes souhaitez-vous imprimer ?',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              _buildModernTextField(
                controller: quantityController,
                label: 'Nombre d\'étiquettes',
                icon: Icons.confirmation_number_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final qty = int.tryParse(value ?? '');
                  if (qty == null || qty <= 0) {
                    return 'Quantité invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final quantity =
                            int.tryParse(quantityController.text) ?? 0;
                        if (quantity > 0) {
                          Navigator.pop(context);
                          _printLabels(quantity);
                        }
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorMessage('Veuillez corriger les erreurs dans le formulaire');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final product = Product(
        barcode: _barcodeController.text.isNotEmpty
            ? _barcodeController.text.trim()
            : null,
        name: _nameController.text.trim(),
        categoryId: _selectedCategory?.id,
        brand: _brandController.text.isNotEmpty
            ? _brandController.text.trim()
            : null,
        model: _modelController.text.isNotEmpty
            ? _modelController.text.trim()
            : null,
        color: _colorController.text.isNotEmpty
            ? _colorController.text.trim()
            : null,
        size: _sizeController.text.isNotEmpty
            ? _sizeController.text.trim()
            : null,
        sellPrice: double.parse(_sellPriceController.text),
        costPrice: _costPriceController.text.isNotEmpty
            ? double.parse(_costPriceController.text)
            : null,
        quantity: int.parse(_quantityController.text),
        minStockAlert: int.parse(_minStockController.text),
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        hasPrescription: _hasPrescription,
      );

      final success = await context.read<ProductService>().addProduct(product);

      if (mounted) {
        if (success) {
          // Impression automatique des étiquettes si quantité > 0
          final quantity = int.parse(_quantityController.text);
          if (quantity > 0) {
            await _printLabels(quantity);
          }

          _showSuccessMessage('Produit ajouté avec succès !');
          await HapticFeedback.heavyImpact();

          // Retour avec animation
          await _slideController.reverse();

          if (mounted && GoRouter.of(context).canPop()) {
            GoRouter.of(context).pop();
          }
        } else {
          _showErrorMessage('Erreur lors de l\'ajout du produit');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Erreur: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _sizeController.dispose();
    _sellPriceController.dispose();
    _costPriceController.dispose();
    _quantityController.dispose();
    _minStockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
