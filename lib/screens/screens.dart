import 'package:flutter/material.dart';
import 'package:mk_optique/database.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services.dart';

// PrescriptionsScreen: تعرض قائمة prescriptions من الخدمة
class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Consumer<PrescriptionService>(
        builder: (context, prescriptionService, child) {
          final prescriptions = prescriptionService.prescriptions;
          if (prescriptions.isEmpty) {
            return const Center(child: Text('Aucune prescription trouvée'));
          }
          return ListView.builder(
            itemCount: prescriptions.length,
            itemBuilder: (context, index) {
              final p = prescriptions[index];
              return ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.teal),
                title: Text('Client: ${p.customerId}'),
                subtitle: Text('Date: ${p.createdAt.toString().split(' ')[0]}'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Naviguer vers l'ajout de prescription
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPrescriptionScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Prescription'),
        backgroundColor: Colors.teal.shade600,
      ),
    );
  }
}

// AddPrescriptionScreen: نموذج إضافة prescription (ربطه بالخدمة)
class AddPrescriptionScreen extends StatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _notesController = TextEditingController();

  Future<void> _savePrescription() async {
    setState(() => _isLoading = true);
    final prescription = Prescription(
      customerId: 1, // À remplacer par la sélection réelle du client
      notes: _notesController.text,
    );
    final service = context.read<PrescriptionService>();
    final success = await service.addPrescription(prescription);
    setState(() => _isLoading = false);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prescription ajoutée')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Prescription'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _savePrescription,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ReportsScreen: تعرض إحصائيات من ReportService
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  Widget _buildReportCard(
    String title,
    IconData icon,
    Color color,
    String value,
  ) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: context.read<ReportService>().getDashboardStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            children: [
              _buildReportCard(
                'Ventes Aujourd\'hui',
                Icons.trending_up,
                Colors.green,
                stats['todaySalesTotal']?.toString() ?? '0',
              ),
              _buildReportCard(
                'Stock Bas',
                Icons.warning,
                Colors.orange,
                stats['lowStockCount']?.toString() ?? '0',
              ),
              _buildReportCard(
                'Créances',
                Icons.account_balance,
                Colors.purple,
                stats['unpaidInvoicesTotal']?.toString() ?? '0',
              ),
              _buildReportCard(
                'Clients',
                Icons.people,
                Colors.indigo,
                '', // Ajoute ici une statistique client si besoin
              ),
            ],
          );
        },
      ),
    );
  }
}

// sales_report_screen.dart
class SalesReportScreen extends StatelessWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport des Ventes'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: context.read<ReportService>().getSalesReport(
          startDate: startOfMonth,
          endDate: now,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final salesList = snapshot.data!;
          if (salesList.isEmpty) {
            return const Center(child: Text('Aucune vente ce mois'));
          }
          return ListView.builder(
            itemCount: salesList.length,
            itemBuilder: (context, index) {
              final item = salesList[index];
              return ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: Text('Date: ${item['period']}'),
                subtitle: Text(
                  'Transactions: ${item['transaction_count']} | Total: ${item['total_sales']?.toStringAsFixed(2) ?? '0'} DA',
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// stock_report_screen.dart
class StockReportScreen extends StatelessWidget {
  const StockReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport de Stock'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: context.read<ReportService>().getStockReport(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stockList = snapshot.data!;
          if (stockList.isEmpty) {
            return const Center(child: Text('Aucun produit en stock'));
          }
          return ListView.builder(
            itemCount: stockList.length,
            itemBuilder: (context, index) {
              final item = stockList[index];
              return ListTile(
                leading: Icon(
                  item['stock_status'] == 'En rupture'
                      ? Icons.error
                      : (item['stock_status'] == 'Stock bas'
                            ? Icons.warning
                            : Icons.check_circle),
                  color: item['stock_status'] == 'En rupture'
                      ? Colors.red
                      : (item['stock_status'] == 'Stock bas'
                            ? Colors.orange
                            : Colors.green),
                ),
                title: Text(item['name']),
                subtitle: Text(
                  'Stock: ${item['quantity']} | Valeur: ${item['stock_value']?.toStringAsFixed(2) ?? '0'} DA',
                ),
                trailing: Text(item['stock_status']),
              );
            },
          );
        },
      ),
    );
  }
}

// FinancialReportScreen: 
class FinancialReportScreen extends StatelessWidget {
  const FinancialReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport Financier'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: context.read<ReportService>().getFinancialSummary(
          startDate: startOfMonth,
          endDate: now,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.green),
                title: const Text('Chiffre d\'affaires'),
                trailing: Text(
                  '${(data['totalRevenue'] ?? 0).toStringAsFixed(2)} DA',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.money_off, color: Colors.red),
                title: const Text('Coût des ventes'),
                trailing: Text(
                  '${(data['totalCost'] ?? 0).toStringAsFixed(2)} DA',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.blue),
                title: const Text('Profit'),
                trailing: Text(
                  '${(data['totalProfit'] ?? 0).toStringAsFixed(2)} DA',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.percent, color: Colors.orange),
                title: const Text('Marge bénéficiaire'),
                trailing: Text(
                  '${(data['profitMargin'] ?? 0).toStringAsFixed(2)} %',
                ),
              ),
              const Divider(),
              const ListTile(
                title: Text('Répartition par méthode de paiement'),
              ),
              ...((data['paymentMethods'] ?? []) as List).map<Widget>(
                (pm) => ListTile(
                  leading: const Icon(Icons.payment),
                  title: Text(pm['payment_method']),
                  subtitle: Text('Transactions: ${pm['transaction_count']}'),
                  trailing: Text(
                    '${(pm['total_amount'] ?? 0).toStringAsFixed(2)} DA',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// settings_screen.dart
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ربط الشاشة بالخدمات
    final printerService = context.watch<PrinterService>();
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Imprimante'),
            subtitle: Text(
              printerService.isConnected
                  ? 'Connectée: ${printerService.connectedPrinter?.name ?? ''}'
                  : 'Aucune imprimante connectée',
            ),
            trailing: ElevatedButton(
              onPressed: () => printerService.searchPrinters(),
              child: const Text('Chercher'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Utilisateur'),
            subtitle: Text(authService.currentUser?.fullName ?? ''),
          ),
          // ...باقي الإعدادات...
        ],
      ),
    );
  }
}

// printer_settings_screen.dart
class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final printerService = context.watch<PrinterService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres Imprimante'),
        backgroundColor: Colors.grey.shade600,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Imprimante connectée'),
            subtitle: Text(
              printerService.isConnected
                  ? printerService.connectedPrinter?.name ?? 'Connectée'
                  : 'Aucune imprimante connectée',
            ),
            trailing: printerService.isConnected
                ? TextButton(
                    onPressed: () => printerService.disconnect(),
                    child: const Text('Déconnecter'),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Rechercher Imprimantes'),
            onPressed: () => printerService.searchPrinters(),
          ),
          if (printerService.availablePrinters.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Imprimantes disponibles:'),
            ...printerService.availablePrinters.map(
              (printer) => ListTile(
                title: Text(printer.name),
                subtitle: Text(printer.macAdress),
                trailing: TextButton(
                  onPressed: () => printerService.connectToPrinter(printer),
                  child: const Text('Connecter'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// users_management_screen.dart
class UsersManagementScreen extends StatelessWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: FutureBuilder<List<User>>(
        future: context.read<DatabaseHelper>().getAllUsers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(child: Text('Aucun utilisateur trouvé'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: Icon(
                  user.role == UserRole.proprietaire
                      ? Icons.verified_user
                      : Icons.person,
                  color: user.role == UserRole.proprietaire
                      ? Colors.green
                      : Colors.blue,
                ),
                title: Text(user.fullName ?? user.username),
                subtitle: Text(user.role.name.toUpperCase()),
                trailing: user.isActive
                    ? const Icon(Icons.check, color: Colors.green)
                    : const Icon(Icons.block, color: Colors.red),
              );
            },
          );
        },
      ),
    );
  }
}

// backup_screen.dart
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbHelper = context.read<DatabaseHelper>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sauvegarde & Restauration'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.backup, color: Colors.green),
                title: const Text('Créer une sauvegarde'),
                subtitle: const Text('Exporter toutes les données'),
                trailing: ElevatedButton(
                  onPressed: () async {
                    final json = await dbHelper.exportDatabaseToJson();
                    // هنا يمكنك حفظ json في ملف أو مشاركته
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sauvegarde exportée')),
                    );
                  },
                  child: const Text('Sauvegarder'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.restore, color: Colors.blue),
                title: const Text('Restaurer les données'),
                subtitle: const Text('Importer depuis une sauvegarde'),
                trailing: ElevatedButton(
                  onPressed: () async {
                    // هنا يمكنك فتح ملف واستدعاء dbHelper.importDatabaseFromJson
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Restauration à implémenter'),
                      ),
                    );
                  },
                  child: const Text('Restaurer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
