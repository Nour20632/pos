import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/services/auth_service.dart';
import 'package:provider/provider.dart';

import '../constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;

    return Drawer(
      width: 280,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A), // Blue-900
              Color(0xFF1E40AF), // Blue-800
            ],
          ),
        ),
        child: Column(
          children: [
            // En-tête moderne
            _buildModernHeader(currentUser),

            // Menu principal avec design moderne
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
                  children: [
                    _buildSectionHeader('Principal'),
                    _buildModernDrawerItem(
                      context,
                      'Tableau de Bord',
                      Icons.dashboard_rounded,
                      '/dashboard',
                      isMain: true,
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Nouvelle Vente',
                      Icons.shopping_cart_rounded,
                      '/sale/new',
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Vente Lunettes',
                      Icons.visibility_rounded,
                      '/create-optical-order',
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Lunettes à Fabriquer',
                      Icons.assignment_turned_in_rounded,
                      '/optical-order',
                    ),

                    const SizedBox(height: 20),
                    _buildSectionHeader('Gestion'),
                    _buildModernDrawerItem(
                      context,
                      'Produits',
                      Icons.inventory_2_rounded,
                      '/products',
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Clients',
                      Icons.people_rounded,
                      '/customers',
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Factures',
                      Icons.receipt_long_rounded,
                      '/invoices',
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Prescriptions',
                      Icons.medical_services_rounded,
                      '/prescriptions',
                    ),

                    const SizedBox(height: 20),
                    _buildSectionHeader('Outils'),
                    _buildModernDrawerItem(
                      context,
                      'Gestion Stock',
                      Icons.warehouse_rounded,
                      '/products/stock',
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Étiquettes Produits',
                      Icons.local_offer_rounded,
                      '/products/labels',
                    ),
                    _buildModernDrawerItem(
                      context,
                      'Rapports',
                      Icons.analytics_rounded,
                      '/reports',
                    ),

                    const SizedBox(height: 20),
                    _buildSectionHeader('Système'),
                    _buildModernDrawerItem(
                      context,
                      'Paramètres',
                      Icons.settings_rounded,
                      '/settings',
                    ),
                    if (authService.isProprietaire)
                      _buildModernDrawerItem(
                        context,
                        'Gestion Utilisateurs',
                        Icons.people_alt_rounded,
                        '/settings/users',
                      ),
                    if (authService.isProprietaire)
                      _buildModernDrawerItem(
                        context,
                        'Sauvegarde',
                        Icons.backup_rounded,
                        '/backup',
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Pied de page moderne
            _buildModernFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(dynamic currentUser) {
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar avec effet glassmorphism
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),

          const SizedBox(height: 16),

          // Informations utilisateur
          Text(
            currentUser?.fullName ?? currentUser?.username ?? 'Utilisateur',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              currentUser?.role.name.toUpperCase() ?? 'ROLE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModernDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    String route, {
    bool isMain = false,
  }) {
    final currentLocation = GoRouter.of(context).routerDelegate.currentConfiguration.fullPath;

    // Logique améliorée pour déterminer si l'élément est sélectionné
    bool isSelected = false;
    if (route == '/dashboard') {
      isSelected = currentLocation == '/dashboard' || currentLocation == '/seller-dashboard';
    } else {
      isSelected = currentLocation.startsWith(route) && currentLocation != '/dashboard' && currentLocation != '/seller-dashboard';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
        border: isSelected
            ? Border.all(color: AppColors.primary.withOpacity(0.2))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateTo(context, route, isMain: isMain),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : const Color(0xFF374151),
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFooter(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Version info avec design moderne
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'MK Optique POS v1.0.0',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bouton de déconnexion moderne
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _logout(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Déconnexion',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String route, {bool isMain = false}) {
    Navigator.of(context).pop(); // Fermer le drawer

    final currentLocation = GoRouter.of(context).routerDelegate.currentConfiguration.fullPath;

    // Ne pas naviguer si on est déjà sur la même page
    if (currentLocation == route) return;

    if (isMain || route == '/dashboard') {
      // Pour le dashboard et les pages principales - remplacer l'historique
      context.go(route);
    } else {
      // Pour les autres pages - navigation normale avec possibilité de retour
      context.push(route);
    }
  }

  void _logout(BuildContext context) async {
    Navigator.of(context).pop(); // Fermer le drawer

    // Dialog de confirmation avec design moderne
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Déconnexion',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Êtes-vous sûr de vouloir vous déconnecter de votre session ?',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Déconnecter',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<AuthService>().logout();
        if (context.mounted) {
          context.go('/login'); // Aller à login et effacer l'historique
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la déconnexion: $e'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }
}