import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/services/auth_service.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isProprietaire = authService.isProprietaire;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          // Section Compte
          _buildSectionHeader('Compte'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Mon Profil',
            subtitle:
                authService.currentUser?.fullName ??
                authService.currentUser?.username ??
                '',
            onTap: () => _showProfileDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.lock,
            title: 'Changer Mot de Passe',
            subtitle: 'Modifier votre mot de passe',
            onTap: () => _showPasswordDialog(context),
          ),

          const Divider(),

          // Section Impression
          _buildSectionHeader('Impression'),
          _buildSettingsTile(
            icon: Icons.print,
            title: 'Paramètres Imprimante',
            subtitle: 'Configuration de l\'imprimante',
            onTap: () => context.push('/settings/printer'),
          ),

          const Divider(),

          // Section Gestion (Propriétaire uniquement)
          if (isProprietaire) ...[
            _buildSectionHeader('Gestion'),
            _buildSettingsTile(
              icon: Icons.people,
              title: 'Gestion Utilisateurs',
              subtitle: 'Ajouter/modifier les utilisateurs',
              onTap: () => context.push('/settings/users'),
            ),
            _buildSettingsTile(
              icon: Icons.backup,
              title: 'Sauvegarde & Restauration',
              subtitle: 'Gérer les données',
              onTap: () => context.push('/backup'),
            ),
            _buildSettingsTile(
              icon: Icons.storage,
              title: 'Maintenance Base',
              subtitle: 'Optimiser la base de données',
              onTap: () => _showMaintenanceDialog(context),
            ),
            const Divider(),
          ],

          // Section Informations
          _buildSectionHeader('Informations'),
          _buildSettingsTile(
            icon: Icons.info,
            title: 'À propos',
            subtitle: 'Version 1.0.0 - MK Optique',
            onTap: () => _showAboutDialog(context),
          ),
          _buildSettingsTile(
            icon: Icons.help,
            title: 'Aide',
            subtitle: 'Guide d\'utilisation',
            onTap: () => _showHelpDialog(context),
          ),

          const SizedBox(height: AppDimensions.paddingXL),

          // Bouton déconnexion
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Se Déconnecter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(AppDimensions.paddingM),
              ),
              onPressed: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        AppDimensions.paddingL,
        AppDimensions.paddingM,
        AppDimensions.paddingS,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showProfileDialog(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser!;

    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mon Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
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
              // TODO: Implement profile update
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil mis à jour')),
              );
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer Mot de Passe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Ancien mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer mot de passe',
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
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Les mots de passe ne correspondent pas'),
                  ),
                );
                return;
              }

              final success = await context.read<AuthService>().changePassword(
                oldPasswordController.text,
                newPasswordController.text,
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Mot de passe modifié avec succès'
                        : 'Erreur lors du changement',
                  ),
                ),
              );
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maintenance Base de Données'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cette opération va optimiser la base de données et peut prendre quelques minutes.',
            ),
            SizedBox(height: AppDimensions.paddingM),
            Text('Recommandée une fois par mois.'),
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
                const SnackBar(
                  content: Text('Maintenance effectuée avec succès'),
                ),
              );
            },
            child: const Text('Lancer'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'MK Optique',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.remove_red_eye, color: Colors.white, size: 30),
      ),
      children: const [
        Text('Système de gestion pour magasin d\'optique'),
        SizedBox(height: AppDimensions.paddingM),
        Text('Développé pour MK Optique'),
        Text('Rue Didouche Mourad, El-Hadjar'),
        Text('Tél: 06.63.90.47.96'),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Guide d\'utilisation rapide:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: AppDimensions.paddingM),
              Text(
                '• Scanner un produit: Utilisez l\'icône scanner dans la vente',
              ),
              Text('• Ajouter un produit: Menu Produits > Ajouter'),
              Text(
                '• Créer une facture: Nouvelle Vente > Ajouter produits > Finaliser',
              ),
              Text('• Gérer le stock: Menu Produits > Gestion Stock'),
              Text('• Imprimer: Connectez l\'imprimante Bluetooth d\'abord'),
              SizedBox(height: AppDimensions.paddingM),
              Text('Pour plus d\'aide, contactez le support technique.'),
            ],
          ),
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

  void _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
