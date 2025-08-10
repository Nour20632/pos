// models/optical_models.dart

import 'package:flutter/material.dart';

class OpticalOrder {
  int? id;
  String orderNumber;
  int customerId;
  int? prescriptionId;
  int? invoiceId;
  
  // Informations de base
  String? frameReference; // Référence du cadre
  String? lensType; // Type de verres
  String? specialNotes;
  
  // Prix
  double estimatedPrice;
  double finalPrice;
  double costPrice;
  
  // Statut
  String status; // nouveau, en_cours, pret, livre, annule
  
  // Dates
  DateTime orderDate;
  DateTime? estimatedDelivery;
  DateTime? completionDate;
  DateTime? deliveryDate;
  
  // Utilisateurs
  int? createdBy;
  int? technicianId;
  
  // Données de jointure (non persistées)
  String? customerName;
  String? customerPhone;
  String? technicianName;
  String? createdByName;
  String? invoiceNumber;
  
  // Prescription data (si chargée)
  double? odSphere;
  double? odCylinder;
  int? odAxis;
  double? odAdd;
  double? osSphere;
  double? osCylinder;
  int? osAxis;
  double? osAdd;
  double? pdTotal;
  double? pdRight;
  double? pdLeft;

  OpticalOrder({
    this.id,
    required this.orderNumber,
    required this.customerId,
    this.prescriptionId,
    this.invoiceId,
    this.frameReference,
    this.lensType,
    this.specialNotes,
    this.estimatedPrice = 0.0,
    this.finalPrice = 0.0,
    this.costPrice = 0.0,
    this.status = 'nouveau',
    required this.orderDate,
    this.estimatedDelivery,
    this.completionDate,
    this.deliveryDate,
    this.createdBy,
    this.technicianId,
    // Jointure data
    this.customerName,
    this.customerPhone,
    this.technicianName,
    this.createdByName,
    this.invoiceNumber,
    // Prescription data
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'prescription_id': prescriptionId,
      'invoice_id': invoiceId,
      'frame_reference': frameReference,
      'lens_type': lensType,
      'special_notes': specialNotes,
      'estimated_price': estimatedPrice,
      'final_price': finalPrice,
      'cost_price': costPrice,
      'status': status,
      'order_date': orderDate.toIso8601String(),
      'estimated_delivery': estimatedDelivery?.toIso8601String(),
      'completion_date': completionDate?.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
      'created_by': createdBy,
      'technician_id': technicianId,
    };
  }

  factory OpticalOrder.fromMap(Map<String, dynamic> map) {
    return OpticalOrder(
      id: map['id'],
      orderNumber: map['order_number'] ?? '',
      customerId: map['customer_id'] ?? 0,
      prescriptionId: map['prescription_id'],
      invoiceId: map['invoice_id'],
      frameReference: map['frame_reference'],
      lensType: map['lens_type'],
      specialNotes: map['special_notes'],
      estimatedPrice: (map['estimated_price'] ?? 0.0).toDouble(),
      finalPrice: (map['final_price'] ?? 0.0).toDouble(),
      costPrice: (map['cost_price'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'nouveau',
      orderDate: DateTime.parse(map['order_date'] ?? DateTime.now().toIso8601String()),
      estimatedDelivery: map['estimated_delivery'] != null 
          ? DateTime.parse(map['estimated_delivery']) 
          : null,
      completionDate: map['completion_date'] != null 
          ? DateTime.parse(map['completion_date']) 
          : null,
      deliveryDate: map['delivery_date'] != null 
          ? DateTime.parse(map['delivery_date']) 
          : null,
      createdBy: map['created_by'],
      technicianId: map['technician_id'],
      // Jointure data
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      technicianName: map['technician_name'],
      createdByName: map['created_by_name'],
      invoiceNumber: map['invoice_number'],
      // Prescription data
      odSphere: map['od_sphere']?.toDouble(),
      odCylinder: map['od_cylinder']?.toDouble(),
      odAxis: map['od_axis'],
      odAdd: map['od_add']?.toDouble(),
      osSphere: map['os_sphere']?.toDouble(),
      osCylinder: map['os_cylinder']?.toDouble(),
      osAxis: map['os_axis'],
      osAdd: map['os_add']?.toDouble(),
      pdTotal: map['pd_total']?.toDouble(),
      pdRight: map['pd_right']?.toDouble(),
      pdLeft: map['pd_left']?.toDouble(),
    );
  }

  // Méthodes utilitaires
  String get statusDisplayName {
    switch (status) {
      case 'nouveau':
        return 'Nouveau';
      case 'en_cours':
        return 'En cours';
      case 'pret':
        return 'Prêt';
      case 'livre':
        return 'Livré';
      case 'annule':
        return 'Annulé';
      default:
        return status;
    }
  }
  
  Color get statusColor {
    switch (status) {
      case 'nouveau':
        return Colors.blue;
      case 'en_cours':
        return Colors.orange;
      case 'pret':
        return Colors.green;
      case 'livre':
        return Colors.grey;
      case 'annule':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  bool get isCompleted => status == 'livre';
  bool get isReady => status == 'pret';
  bool get isInProgress => status == 'en_cours';
  bool get isNew => status == 'nouveau';
  bool get isCancelled => status == 'annule';
  
  bool get isOverdue {
    if (estimatedDelivery == null || isCompleted || isCancelled) return false;
    return DateTime.now().isAfter(estimatedDelivery!);
  }
}

class LensType {
  int? id;
  String name;
  String? description;
  double basePrice;
  bool isActive;
  DateTime createdAt;

  LensType({
    this.id,
    required this.name,
    this.description,
    this.basePrice = 0.0,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'base_price': basePrice,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LensType.fromMap(Map<String, dynamic> map) {
    return LensType(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      basePrice: (map['base_price'] ?? 0.0).toDouble(),
      isActive: (map['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// Énumérations pour les statuts
enum OpticalOrderStatus {
  nouveau('nouveau', 'Nouveau'),
  enCours('en_cours', 'En cours'),
  pret('pret', 'Prêt'),
  livre('livre', 'Livré'),
  annule('annule', 'Annulé');

  const OpticalOrderStatus(this.value, this.displayName);
  final String value;
  final String displayName;
}