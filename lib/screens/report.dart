import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/services/printer_service.dart';
import 'package:mk_optique/services/report_service.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../widgets/app_drawer.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _quickStats = {};

  @override
  void initState() {
    super.initState();
    _loadQuickStats();
  }

  Future<void> _loadQuickStats() async {
    final stats = await context.read<ReportService>().getDashboardStats();
    if (mounted) {
      setState(() {
        _quickStats = stats;
        _isLoading = false;
      });
    }
  }

  Widget _buildQuickStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showProductReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rapport Produits'),
        content: const Text(
          'Cette fonctionnalité sera disponible dans une prochaine version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showCustomerReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rapport Clients'),
        content: const Text(
          'Cette fonctionnalité sera disponible dans une prochaine version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exporter Données'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sélectionnez le format d\'export :'),
            SizedBox(height: AppDimensions.paddingM),
            Text('• Excel (.xlsx)\n• CSV (.csv)\n• PDF (.pdf)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export en cours...')),
              );
            },
            child: const Text('Exporter'),
          ),
        ],
      ),
    );
  }

  void _printReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imprimer Rapport'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choisissez le rapport à imprimer :'),
            SizedBox(height: AppDimensions.paddingM),
            Text('• Rapport quotidien\n• Rapport mensuel\n• Bilan de stock'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final usbPrinterService = context.read<UsbPrinterService>();
              if (!usbPrinterService.isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aucune imprimante connectée')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Impression en cours...')),
                );
              }
            },
            child: const Text('Imprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        backgroundColor: AppColors.primary,
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
            onPressed: _loadQuickStats,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistiques rapides
                  Text(
                    'Vue d\'ensemble',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: AppDimensions.paddingM,
                    mainAxisSpacing: AppDimensions.paddingM,
                    childAspectRatio: 1.3,
                    children: [
                      _buildQuickStatCard(
                        'Ventes Aujourd\'hui',
                        '${_quickStats['todaySalesCount'] ?? 0}',
                        '${(_quickStats['todaySalesTotal'] ?? 0).toStringAsFixed(0)} DA',
                        Icons.today,
                        AppColors.success,
                      ),
                      _buildQuickStatCard(
                        'Ventes du Mois',
                        '${_quickStats['monthSalesCount'] ?? 0}',
                        '${(_quickStats['monthSalesTotal'] ?? 0).toStringAsFixed(0)} DA',
                        Icons.calendar_month,
                        AppColors.primary,
                      ),
                      _buildQuickStatCard(
                        'Créances',
                        '${_quickStats['unpaidInvoicesCount'] ?? 0}',
                        '${(_quickStats['unpaidInvoicesTotal'] ?? 0).toStringAsFixed(0)} DA',
                        Icons.account_balance_wallet,
                        AppColors.warning,
                      ),
                      _buildQuickStatCard(
                        'Stock Bas',
                        '${_quickStats['lowStockCount'] ?? 0}',
                        'produits',
                        Icons.inventory,
                        AppColors.error,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Types de rapports
                  Text(
                    'Rapports Détaillés',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),

                  _buildReportCard(
                    'Rapport des Ventes',
                    'Analyse détaillée des ventes par période',
                    Icons.trending_up,
                    AppColors.success,
                    () => context.push('/reports/sales'),
                  ),

                  _buildReportCard(
                    'Rapport de Stock',
                    'État actuel du stock et mouvements',
                    Icons.warehouse,
                    AppColors.secondary,
                    () => context.push('/reports/stock'),
                  ),

                  _buildReportCard(
                    'Rapport Financier',
                    'Bilan financier et analyse des profits',
                    Icons.account_balance,
                    AppColors.primary,
                    () => context.push('/reports/financial'),
                  ),

                  _buildReportCard(
                    'Rapport Produits',
                    'Produits les plus vendus et performances',
                    Icons.shopping_bag,
                    AppColors.info,
                    () => _showProductReport(),
                  ),

                  _buildReportCard(
                    'Rapport Clients',
                    'Analyse de la clientèle et fidélité',
                    Icons.people,
                    AppColors.warning,
                    () => _showCustomerReport(),
                  ),

                  const SizedBox(height: AppDimensions.paddingXL),

                  // Actions rapides
                  Text(
                    'Actions Rapides',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.file_download),
                          label: const Text('Exporter Données'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(
                              AppDimensions.paddingM,
                            ),
                          ),
                          onPressed: _exportData,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingM),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Imprimer Rapport'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(
                              AppDimensions.paddingM,
                            ),
                          ),
                          onPressed: _printReport,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
