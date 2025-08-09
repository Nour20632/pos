import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mk_optique/models.dart';
import 'package:mk_optique/screens/add_customer.dart';
import 'package:mk_optique/screens/add_product.dart';
import 'package:mk_optique/screens/customer.dart';
import 'package:mk_optique/screens/dashboard.dart';
import 'package:mk_optique/screens/edit_method.dart';
import 'package:mk_optique/screens/invoice.dart';
import 'package:mk_optique/screens/login.dart';
import 'package:mk_optique/screens/new_sale.dart';
import 'package:mk_optique/screens/products.dart';
import 'package:mk_optique/screens/sale.dart';
import 'package:mk_optique/screens/screens.dart';
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

// Thème personnalisé de l'application
class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    fontFamily: GoogleFonts.roboto().fontFamily,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    fontFamily: GoogleFonts.roboto().fontFamily,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ajout pour Windows/Linux/Mac (sqflite_common_ffi)
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
            supportedLocales: const [Locale('fr', 'DZ'), Locale('ar', 'DZ')],
            locale: const Locale('fr', 'DZ'),
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
      initialLocation: authService.isAuthenticated ? '/dashboard' : '/login',
      redirect: (context, state) {
        final isLoggedIn = authService.isAuthenticated;
        final isGoingToLogin = state.uri.toString() == '/login';

        // Rediriger vers login si pas connecté
        if (!isLoggedIn && !isGoingToLogin) {
          return '/login';
        }

        // Rediriger vers dashboard si connecté et sur login
        if (isLoggedIn && isGoingToLogin) {
          return '/dashboard';
        }

        return null;
      },
      routes: <GoRoute>[
        // Route de connexion
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),

        // Route principale - Dashboard
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),

        // Routes de vente
        GoRoute(
          path: '/sale',
          builder: (context, state) => OpticalSaleScreen(cart: Cart()),
        ),

        GoRoute(
          path: '/optical-sale',
          builder: (context, state) {
            final Map<String, dynamic> extra =
                state.extra as Map<String, dynamic>;
            return OpticalSaleScreen(
              cart: extra['cart'] as Cart,
              customer: extra['customer'] as Customer?,
            );
          },
        ),

        // البيع الجديد - إصلاح المسار
        GoRoute(
          path: '/sale/new',
          builder: (context, state) => const NewSaleScreen(),
        ),

        // Routes produits
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsScreen(),
        ),
        GoRoute(
          path: '/products/add',
          builder: (context, state) => const AddProductScreen(),
        ),
        GoRoute(
          path: '/products/edit/:id',
          builder: (context, state) => EditProductScreen(
            productId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/products/stock',
          builder: (context, state) => const StockManagementScreen(),
        ),
        GoRoute(
          path: '/products/labels',
          builder: (context, state) => const LabelPrintingScreen(),
        ),

        // Routes clients
        GoRoute(
          path: '/customers',
          builder: (context, state) => const CustomersScreen(),
        ),
        GoRoute(
          path: '/customers/add',
          builder: (context, state) => const AddCustomerScreen(),
        ),
        GoRoute(
          path: '/customers/edit/:id',
          builder: (context, state) => EditCustomerScreen(
            customerId: int.parse(state.pathParameters['id']!),
          ),
        ),

        // Routes prescriptions
        GoRoute(
          path: '/prescriptions',
          builder: (context, state) => const PrescriptionsScreen(),
        ),
        GoRoute(
          path: '/prescriptions/add',
          builder: (context, state) => const AddPrescriptionScreen(),
        ),

        // Routes factures
        GoRoute(
          path: '/invoices',
          builder: (context, state) => const InvoicesScreen(),
        ),
        GoRoute(
          path: '/invoices/detail/:id',
          builder: (context, state) => InvoiceDetailScreen(
            invoiceId: int.parse(state.pathParameters['id']!),
          ),
        ),

        // Routes rapports
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/reports/sales',
          builder: (context, state) => const SalesReportScreen(),
        ),
        GoRoute(
          path: '/reports/stock',
          builder: (context, state) => const StockReportScreen(),
        ),
        GoRoute(
          path: '/reports/financial',
          builder: (context, state) => const FinancialReportScreen(),
        ),

        // Routes paramètres
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/printer',
          builder: (context, state) => const PrinterSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/users',
          builder: (context, state) => const UsersManagementScreen(),
        ),

        // Route de sauvegarde/restauration
        GoRoute(
          path: '/backup',
          builder: (context, state) => const BackupScreen(),
        ),
      ],
      errorBuilder: (context, state) => const ErrorScreen(),
    );
  }
}

// إنشاء wrapper للـ screens مع back button
class AppScreenWrapper extends StatelessWidget {
  final Widget child;
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  const AppScreenWrapper({
    super.key,
    required this.child,
    required this.title,
    this.showBackButton = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: actions,
      ),
      body: child,
    );
  }
}

// Écran d'erreur personnalisé مع back button
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreenWrapper(
      title: 'Erreur',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Une erreur s\'est produite',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Veuillez redémarrer l\'application',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Retour au tableau de bord'),
            ),
          ],
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
      'Rue Didouche Mourad\nà côté protection Civile el-hadjar';
  static const String phone = '06.63.90.47.96';
}

// Wrapper pour les écrans avec gestion du bouton de retour
class AppWrapper extends StatelessWidget {
  final Widget child;
  const AppWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    // Use routerState to get current location
    final location = GoRouterState.of(context).uri.toString();

    if (location == '/login') {
      return child;
    }

    return Stack(
      children: [
        child,
        if (router.canPop())
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: FloatingActionButton.small(
              backgroundColor: Colors.black.withOpacity(0.7),
              child: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => router.pop(),
            ),
          ),
      ],
    );
  }
}
