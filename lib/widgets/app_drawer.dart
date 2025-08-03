import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../services.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;

    return Drawer(
      child: Column(
        children: [
          // En-tête
          UserAccountsDrawerHeader(
            accountName: Text(
              currentUser?.fullName ?? currentUser?.username ?? '',
            ),
            accountEmail: Text(currentUser?.role.name.toUpperCase() ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: AppColors.primary, size: 40),
            ),
            decoration: const BoxDecoration(color: AppColors.primary),
          ),

          // Menu principal
          Expanded(
            child: ListView(
              children: [
                _buildDrawerItem(
                  context,
                  'Tableau de Bord',
                  Icons.dashboard,
                  '/dashboard',
                ),
                _buildDrawerItem(
                  context,
                  'Nouvelle Vente',
                  Icons.point_of_sale,
                  '/sale/new',
                ),
                _buildDrawerItem(
                  context,
                  'Produits',
                  Icons.inventory_2,
                  '/products',
                ),
                _buildDrawerItem(
                  context,
                  'Clients',
                  Icons.people,
                  '/customers',
                ),
                _buildDrawerItem(
                  context,
                  'Factures',
                  Icons.receipt_long,
                  '/invoices',
                ),
                _buildDrawerItem(
                  context,
                  'Prescriptions',
                  Icons.medical_services,
                  '/prescriptions',
                ),
                const Divider(),
                _buildDrawerItem(
                  context,
                  'Gestion Stock',
                  Icons.warehouse,
                  '/products/stock',
                ),
                _buildDrawerItem(
                  context,
                  'Rapports',
                  Icons.analytics,
                  '/reports',
                ),
                const Divider(),
                _buildDrawerItem(
                  context,
                  'Paramètres',
                  Icons.settings,
                  '/settings',
                ),
                if (authService.isProprietaire)
                  _buildDrawerItem(
                    context,
                    'Sauvegarde',
                    Icons.backup,
                    '/backup',
                  ),
              ],
            ),
          ),

          // Pied de page
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Déconnexion'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context); // Close drawer
    if (route.startsWith('/dashboard/')) {
      // For nested routes
      context.go(route);
    } else {
      // For main routes
      context.push(route);
    }
  }

  Widget _buildDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    final isSelected = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.fullPath.startsWith(route);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }

  void _logout(BuildContext context) async {
    Navigator.of(context).pop();
    await context.read<AuthService>().logout();
    if (context.mounted) {
      context.go('/login');
    }
  }
}
