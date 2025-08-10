import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mk_optique/screens/add_customer.dart';
import 'package:mk_optique/screens/add_product.dart';
import 'package:mk_optique/screens/create_optical_order_screen.dart';
import 'package:mk_optique/screens/customer.dart';
import 'package:mk_optique/screens/dashboard.dart';
import 'package:mk_optique/screens/edit_customer_screen.dart';
import 'package:mk_optique/screens/invoice_detail_screen.dart';
import 'package:mk_optique/screens/invoice_screen.dart';
import 'package:mk_optique/screens/login.dart';
import 'package:mk_optique/screens/new_sale_screen.dart';
import 'package:mk_optique/screens/optical_orders_screen.dart';
import 'package:mk_optique/screens/products.dart';
import 'package:mk_optique/screens/report.dart';
import 'package:mk_optique/screens/settings.dart';
import 'package:mk_optique/screens/stock_management.dart';
import 'package:mk_optique/services/auth_service.dart';
import 'package:mk_optique/services/customer_service.dart';
import 'package:mk_optique/services/invoice_service.dart';
import 'package:mk_optique/services/prescription_service.dart';
import 'package:mk_optique/services/product_service.dart';
import 'package:mk_optique/services/report_service.dart';
import 'package:mk_optique/services/scanner_service.dart';
import 'package:mk_optique/services/service_manager.dart';
import 'package:mk_optique/services/stock_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database.dart';
import 'screens/edit_product_screen.dart';
import 'screens/label_printing_screen.dart';
import 'screens/saller_dash.dart';

// Thème personnalisé de l'application
class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    fontFamily: GoogleFonts.roboto().fontFamily,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    fontFamily: GoogleFonts.roboto().fontFamily,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E293B),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration pour Windows/Linux/Mac (sqflite_common_ffi)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Configuration du système
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialisation de la base de données
  final databaseHelper = DatabaseHelper();
  await databaseHelper.initDatabase();

  // Initialisation des préférences
  final prefs = await SharedPreferences.getInstance();

  runApp(MKOptiquePOSApp(databaseHelper: databaseHelper, prefs: prefs));
}

class MKOptiquePOSApp extends StatelessWidget {
  final DatabaseHelper databaseHelper;
  final SharedPreferences prefs;

  const MKOptiquePOSApp({
    super.key,
    required this.databaseHelper,
    required this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseHelper>.value(value: databaseHelper),
        Provider<SharedPreferences>.value(value: prefs),
        ChangeNotifierProvider(create: (_) => AuthService(databaseHelper)),
        ChangeNotifierProvider(create: (_) => ProductService(databaseHelper)),
        ChangeNotifierProvider(create: (_) => CustomerService(databaseHelper)),
        ChangeNotifierProvider(create: (_) => InvoiceService(databaseHelper)),
        ChangeNotifierProvider(create: (_) => ScannerService()),
        ChangeNotifierProvider(create: (_) => ReportService(databaseHelper)),
        ChangeNotifierProvider(create: (_) => StockService(databaseHelper)),
        ChangeNotifierProvider(
          create: (_) => PrescriptionService(databaseHelper),
        ),
        ChangeNotifierProvider(
          create: (_) => MKOptiqueServiceManager(databaseHelper),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp.router(
            title: 'MK Optique POS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _getThemeMode(context),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('fr', 'FR'), Locale('ar', 'DZ')],
            locale: const Locale('fr', 'FR'),
            routerConfig: _createRouter(authService),
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(BuildContext context) {
    final prefs = Provider.of<SharedPreferences>(context, listen: false);
    final isDark = prefs.getBool('isDarkMode') ?? false;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  GoRouter _createRouter(AuthService authService) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isAuthenticated = authService.isAuthenticated;
        final isOnLoginPage = state.uri.path == '/login';

        // Si pas connecté et pas sur la page de connexion
        if (!isAuthenticated && !isOnLoginPage) {
          return '/login';
        }

        // Si connecté et sur la page de connexion
        if (isAuthenticated && isOnLoginPage) {
          return authService.isProprietaire
              ? '/dashboard'
              : '/seller-dashboard';
        }

        return null; // Aucune redirection
      },
      routes: <GoRoute>[
        // Page de connexion
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),

        // Tableaux de bord
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/seller-dashboard',
          builder: (context, state) => const SellerDashboardScreen(),
        ),

        // Gestion des produits
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddProductScreen(),
            ),
            GoRoute(
              path: 'edit/:id',
              builder: (context, state) => EditProductScreen(
                productId: int.parse(state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: 'stock',
              builder: (context, state) => const StockManagementScreen(),
            ),
            GoRoute(
              path: 'labels',
              builder: (context, state) => const LabelPrintingScreen(),
            ),
          ],
        ),

        // Gestion des clients
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersScreen(),
        ),
        GoRoute(
          path: '/add-customer',
          builder: (context, state) => const AddCustomerScreen(),
        ),
        GoRoute(
          path: '/edit-customer/:id',
          builder: (context, state) => EditCustomerScreen(
            customerId: int.parse(state.pathParameters['id']!),
          ),
        ),

        // Ventes
        GoRoute(
          path: '/sale',
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const NewSaleScreen(),
            ),
          ],
        ),

        // Factures
        GoRoute(
          path: '/invoices',
          builder: (context, state) => const InvoicesScreen(),
          routes: [
            GoRoute(
              path: 'detail/:id',
              builder: (context, state) => InvoiceDetailScreen(
                invoiceId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        ),

        // Lunettes optiques
        GoRoute(
          path: '/optical-order',
          builder: (context, state) => const OpticalOrdersScreen(),
        ),
        GoRoute(
          path: '/create-optical-order',
          builder: (context, state) => const CreateOpticalOrderScreen(),
        ),
        GoRoute(
          path: '/vente-lunettes',
          builder: (context, state) => const CreateOpticalOrderScreen(),
        ),
        GoRoute(
          path: '/lunettes-a-fabriquer',
          builder: (context, state) => const OpticalOrdersScreen(),
        ),

        // Rapports
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),

        // Paramètres
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'users',
              builder: (context, state) => const UsersManagementScreen(),
            ),
            GoRoute(
              path: 'profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // Sauvegarde
        GoRoute(
          path: '/backup',
          builder: (context, state) => const BackupScreen(),
        ),

        // Profil utilisateur
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
      errorBuilder: (context, state) => const ErrorScreen(),
    );
  }
}

// Écrans manquants - À créer
class UsersManagementScreen extends StatelessWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_rounded, size: 64, color: Color(0xFF6B7280)),
            SizedBox(height: 16),
            Text(
              'Gestion des Utilisateurs',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Fonctionnalité en cours de développement',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sauvegarde'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backup_rounded, size: 64, color: Color(0xFF6B7280)),
            SizedBox(height: 16),
            Text(
              'Sauvegarde des Données',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Fonctionnalité en cours de développement',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Utilisateur'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_rounded, size: 64, color: Color(0xFF6B7280)),
            SizedBox(height: 16),
            Text(
              'Profil Utilisateur',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Fonctionnalité en cours de développement',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

// Écran d'erreur personnalisé avec design moderne
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Erreur Application',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Désolé, une erreur inattendue s\'est produite.\nVeuillez redémarrer l\'application.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Retour au Tableau de Bord',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Configuration globale de l'application
class AppConfig {
  static const String appName = 'MK Optique POS';
  static const String version = '1.0.0';
  static const String companyName = 'MK OPTIQUE';
  static const String address =
      'Rue Didouche Mourad\nà côté Protection Civile El-Hadjar';
  static const String phone = '06.63.90.47.96';
}

// Helper pour créer AppBar unifié
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      centerTitle: centerTitle,
      elevation: 0,
      actions: actions,
      leading: leading,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Helper pour créer cartes unifiées
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
