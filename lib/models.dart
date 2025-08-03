import 'package:flutter/foundation.dart';

// ==================== MODÈLE UTILISATEUR ====================
class User {
  User({
    this.id,
    required this.username,
    required this.password,
    required this.role,
    this.fullName,
    this.phone,
    DateTime? createdAt,
    this.lastLogin,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      role: UserRole.values.firstWhere((e) => e.name == map['role']),
      fullName: map['full_name'],
      phone: map['phone'],
      createdAt: DateTime.parse(map['created_at']),
      lastLogin: map['last_login'] != null
          ? DateTime.parse(map['last_login'])
          : null,
      isActive: map['is_active'] == 1,
    );
  }

  final DateTime createdAt;
  final String? fullName;
  final int? id;
  final bool isActive;
  final DateTime? lastLogin;
  final String password;
  final String? phone;
  final UserRole role;
  final String username;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role.name,
      'full_name': fullName,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    UserRole? role,
    String? fullName,
    String? phone,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum UserRole { proprietaire, employe }

// ==================== MODÈLE CATÉGORIE ====================
class Category {
  Category({this.id, required this.name, this.description, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  final DateTime createdAt;
  final String? description;
  final int? id;
  final String name;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// ==================== MODÈLE PRODUIT ====================
class Product {
  Product({
    this.id,
    this.barcode,
    required this.name,
    this.categoryId,
    this.brand,
    this.model,
    this.color,
    this.size,
    required this.sellPrice,
    this.costPrice,
    this.quantity = 0,
    this.minStockAlert = 5,
    this.description,
    this.hasPrescription = false,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.category,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      categoryId: map['category_id'],
      brand: map['brand'],
      model: map['model'],
      color: map['color'],
      size: map['size'],
      sellPrice: (map['sell_price'] as num).toDouble(),
      costPrice: map['cost_price'] != null ? (map['cost_price'] as num).toDouble() : null,
      quantity: map['quantity'] ?? 0,
      minStockAlert: map['min_stock_alert'] ?? 5,
      description: map['description'],
      hasPrescription: map['has_prescription'] == 1,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  final String? barcode;
  final String? brand;
  // Relations
  Category? category;

  final int? categoryId;
  final String? color;
  final double? costPrice;
  final DateTime createdAt;
  final String? description;
  final bool hasPrescription;
  final int? id;
  final bool isActive;
  final int minStockAlert;
  final String? model;
  final String name;
  final int quantity;
  final double sellPrice;
  final String? size;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'category_id': categoryId,
      'brand': brand,
      'model': model,
      'color': color,
      'size': size,
      'sell_price': sellPrice,
      'cost_price': costPrice,
      'quantity': quantity,
      'min_stock_alert': minStockAlert,
      'description': description,
      'has_prescription': hasPrescription ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    int? categoryId,
    String? brand,
    String? model,
    String? color,
    String? size,
    double? sellPrice,
    double? costPrice,
    int? quantity,
    int? minStockAlert,
    String? description,
    bool? hasPrescription,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Category? category,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      color: color ?? this.color,
      size: size ?? this.size,
      sellPrice: sellPrice ?? this.sellPrice,
      costPrice: costPrice ?? this.costPrice,
      quantity: quantity ?? this.quantity,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      description: description ?? this.description,
      hasPrescription: hasPrescription ?? this.hasPrescription,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
    );
  }

  bool get isLowStock => quantity <= minStockAlert;

  double get margin => costPrice != null ? sellPrice - costPrice! : 0;

  double get marginPercentage => costPrice != null && costPrice! > 0
      ? ((sellPrice - costPrice!) / costPrice!) * 100
      : 0;
}

// ==================== MODÈLE MOUVEMENT DE STOCK ====================
class StockMovement {
  StockMovement({
    this.id,
    required this.productId,
    required this.movementType,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    this.unitCost,
    this.totalCost,
    this.reason,
    this.referenceNumber,
    this.userId,
    DateTime? createdAt,
    this.product,
    this.user,
  }) : createdAt = createdAt ?? DateTime.now();

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'],
      productId: map['product_id'],
      movementType: StockMovementType.values.firstWhere(
        (e) => e.name == map['movement_type'],
      ),
      quantity: map['quantity'],
      quantityBefore: map['quantity_before'],
      quantityAfter: map['quantity_after'],
      unitCost: map['unit_cost'] != null
          ? (map['unit_cost'] as num).toDouble()
          : null,
      totalCost: map['total_cost'] != null
          ? (map['total_cost'] as num).toDouble()
          : null,
      reason: map['reason'],
      referenceNumber: map['reference_number'],
      userId: map['user_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  final DateTime createdAt;
  final int? id;
  final StockMovementType movementType;
  // Relations
  Product? product;

  final int productId;
  final int quantity;
  final int quantityAfter;
  final int quantityBefore;
  final String? reason;
  final String? referenceNumber;
  final double? totalCost;
  final double? unitCost;
  User? user;
  final int? userId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'movement_type': movementType.name,
      'quantity': quantity,
      'quantity_before': quantityBefore,
      'quantity_after': quantityAfter,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'reason': reason,
      'reference_number': referenceNumber,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum StockMovementType { entree, sortie, ajustement, retour }

// ==================== MODÈLE CLIENT ====================
class Customer {
  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.dateOfBirth,
    this.gender,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      dateOfBirth: map['date_of_birth'] != null
          ? DateTime.parse(map['date_of_birth'])
          : null,
      gender: map['gender'] != null
          ? Gender.values.firstWhere((e) => e.name == map['gender'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  final String? address;
  final DateTime createdAt;
  final DateTime? dateOfBirth;
  final String? email;
  final Gender? gender;
  final int? id;
  final String name;
  final String? phone;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'gender': gender?.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    DateTime? dateOfBirth,
    Gender? gender,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum Gender { homme, femme }

// ==================== MODÈLE FACTURE ====================
class Invoice {
  Invoice({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.invoiceType = InvoiceType.vente,
    this.paymentType = PaymentType.comptant,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    required this.totalAmount,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.paymentStatus = PaymentStatus.impaye,
    this.deliveryDate,
    this.notes,
    this.userId,
    DateTime? createdAt,
    this.customer,
    this.user,
    List<InvoiceItem>? items,
  }) : createdAt = createdAt ?? DateTime.now() {
    if (items != null) this.items = items;
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      customerId: map['customer_id'],
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      invoiceType: InvoiceType.values.firstWhere(
        (e) => e.name == map['invoice_type'],
      ),
      paymentType: PaymentType.values.firstWhere(
        (e) => e.name == map['payment_type'],
      ),
      subtotal: (map['subtotal'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      remainingAmount: (map['remaining_amount'] as num).toDouble(),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['payment_status'],
      ),
      deliveryDate: map['delivery_date'] != null
          ? DateTime.parse(map['delivery_date'])
          : null,
      notes: map['notes'],
      userId: map['user_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  final DateTime createdAt;
  // Relations
  Customer? customer;

  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final DateTime? deliveryDate;
  final double discountAmount;
  final int? id;
  final String invoiceNumber;
  final InvoiceType invoiceType;
  List<InvoiceItem> items = [];
  final String? notes;
  final double paidAmount;
  final PaymentStatus paymentStatus;
  final PaymentType paymentType;
  final double remainingAmount;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  User? user;
  final int? userId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'invoice_type': invoiceType.name,
      'payment_type': paymentType.name,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'payment_status': paymentStatus.name,
      'delivery_date': deliveryDate?.toIso8601String().split('T')[0],
      'notes': notes,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    int? customerId,
    String? customerName,
    String? customerPhone,
    InvoiceType? invoiceType,
    PaymentType? paymentType,
    double? subtotal,
    double? discountAmount,
    double? taxAmount,
    double? totalAmount,
    double? paidAmount,
    double? remainingAmount,
    PaymentStatus? paymentStatus,
    DateTime? deliveryDate,
    String? notes,
    int? userId,
    DateTime? createdAt,
    Customer? customer,
    User? user,
    List<InvoiceItem>? items,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      invoiceType: invoiceType ?? this.invoiceType,
      paymentType: paymentType ?? this.paymentType,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      user: user ?? this.user,
      items: items ?? this.items,
    );
  }

  bool get isPaid => paymentStatus == PaymentStatus.paye;

  bool get isPartiallyPaid => paymentStatus == PaymentStatus.partiel;

  bool get isUnpaid => paymentStatus == PaymentStatus.impaye;

  bool get isCancelled => paymentStatus == PaymentStatus.annule;

  bool get needsPayment => remainingAmount > 0;
}

enum InvoiceType { vente, devis, retour }

enum PaymentType { comptant, credit, mixte }

enum PaymentStatus { paye, impaye, partiel, annule }

// ==================== MODÈLE ÉLÉMENT DE FACTURE ====================
class InvoiceItem {
  InvoiceItem({
    this.id,
    required this.invoiceId,
    this.productId,
    required this.productName,
    this.productBarcode,
    required this.quantity,
    required this.unitPrice,
    this.discountAmount = 0,
    required this.totalPrice,
    this.hasPrescription = false,
    this.product,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      productBarcode: map['product_barcode'],
      quantity: map['quantity'],
      unitPrice: (map['unit_price'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
      hasPrescription: map['has_prescription'] == 1,
    );
  }

  final double discountAmount;
  final bool hasPrescription;
  final int? id;
  final int invoiceId;
  // Relations
  Product? product;

  final String? productBarcode;
  final int? productId;
  final String productName;
  final int quantity;
  final double totalPrice;
  final double unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'product_barcode': productBarcode,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount_amount': discountAmount,
      'total_price': totalPrice,
      'has_prescription': hasPrescription ? 1 : 0,
    };
  }

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    String? productBarcode,
    int? quantity,
    double? unitPrice,
    double? discountAmount,
    double? totalPrice,
    bool? hasPrescription,
    Product? product,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBarcode: productBarcode ?? this.productBarcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      hasPrescription: hasPrescription ?? this.hasPrescription,
      product: product ?? this.product,
    );
  }

  double get subtotal => unitPrice * quantity;

  double get discountPercentage =>
      subtotal > 0 ? (discountAmount / subtotal) * 100 : 0;
}

// ==================== MODÈLE PAIEMENT ====================
class Payment {
  Payment({
    this.id,
    required this.invoiceId,
    required this.paymentMethod,
    required this.amount,
    DateTime? paymentDate,
    this.referenceNumber,
    this.notes,
    this.userId,
    this.invoice,
    this.user,
  }) : paymentDate = paymentDate ?? DateTime.now();

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      invoiceId: map['invoice_id'],
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
      ),
      amount: (map['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(map['payment_date']),
      referenceNumber: map['reference_number'],
      notes: map['notes'],
      userId: map['user_id'],
    );
  }

  final double amount;
  final int? id;
  // Relations
  Invoice? invoice;

  final int invoiceId;
  final String? notes;
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  User? user;
  final int? userId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'payment_method': paymentMethod.name,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'reference_number': referenceNumber,
      'notes': notes,
      'user_id': userId,
    };
  }
}

enum PaymentMethod { especes, carte, cheque, virement }

// ==================== MODÈLE PRESCRIPTION ====================
class Prescription {
  Prescription({
    this.id,
    this.invoiceId,
    required this.customerId,
    this.odSphere,
    this.odCylinder,
    this.odAxis,
    this.odAdd,
    this.osSphere,
    this.osCylinder,
    this.osAxis,
    this.osAdd,
    this.pdTotal,
    this.pdRight,
    this.pdLeft,
    this.vertexDistance,
    this.pantoscopicTilt,
    this.wrapAngle,
    this.lensType,
    this.lensMaterial,
    this.coating,
    this.tint,
    this.doctorName,
    this.prescriptionDate,
    this.notes,
    DateTime? createdAt,
    this.customer,
    this.invoice,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Prescription.fromMap(Map<String, dynamic> map) {
    return Prescription(
      id: map['id'],
      invoiceId: map['invoice_id'],
      customerId: map['customer_id'],
      odSphere: map['od_sphere'] != null
          ? (map['od_sphere'] as num).toDouble()
          : null,
      odCylinder: map['od_cylinder'] != null
          ? (map['od_cylinder'] as num).toDouble()
          : null,
      odAxis: map['od_axis'],
      odAdd: map['od_add'] != null ? (map['od_add'] as num).toDouble() : null,
      osSphere: map['os_sphere'] != null
          ? (map['os_sphere'] as num).toDouble()
          : null,
      osCylinder: map['os_cylinder'] != null
          ? (map['os_cylinder'] as num).toDouble()
          : null,
      osAxis: map['os_axis'],
      osAdd: map['os_add'] != null ? (map['os_add'] as num).toDouble() : null,
      pdTotal: map['pd_total'] != null
          ? (map['pd_total'] as num).toDouble()
          : null,
      pdRight: map['pd_right'] != null
          ? (map['pd_right'] as num).toDouble()
          : null,
      pdLeft: map['pd_left'] != null
          ? (map['pd_left'] as num).toDouble()
          : null,
      vertexDistance: map['vertex_distance'] != null
          ? (map['vertex_distance'] as num).toDouble()
          : null,
      pantoscopicTilt: map['pantoscopic_tilt'] != null
          ? (map['pantoscopic_tilt'] as num).toDouble()
          : null,
      wrapAngle: map['wrap_angle'] != null
          ? (map['wrap_angle'] as num).toDouble()
          : null,
      lensType: map['lens_type'],
      lensMaterial: map['lens_material'],
      coating: map['coating'],
      tint: map['tint'],
      doctorName: map['doctor_name'],
      prescriptionDate: map['prescription_date'] != null
          ? DateTime.parse(map['prescription_date'])
          : null,
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  final String? coating;
  final DateTime createdAt;
  // Relations
  Customer? customer;

  final int customerId;
  // Notes du praticien
  final String? doctorName;

  final int? id;
  Invoice? invoice;
  final int? invoiceId;
  final String? lensMaterial;
  // Type de verre
  final String? lensType;

  final String? notes;
  final double? odAdd;
  final int? odAxis;
  final double? odCylinder;
  // Œil Droit (OD)
  final double? odSphere;

  final double? osAdd;
  final int? osAxis;
  final double? osCylinder;
  // Œil Gauche (OS)
  final double? osSphere;

  final double? pantoscopicTilt;
  final double? pdLeft;
  final double? pdRight;
  // Distances pupillaires
  final double? pdTotal;

  final DateTime? prescriptionDate;
  final String? tint;
  // Autres mesures
  final double? vertexDistance;

  final double? wrapAngle;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'customer_id': customerId,
      'od_sphere': odSphere,
      'od_cylinder': odCylinder,
      'od_axis': odAxis,
      'od_add': odAdd,
      'os_sphere': osSphere,
      'os_cylinder': osCylinder,
      'os_axis': osAxis,
      'os_add': osAdd,
      'pd_total': pdTotal,
      'pd_right': pdRight,
      'pd_left': pdLeft,
      'vertex_distance': vertexDistance,
      'pantoscopic_tilt': pantoscopicTilt,
      'wrap_angle': wrapAngle,
      'lens_type': lensType,
      'lens_material': lensMaterial,
      'coating': coating,
      'tint': tint,
      'doctor_name': doctorName,
      'prescription_date': prescriptionDate?.toIso8601String().split('T')[0],
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Prescription copyWith({
    int? id,
    int? invoiceId,
    int? customerId,
    double? odSphere,
    double? odCylinder,
    int? odAxis,
    double? odAdd,
    double? osSphere,
    double? osCylinder,
    int? osAxis,
    double? osAdd,
    double? pdTotal,
    double? pdRight,
    double? pdLeft,
    double? vertexDistance,
    double? pantoscopicTilt,
    double? wrapAngle,
    String? lensType,
    String? lensMaterial,
    String? coating,
    String? tint,
    String? doctorName,
    DateTime? prescriptionDate,
    String? notes,
    DateTime? createdAt,
    Customer? customer,
    Invoice? invoice,
  }) {
    return Prescription(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      customerId: customerId ?? this.customerId,
      odSphere: odSphere ?? this.odSphere,
      odCylinder: odCylinder ?? this.odCylinder,
      odAxis: odAxis ?? this.odAxis,
      odAdd: odAdd ?? this.odAdd,
      osSphere: osSphere ?? this.osSphere,
      osCylinder: osCylinder ?? this.osCylinder,
      osAxis: osAxis ?? this.osAxis,
      osAdd: osAdd ?? this.osAdd,
      pdTotal: pdTotal ?? this.pdTotal,
      pdRight: pdRight ?? this.pdRight,
      pdLeft: pdLeft ?? this.pdLeft,
      vertexDistance: vertexDistance ?? this.vertexDistance,
      pantoscopicTilt: pantoscopicTilt ?? this.pantoscopicTilt,
      wrapAngle: wrapAngle ?? this.wrapAngle,
      lensType: lensType ?? this.lensType,
      lensMaterial: lensMaterial ?? this.lensMaterial,
      coating: coating ?? this.coating,
      tint: tint ?? this.tint,
      doctorName: doctorName ?? this.doctorName,
      prescriptionDate: prescriptionDate ?? this.prescriptionDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      invoice: invoice ?? this.invoice,
    );
  }

  bool get hasRightEyePrescription => odSphere != null || odCylinder != null;

  bool get hasLeftEyePrescription => osSphere != null || osCylinder != null;

  bool get isProgressive => odAdd != null || osAdd != null;
}

// ==================== MODÈLE PARAMÈTRES IMPRIMANTE ====================
class PrinterSettings {
  PrinterSettings({
    this.id,
    required this.printerName,
    required this.printerType,
    this.connectionString,
    this.paperWidth = 80,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PrinterSettings.fromMap(Map<String, dynamic> map) {
    return PrinterSettings(
      id: map['id'],
      printerName: map['printer_name'],
      printerType: PrinterType.values.firstWhere(
        (e) => e.name == map['printer_type'],
      ),
      connectionString: map['connection_string'],
      paperWidth: map['paper_width'] ?? 80,
      isDefault: map['is_default'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  final String? connectionString;
  final DateTime createdAt;
  final int? id;
  final bool isDefault;
  final int paperWidth;
  final String printerName;
  final PrinterType printerType;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'printer_name': printerName,
      'printer_type': printerType.name,
      'connection_string': connectionString,
      'paper_width': paperWidth,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum PrinterType { bluetooth, wifi, usb }

// ==================== MODÈLE TEMPLATE D'IMPRESSION ====================
class PrintTemplate {
  PrintTemplate({
    this.id,
    required this.templateName,
    required this.templateType,
    this.headerText,
    this.footerText,
    this.logoPath,
    this.isDefault = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PrintTemplate.fromMap(Map<String, dynamic> map) {
    return PrintTemplate(
      id: map['id'],
      templateName: map['template_name'],
      templateType: TemplateType.values.firstWhere(
        (e) => e.name == map['template_type'],
      ),
      headerText: map['header_text'],
      footerText: map['footer_text'],
      logoPath: map['logo_path'],
      isDefault: map['is_default'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  final DateTime createdAt;
  final String? footerText;
  final String? headerText;
  final int? id;
  final bool isDefault;
  final String? logoPath;
  final String templateName;
  final TemplateType templateType;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'template_name': templateName,
      'template_type': templateType.name,
      'header_text': headerText,
      'footer_text': footerText,
      'logo_path': logoPath,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum TemplateType { facture, devis, etiquette, prescription }

// ==================== MODÈLES DE DONNÉES POUR RAPPORTS ====================
class SalesReportData {
  SalesReportData({
    required this.date,
    required this.totalSales,
    required this.totalTransactions,
    required this.averageTransaction,
  });

  final double averageTransaction;
  final DateTime date;
  final double totalSales;
  final int totalTransactions;
}

class ProductSalesData {
  ProductSalesData({
    required this.product,
    required this.quantitySold,
    required this.totalRevenue,
    required this.totalProfit,
  });

  final Product product;
  final int quantitySold;
  final double totalProfit;
  final double totalRevenue;
}

class StockAlertData {
  StockAlertData({
    required this.product,
    required this.currentStock,
    required this.minStock,
    required this.isOutOfStock,
  });

  final int currentStock;
  final bool isOutOfStock;
  final int minStock;
  final Product product;

  bool get needsReorder => currentStock <= minStock;
}

// ==================== MODÈLE CART POUR VENTE ====================
class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    double? unitPrice,
    this.discountAmount = 0,
    this.hasPrescription = false,
  }) : unitPrice = unitPrice ?? product.sellPrice;

  double discountAmount;
  bool hasPrescription;
  final Product product;
  int quantity;
  double unitPrice;

  double get subtotal => unitPrice * quantity;

  double get total => subtotal - discountAmount;

  double get discountPercentage =>
      subtotal > 0 ? (discountAmount / subtotal) * 100 : 0;

  CartItem copyWith({
    Product? product,
    int? quantity,
    double? unitPrice,
    double? discountAmount,
    bool? hasPrescription,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountAmount: discountAmount ?? this.discountAmount,
      hasPrescription: hasPrescription ?? this.hasPrescription,
    );
  }
}

class Cart extends ChangeNotifier {
  Customer? _customer;
  double _globalDiscountAmount = 0;
  final List<CartItem> _items = [];
  String? _notes;
  PaymentType _paymentType = PaymentType.comptant;

  List<CartItem> get items => List.unmodifiable(_items);

  Customer? get customer => _customer;

  double get globalDiscountAmount => _globalDiscountAmount;

  PaymentType get paymentType => _paymentType;

  String? get notes => _notes;

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  double get totalDiscountAmount =>
      _globalDiscountAmount +
      _items.fold(0, (sum, item) => sum + item.discountAmount);

  double get taxAmount => (subtotal - totalDiscountAmount) * 0.19; // 19% TVA

  double get total => subtotal - totalDiscountAmount + taxAmount;

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  void addItem(Product product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void updateItemDiscount(int productId, double discountAmount) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      _items[index].discountAmount = discountAmount;
      notifyListeners();
    }
  }

  void setCustomer(Customer? customer) {
    _customer = customer;
    notifyListeners();
  }

  void setGlobalDiscount(double amount) {
    _globalDiscountAmount = amount;
    notifyListeners();
  }

  void setPaymentType(PaymentType type) {
    _paymentType = type;
    notifyListeners();
  }

  void setNotes(String? notes) {
    _notes = notes;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _customer = null;
    _globalDiscountAmount = 0;
    _paymentType = PaymentType.comptant;
    _notes = null;
    notifyListeners();
  }
}
  
