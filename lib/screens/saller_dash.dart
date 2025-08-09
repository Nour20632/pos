import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/services/auth_service.dart';
import 'package:provider/provider.dart';

// Seller dashboard
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentTime = DateTime.now();
    final greeting = _getGreeting(currentTime.hour);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFFF8FAFC)],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(authService, greeting),

              // Main Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWelcomeMessage(),
                            const SizedBox(height: 32),
                            _buildQuickActions(),
                            const SizedBox(height: 32),
                            _buildTodayStats(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthService authService, String greeting) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and Title
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  // Replace deprecated withOpacity
                  color: Colors.white.withAlpha(51), // ~0.2
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MK OPTIQUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'Point de Vente',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),

          // User Menu
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51), // ~0.2
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Text(authService.currentUser?.fullName ?? 'Profil'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Déconnexion', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    final authService = context.watch<AuthService>();
    final userName = authService.currentUser?.fullName ?? 'Vendeur';
    final greeting = _getGreeting(DateTime.now().hour);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100.withAlpha(128), // ~0.5
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _getGreetingIcon(DateTime.now().hour),
              color: Colors.blue.shade700,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $userName!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Prêt pour une nouvelle journée de ventes',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on, color: Color(0xFF3B82F6), size: 24),
            SizedBox(width: 8),
            Text(
              'Actions Rapides',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            // Vente Produits
            Expanded(
              child: _buildActionCard(
                'Vente Produits',
                'Vente rapide produits',
                Icons.shopping_cart_rounded,
                const Color(0xFF059669),
                () => context.push('/vente-produits'),
              ),
            ),
            const SizedBox(width: 16),
            // Vente Lunettes sur Ordonnance
            Expanded(
              child: _buildActionCard(
                'Vente Lunettes Ordonnance',
                'Vente sur ordonnance',
                Icons.visibility,
                const Color(0xFF3B82F6),
                () => context.push('/create-optical-order'),
              ),
            ),
            const SizedBox(width: 16),
            // Lunettes à fabriquer
            Expanded(
              child: _buildActionCard(
                'Lunettes à fabriquer',
                'Liste des lunettes à fabriquer',
                Icons.assignment_turned_in,
                const Color(0xFF8B5CF6),
                () => context.push('/optical-order'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(26), // ~0.1
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: color.withAlpha(51)), // ~0.2
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(26), // ~0.1
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_ios, color: color, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.today, color: Color(0xFF3B82F6), size: 24),
            SizedBox(width: 8),
            Text(
              'Aujourd\'hui',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildStatItem(
                Icons.shopping_bag_outlined,
                'Ventes réalisées',
                '0',
                const Color(0xFF059669),
              ),
              const Divider(height: 32),
              _buildStatItem(
                Icons.schedule,
                'Heure de connexion',
                _getFormattedTime(),
                const Color(0xFF3B82F6),
              ),
              const Divider(height: 32),
              _buildStatItem(
                Icons.calendar_today,
                'Date',
                _getFormattedDate(),
                const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26), // ~0.1
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods
  String _getGreeting(int hour) {
    if (hour < 12) return 'Bonjour';
    if (hour < 17) return 'Bon après-midi';
    return 'Bonsoir';
  }

  IconData _getGreetingIcon(int hour) {
    if (hour < 12) return Icons.wb_sunny;
    if (hour < 17) return Icons.wb_sunny_outlined;
    return Icons.nights_stay;
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    final months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Jun',
      'Jul',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    return '${days[now.weekday % 7]} ${now.day} ${months[now.month - 1]}';
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
        // Show profile info
        _showProfileDialog();
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  void _showProfileDialog() {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Profil Utilisateur'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileItem('Nom complet', user?.fullName ?? 'N/A'),
            const SizedBox(height: 12),
            _buildProfileItem('Nom d\'utilisateur', user?.username ?? 'N/A'),
            const SizedBox(height: 12),
            _buildProfileItem('Rôle', 'Vendeur'),
            const SizedBox(height: 12),
            _buildProfileItem(
              'Dernière connexion',
              user?.lastLogin != null
                  ? _formatDateTime(user!.lastLogin!.toIso8601String())
                  : 'Première connexion',
            ),
          ],
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

  Widget _buildProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Déconnexion'),
          ],
        ),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<AuthService>().logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }
}
