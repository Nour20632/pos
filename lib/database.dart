import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseHelper {
  static const String _databaseName = 'MK_optique.db';
  static const int _databaseVersion = 1;

  Database? _database;

  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> initDatabase() async {
    await database;
  }

  Future<void> _onOpen(Database db) async {
    // Activer les contraintes de clés étrangères
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _insertInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration de la base de données selon les versions
    if (oldVersion < newVersion) {
      // Exemple de migration future
      // await _upgradeToVersion2(db);
    }
  }

  Future<void> _createTables(Database db) async {
    // Table des utilisateurs
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('proprietaire', 'employe')),
        full_name TEXT,
        phone TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_login TEXT,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Table des catégories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Table des produits
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        category_id INTEGER,
        brand TEXT,
        model TEXT,
        color TEXT,
        size TEXT,
        sell_price REAL NOT NULL,
        cost_price REAL,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_stock_alert INTEGER DEFAULT 5,
        description TEXT,
        has_prescription INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Table des mouvements de stock
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        movement_type TEXT CHECK (movement_type IN ('entree', 'sortie', 'ajustement', 'retour')),
        quantity INTEGER NOT NULL,
        quantity_before INTEGER,
        quantity_after INTEGER,
        unit_cost REAL,
        total_cost REAL,
        reason TEXT,
        reference_number TEXT,
        user_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Table des clients
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        date_of_birth TEXT,
        gender TEXT CHECK (gender IN ('homme', 'femme')),
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Table des factures
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        customer_phone TEXT,
        invoice_type TEXT DEFAULT 'vente' CHECK (invoice_type IN ('vente', 'devis', 'retour')),
        payment_type TEXT DEFAULT 'comptant' CHECK (payment_type IN ('comptant', 'credit', 'mixte')),
        subtotal REAL NOT NULL DEFAULT 0,
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        total_amount REAL NOT NULL,
        paid_amount REAL DEFAULT 0,
        remaining_amount REAL DEFAULT 0,
        payment_status TEXT DEFAULT 'impaye' CHECK (payment_status IN ('paye', 'impaye', 'partiel', 'annule')),
        delivery_date TEXT,
        notes TEXT,
        user_id INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Table des détails de factures
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        product_barcode TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        total_price REAL NOT NULL,
        has_prescription INTEGER DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // Table des paiements
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        payment_method TEXT CHECK (payment_method IN ('especes', 'carte', 'cheque', 'virement')),
        amount REAL NOT NULL,
        payment_date TEXT DEFAULT CURRENT_TIMESTAMP,
        reference_number TEXT,
        notes TEXT,
        user_id INTEGER,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Table des prescriptions
    await db.execute('''
      CREATE TABLE prescriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER,
        customer_id INTEGER,
        od_sphere REAL,
        od_cylinder REAL,
        od_axis INTEGER,
        od_add REAL,
        os_sphere REAL,
        os_cylinder REAL,
        os_axis INTEGER,
        os_add REAL,
        pd_total REAL,
        pd_right REAL,
        pd_left REAL,
        vertex_distance REAL,
        pantoscopic_tilt REAL,
        wrap_angle REAL,
        lens_type TEXT,
        lens_material TEXT,
        coating TEXT,
        tint TEXT,
        doctor_name TEXT,
        prescription_date TEXT,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // Table des paramètres d'imprimante
    await db.execute('''
      CREATE TABLE printer_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        printer_name TEXT NOT NULL,
        printer_type TEXT CHECK (printer_type IN ('bluetooth', 'wifi', 'usb')),
        connection_string TEXT,
        paper_width INTEGER DEFAULT 80,
        is_default INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Table des templates d'impression
    await db.execute('''
      CREATE TABLE print_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_name TEXT NOT NULL,
        template_type TEXT CHECK (template_type IN ('facture', 'devis', 'etiquette', 'prescription')),
        header_text TEXT,
        footer_text TEXT,
        logo_path TEXT,
        is_default INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Création des index pour optimiser les performances
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Index sur les codes-barres des produits
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');

    // Index sur les numéros de facture
    await db.execute(
      'CREATE INDEX idx_invoices_number ON invoices(invoice_number)',
    );

    // Index sur les dates de création
    await db.execute(
      'CREATE INDEX idx_invoices_created_at ON invoices(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_movements_created_at ON stock_movements(created_at)',
    );

    // Index sur les clients
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');

    // Index sur les relations
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_movements_product ON stock_movements(product_id)',
    );
  }

  Future<void> _insertInitialData(Database db) async {
    // Données initiales des catégories
    final categories = [
      "('Verres de Vue', 'Verres correcteurs pour lunettes de vue')",
      "('Verres Solaires', 'Verres teintés et de soleil')",
      "('Montures Vue', 'Montures pour lunettes de vue')",
      "('Montures Solaires', 'Montures pour lunettes de soleil')",
      "('Lentilles', 'Lentilles de contact')",
      "('Accessoires', 'Étuis, chiffons, cordons, etc.')",
      "('Montres', 'Montres diverses')",
      "('Réparations', 'Services de réparation')",
    ];

    for (String category in categories) {
      await db.execute(
        'INSERT INTO categories (name, description) VALUES $category',
      );
    }

    // Utilisateur administrateur par défaut
    final hashedPassword = _hashPassword('admin123');
    await db.execute('''
      INSERT INTO users (username, password, role, full_name) 
      VALUES ('admin', '$hashedPassword', 'proprietaire', 'Administrateur MK')
    ''');

    // ==== إضافة حساب بائع افتراضي ====
    final hashedSellerPassword = _hashPassword('vendeur123');
    await db.execute('''
      INSERT INTO users (username, password, role, full_name) 
      VALUES ('vendeur', '$hashedSellerPassword', 'employe', 'vendeur')
    ''');

    // Paramètres d'imprimante par défaut
    await db.execute('''
      INSERT INTO printer_settings (printer_name, printer_type, paper_width, is_default) 
      VALUES ('Smart Thermal Printer', 'bluetooth', 80, 1)
    ''');

    // Templates d'impression par défaut
    await db.execute('''
      INSERT INTO print_templates (template_name, template_type, header_text, footer_text, is_default) 
      VALUES (
        'Facture MK',
        'facture', 
        'MK OPTIQUE\nRue Didouche Mourad\nà côté protection Civile el-hadjar\nMOB: 06.63.90.47.96', 
        'Toute commande confirmée ne pourra être annulée\npassé le délai de 03 Mois la maison\ndécline toute responsabilité', 
        1
      )
    ''');

    await db.execute('''
      INSERT INTO print_templates (template_name, template_type, header_text, footer_text, is_default) 
      VALUES ('Étiquette Produit', 'etiquette', 'MK OPTIQUE', '', 1)
    ''');
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyPassword(String password, String hashedPassword) {
    return _hashPassword(password) == hashedPassword;
  }

  // ==================== MÉTHODES UTILISATEURS ====================
  Future<User?> authenticateUser(String username, String password) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      final user = User.fromMap(maps.first);
      if (_verifyPassword(password, user.password)) {
        // Mettre à jour la dernière connexion
        await updateLastLogin(user.id!);
        return user;
      }
    }
    return null;
  }

  Future<void> updateLastLogin(int userId) async {
    final db = await database;
    await db.update(
      'users',
      {'last_login': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return maps.map((map) => User.fromMap(map)).toList();
  }

  Future<int> insertUser(User user) async {
    final db = await database;
    final userMap = user.toMap();
    userMap['password'] = _hashPassword(userMap['password']);
    return await db.insert('users', userMap);
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    final userMap = user.toMap();
    if (userMap['password'] != null) {
      userMap['password'] = _hashPassword(userMap['password']);
    }
    await db.update('users', userMap, where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.update(
      'users',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== MÉTHODES CATÉGORIES ====================
  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('categories');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== MÉTHODES PRODUITS ====================
  Future<List<Product>> getAllProducts({bool includeInactive = false}) async {
    final db = await database;
    String whereClause = includeInactive ? '' : 'WHERE p.is_active = 1';

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.name as category_name, c.description as category_description
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      $whereClause
      ORDER BY p.name
    ''');

    return maps.map((map) {
      final product = Product.fromMap(map);
      if (map['category_name'] != null) {
        product.category = Category(
          id: map['category_id'],
          name: map['category_name'],
          description: map['category_description'],
        );
      }
      return product;
    }).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT p.*, c.name as category_name, c.description as category_description
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.id = ?
    ''',
      [id],
    );

    if (maps.isNotEmpty) {
      final product = Product.fromMap(maps.first);
      if (maps.first['category_name'] != null) {
        product.category = Category(
          id: maps.first['category_id'],
          name: maps.first['category_name'],
          description: maps.first['category_description'],
        );
      }
      return product;
    }
    return null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT p.*, c.name as category_name, c.description as category_description
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.barcode = ? AND p.is_active = 1
    ''',
      [barcode],
    );

    if (maps.isNotEmpty) {
      final product = Product.fromMap(maps.first);
      if (maps.first['category_name'] != null) {
        product.category = Category(
          id: maps.first['category_id'],
          name: maps.first['category_name'],
          description: maps.first['category_description'],
        );
      }
      return product;
    }
    return null;
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT p.*, c.name as category_name, c.description as category_description
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1 
      AND (p.name LIKE ? OR p.barcode LIKE ? OR p.brand LIKE ? OR p.model LIKE ?)
      ORDER BY p.name
    ''',
      ['%$query%', '%$query%', '%$query%', '%$query%'],
    );

    return maps.map((map) {
      final product = Product.fromMap(map);
      if (map['category_name'] != null) {
        product.category = Category(
          id: map['category_id'],
          name: map['category_name'],
          description: map['category_description'],
        );
      }
      return product;
    }).toList();
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*, c.name as category_name, c.description as category_description
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1 AND p.quantity <= p.min_stock_alert
      ORDER BY p.quantity
    ''');

    return maps.map((map) {
      final product = Product.fromMap(map);
      if (map['category_name'] != null) {
        product.category = Category(
          id: map['category_id'],
          name: map['category_name'],
          description: map['category_description'],
        );
      }
      return product;
    }).toList();
  }

  Future<int> insertProduct(Product product) async {
    try {
      final db = await database;
      final productMap = product.toMap();
      productMap.remove('id');
      return await db.insert('products', productMap);
    } catch (e) {
      debugPrint('Erreur insertion produit: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    final productMap = product.toMap();
    productMap['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'products',
      productMap,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> generateProductBarcode() async {
    final db = await database;
    String barcode = '';
    bool exists = true;

    while (exists) {
      // Générer un code-barres de 13 chiffres (EAN-13 simplifié)
      final result = await db.query(
        'products',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      exists = result.isNotEmpty;
    }

    return barcode;
  }

  // ==================== MÉTHODES MOUVEMENTS DE STOCK ====================
  Future<void> addStockMovement(StockMovement movement) async {
    final db = await database;
    await db.transaction((txn) async {
      // Insérer le mouvement
      await txn.insert('stock_movements', movement.toMap());

      // Mettre à jour la quantité du produit
      await txn.update(
        'products',
        {
          'quantity': movement.quantityAfter,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [movement.productId],
      );
    });
  }

  Future<List<StockMovement>> getStockMovements({
    int? productId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (productId != null) {
      whereClause += 'WHERE sm.product_id = ?';
      whereArgs.add(productId);
    }

    if (startDate != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'sm.created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'sm.created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT sm.*, p.name as product_name, u.full_name as user_name
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      LEFT JOIN users u ON sm.user_id = u.id
      $whereClause
      ORDER BY sm.created_at DESC
      LIMIT $limit
    ''', whereArgs);

    return maps.map((map) => StockMovement.fromMap(map)).toList();
  }

  // ==================== MÉTHODES CLIENTS ====================
  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      orderBy: 'name',
    );
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    final customerMap = customer.toMap();
    customerMap.remove('id');
    return await db.insert('customers', customerMap);
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== MÉTHODES FACTURES ====================
  Future<String> generateInvoiceNumber() async {
    final db = await database;
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');

    // Compter les factures du mois
    final count = await db.rawQuery(
      '''
      SELECT COUNT(*) as count FROM invoices 
      WHERE invoice_number LIKE ?
    ''',
      ['F$year$month%'],
    );

    final nextNumber = (count.first['count'] as int) + 1;
    return 'F$year$month${nextNumber.toString().padLeft(4, '0')}';
  }

  Future<int> insertInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final db = await database;
    int invoiceId = 0;

    await db.transaction((txn) async {
      // Insérer la facture
      final invoiceMap = invoice.toMap();
      invoiceMap.remove('id');
      invoiceId = await txn.insert('invoices', invoiceMap);

      // Insérer les items
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['invoice_id'] = invoiceId;
        itemMap.remove('id');
        await txn.insert('invoice_items', itemMap);

        // Décrémenter le stock uniquement si c'est une vente confirmée
        if (invoice.invoiceType == InvoiceType.vente &&
            invoice.paymentStatus != PaymentStatus.annule) {
          await txn.rawUpdate(
            '''
            UPDATE products 
            SET quantity = quantity - ?, updated_at = ?
            WHERE id = ?
          ''',
            [item.quantity, DateTime.now().toIso8601String(), item.productId],
          );

          // Ajouter un mouvement de stock
          final movement = StockMovement(
            productId: item.productId!,
            movementType: StockMovementType.sortie,
            quantity: item.quantity,
            quantityBefore: 0, // Sera calculé
            quantityAfter: 0, // Sera calculé
            reason: 'Vente - Facture ${invoice.invoiceNumber}',
            referenceNumber: invoice.invoiceNumber,
            userId: invoice.userId,
          );

          // Récupérer la quantité actuelle pour le mouvement
          final currentQty = await txn.rawQuery(
            'SELECT quantity FROM products WHERE id = ?',
            [item.productId],
          );
          if (currentQty.isNotEmpty &&
              (currentQty.first['quantity'] as int) < item.quantity) {
            throw Exception(
              'Stock insuffisant pour le produit ${item.productName}',
            );
          }

          if (currentQty.isNotEmpty) {
            final qty = currentQty.first['quantity'] as int;
            final movementMap = movement.toMap();
            movementMap['quantity_before'] = qty + item.quantity;
            movementMap['quantity_after'] = qty;
            movementMap.remove('id');
            await txn.insert('stock_movements', movementMap);
          }
        }
      }
    });

    return invoiceId;
  }

  Future<List<Invoice>> getAllInvoices({
    DateTime? startDate,
    DateTime? endDate,
    InvoiceType? type,
    PaymentStatus? status,
    int limit = 100,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'i.created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'i.created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (type != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'i.invoice_type = ?';
      whereArgs.add(type.name);
    }

    if (status != null) {
      whereClause += whereClause.isEmpty ? 'WHERE ' : ' AND ';
      whereClause += 'i.payment_status = ?';
      whereArgs.add(status.name);
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT i.*, c.name as customer_name_full, u.full_name as user_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      LEFT JOIN users u ON i.user_id = u.id
      $whereClause
      ORDER BY i.created_at DESC
      LIMIT $limit
    ''', whereArgs);

    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT i.*, c.name as customer_name_full, u.full_name as user_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      LEFT JOIN users u ON i.user_id = u.id
      WHERE i.id = ?
    ''',
      [id],
    );

    if (maps.isNotEmpty) {
      final invoice = Invoice.fromMap(maps.first);

      // Charger les items
      final itemMaps = await db.rawQuery(
        '''
        SELECT ii.*, p.name as product_name_full
        FROM invoice_items ii
        LEFT JOIN products p ON ii.product_id = p.id
        WHERE ii.invoice_id = ?
      ''',
        [id],
      );

      invoice.items = itemMaps.map((map) => InvoiceItem.fromMap(map)).toList();

      return invoice;
    }
    return null;
  }

  Future<void> updateInvoicePaymentStatus(
    int invoiceId,
    PaymentStatus status,
    double paidAmount,
  ) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE invoices 
      SET payment_status = ?, paid_amount = ?, remaining_amount = total_amount - ?
      WHERE id = ?
    ''',
      [status.name, paidAmount, paidAmount, invoiceId],
    );
  }

  // ==================== MÉTHODES PAIEMENTS ====================
  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    return await db.insert('payments', payment.toMap());
  }

  Future<List<Payment>> getInvoicePayments(int invoiceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'payment_date DESC',
    );
    return maps.map((map) => Payment.fromMap(map)).toList();
  }

  // ==================== MÉTHODES PRESCRIPTIONS ====================
  Future<int> insertPrescription(Prescription prescription) async {
    final db = await database;
    final prescriptionMap = prescription.toMap();
    prescriptionMap.remove('id');
    return await db.insert('prescriptions', prescriptionMap);
  }

  Future<List<Prescription>> getCustomerPrescriptions(int customerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'prescriptions',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Prescription.fromMap(map)).toList();
  }

  Future<void> updatePrescription(Prescription prescription) async {
    final db = await database;
    await db.update(
      'prescriptions',
      prescription.toMap(),
      where: 'id = ?',
      whereArgs: [prescription.id],
    );
  }

  // ==================== MÉTHODES PARAMÈTRES ====================
  Future<List<PrinterSettings>> getAllPrinterSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('printer_settings');
    return maps.map((map) => PrinterSettings.fromMap(map)).toList();
  }

  Future<PrinterSettings?> getDefaultPrinter() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'printer_settings',
      where: 'is_default = 1',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PrinterSettings.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertPrinterSettings(PrinterSettings settings) async {
    final db = await database;
    return await db.insert('printer_settings', settings.toMap());
  }

  Future<List<PrintTemplate>> getAllPrintTemplates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('print_templates');
    return maps.map((map) => PrintTemplate.fromMap(map)).toList();
  }

  Future<PrintTemplate?> getDefaultTemplate(TemplateType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'print_templates',
      where: 'template_type = ? AND is_default = 1',
      whereArgs: [type.name],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PrintTemplate.fromMap(maps.first);
    }
    return null;
  }

  // ==================== RAPPORTS ET STATISTIQUES ====================
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final startOfMonth = DateTime(today.year, today.month, 1);

    // Ventes du jour
    final todaySales = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, COALESCE(SUM(total_amount), 0) as total
      FROM invoices 
      WHERE created_at >= ? AND invoice_type = 'vente' AND payment_status != 'annule'
    ''',
      [startOfDay.toIso8601String()],
    );

    // Ventes du mois
    final monthSales = await db.rawQuery(
      '''
      SELECT COUNT(*) as count, COALESCE(SUM(total_amount), 0) as total
      FROM invoices 
      WHERE created_at >= ? AND invoice_type = 'vente' AND payment_status != 'annule'
    ''',
      [startOfMonth.toIso8601String()],
    );

    // Stock bas
    final lowStock = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM products 
      WHERE is_active = 1 AND quantity <= min_stock_alert
    ''');

    // Créances en cours
    final unpaidInvoices = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(remaining_amount), 0) as total
      FROM invoices 
      WHERE payment_status IN ('impaye', 'partiel')
    ''');

    // Produits les plus vendus ce mois
    final topProducts = await db.rawQuery(
      '''
      SELECT p.name, SUM(ii.quantity) as total_sold
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      JOIN products p ON ii.product_id = p.id
      WHERE i.created_at >= ? AND i.payment_status != 'annule'
      GROUP BY p.id, p.name
      ORDER BY total_sold DESC
      LIMIT 5
    ''',
      [startOfMonth.toIso8601String()],
    );

    return {
      'todaySalesCount': todaySales.first['count'],
      'todaySalesTotal': todaySales.first['total'],
      'monthSalesCount': monthSales.first['count'],
      'monthSalesTotal': monthSales.first['total'],
      'lowStockCount': lowStock.first['count'],
      'unpaidInvoicesCount': unpaidInvoices.first['count'],
      'unpaidInvoicesTotal': unpaidInvoices.first['total'],
      'topProducts': topProducts,
    };
  }

  Future<List<Map<String, dynamic>>> getSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String groupBy = 'day', // day, week, month
  }) async {
    final db = await database;
    String dateFormat;

    switch (groupBy) {
      case 'week':
        dateFormat = '%Y-%W';
        break;
      case 'month':
        dateFormat = '%Y-%m';
        break;
      default:
        dateFormat = '%Y-%m-%d';
    }

    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT 
        strftime('$dateFormat', created_at) as period,
        COUNT(*) as transaction_count,
        SUM(total_amount) as total_sales,
        AVG(total_amount) as average_sale,
        SUM(CASE WHEN payment_status = 'paye' THEN total_amount ELSE 0 END) as paid_sales,
        SUM(CASE WHEN payment_status IN ('impaye', 'partiel') THEN remaining_amount ELSE 0 END) as pending_amount
      FROM invoices 
      WHERE created_at >= ? AND created_at <= ? 
        AND invoice_type = 'vente' 
        AND payment_status != 'annule'
      GROUP BY strftime('$dateFormat', created_at)
      ORDER BY period
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    return result;
  }

  Future<List<Map<String, dynamic>>> getProductSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    int? categoryId,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];

    if (categoryId != null) {
      whereClause = 'AND p.category_id = ?';
      whereArgs.add(categoryId);
    }

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.brand,
        p.sell_price,
        p.cost_price,
        c.name as category_name,
        SUM(ii.quantity) as quantity_sold,
        SUM(ii.total_price) as total_revenue,
        SUM(ii.quantity * COALESCE(p.cost_price, 0)) as total_cost,
        SUM(ii.total_price - (ii.quantity * COALESCE(p.cost_price, 0))) as total_profit
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      JOIN products p ON ii.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE i.created_at >= ? AND i.created_at <= ? 
        AND i.payment_status != 'annule'
        $whereClause
      GROUP BY p.id, p.name, p.brand, p.sell_price, p.cost_price, c.name
      ORDER BY quantity_sold DESC
    ''', whereArgs);

    return result;
  }

  Future<List<Map<String, dynamic>>> getStockReport() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        p.id,
        p.name,
        p.brand,
        p.barcode,
        p.quantity,
        p.min_stock_alert,
        p.sell_price,
        p.cost_price,
        c.name as category_name,
        p.quantity * COALESCE(p.cost_price, 0) as stock_value,
        CASE 
          WHEN p.quantity = 0 THEN 'En rupture'
          WHEN p.quantity <= p.min_stock_alert THEN 'Stock bas'
          ELSE 'Stock normal'
        END as stock_status
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_active = 1
      ORDER BY p.quantity ASC, p.name
    ''');

    return result;
  }

  Future<Map<String, dynamic>> getFinancialSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;

    // Chiffre d'affaires
    final revenue = await db.rawQuery(
      '''
      SELECT 
        SUM(total_amount) as total_revenue,
        SUM(CASE WHEN payment_status = 'paye' THEN total_amount ELSE 0 END) as paid_revenue,
        SUM(remaining_amount) as pending_revenue
      FROM invoices 
      WHERE created_at >= ? AND created_at <= ? 
        AND invoice_type = 'vente' 
        AND payment_status != 'annule'
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // Coût des ventes
    final costs = await db.rawQuery(
      '''
      SELECT 
        SUM(ii.quantity * COALESCE(p.cost_price, 0)) as total_cost
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      JOIN products p ON ii.product_id = p.id
      WHERE i.created_at >= ? AND i.created_at <= ? 
        AND i.payment_status != 'annule'
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // Répartition par méthode de paiement
    final paymentMethods = await db.rawQuery(
      '''
      SELECT 
        payment_method,
        COUNT(*) as transaction_count,
        SUM(amount) as total_amount
      FROM payments p
      JOIN invoices i ON p.invoice_id = i.id
      WHERE p.payment_date >= ? AND p.payment_date <= ?
      GROUP BY payment_method
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final totalRevenue = (revenue.first['total_revenue'] ?? 0) as num;
    final totalCost = (costs.first['total_cost'] ?? 0) as num;
    final totalProfit = totalRevenue - totalCost;

    return {
      'totalRevenue': totalRevenue,
      'paidRevenue': revenue.first['paid_revenue'] ?? 0,
      'pendingRevenue': revenue.first['pending_revenue'] ?? 0,
      'totalCost': totalCost,
      'totalProfit': totalProfit,
      'profitMargin': totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0,
      'paymentMethods': paymentMethods,
    };
  }

  // ==================== SAUVEGARDE ET RESTAURATION ====================
  Future<String> exportDatabaseToJson() async {
    final db = await database;

    // Exporter toutes les tables principales
    final tables = [
      'users',
      'categories',
      'products',
      'customers',
      'invoices',
      'invoice_items',
      'payments',
      'prescriptions',
      'stock_movements',
      'printer_settings',
      'print_templates',
    ];

    Map<String, dynamic> exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'version': _databaseVersion,
    };

    for (String table in tables) {
      final data = await db.query(table);
      exportData[table] = data;
    }

    return jsonEncode(exportData);
  }

  Future<bool> importDatabaseFromJson(String jsonData) async {
    try {
      final db = await database;
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      await db.transaction((txn) async {
        // Vider les tables existantes (sauf configuration)
        final tablesToClear = [
          'stock_movements',
          'invoice_items',
          'payments',
          'prescriptions',
          'invoices',
          'customers',
          'products',
          'categories',
        ];

        for (String table in tablesToClear) {
          await txn.delete(table);
        }

        // Restaurer les données
        for (String table in tablesToClear.reversed) {
          if (data.containsKey(table)) {
            final tableData = data[table] as List<dynamic>;
            for (Map<String, dynamic> row in tableData) {
              await txn.insert(table, row);
            }
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('Erreur importation: $e');
      return false;
    }
  }

  // ==================== UTILITAIRES ====================
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<bool> isDatabaseEmpty() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM products WHERE is_active = 1
    ''');
    return (result.first['count'] as int) == 0;
  }

  Future<Map<String, int>> getTableCounts() async {
    final db = await database;
    final tables = ['users', 'categories', 'products', 'customers', 'invoices'];
    Map<String, int> counts = {};

    for (String table in tables) {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
      counts[table] = result.first['count'] as int;
    }

    return counts;
  }

  // ==================== AUTO-MAINTENANCE ====================
  Future<void> performMaintenance() async {
    final db = await database;

    // Nettoyer les anciens logs de mouvement de stock (garder 1 an)
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    await db.delete(
      'stock_movements',
      where: 'created_at < ?',
      whereArgs: [oneYearAgo.toIso8601String()],
    );

    // Optimiser la base de données
    await db.execute('ANALYZE');
    await vacuum();
  }

  // ==================== VALIDATION DES DONNÉES ====================
  Future<List<String>> validateData() async {
    final db = await database;
    List<String> errors = [];

    // Vérifier les produits sans prix
    final productsWithoutPrice = await db.query(
      'products',
      where: 'sell_price <= 0 AND is_active = 1',
    );
    if (productsWithoutPrice.isNotEmpty) {
      errors.add(
        '${productsWithoutPrice.length} produit(s) sans prix de vente',
      );
    }

    // Vérifier les factures avec montant négatif
    final negativeInvoices = await db.query(
      'invoices',
      where: 'total_amount < 0',
    );
    if (negativeInvoices.isNotEmpty) {
      errors.add('${negativeInvoices.length} facture(s) avec montant négatif');
    }

    // Vérifier les incohérences de stock
    final stockInconsistencies = await db.rawQuery('''
      SELECT p.id, p.name, p.quantity,
        COALESCE(SUM(CASE WHEN sm.movement_type IN ('entree', 'retour') THEN sm.quantity ELSE 0 END), 0) as entries,
        COALESCE(SUM(CASE WHEN sm.movement_type IN ('sortie', 'ajustement') THEN sm.quantity ELSE 0 END), 0) as exits
      FROM products p
      LEFT JOIN stock_movements sm ON p.id = sm.product_id
      WHERE p.is_active = 1
      GROUP BY p.id, p.name, p.quantity
      HAVING p.quantity != (entries - exits) AND (entries > 0 OR exits > 0)
    ''');

    if (stockInconsistencies.isNotEmpty) {
      errors.add(
        '${stockInconsistencies.length} produit(s) avec incohérence de stock',
      );
    }

    return errors;
  }
}
