import 'package:flutter/foundation.dart';

import '../database.dart';
import '../models.dart' as models;

/// Service de gestion des factures et paiements
class InvoiceService extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  List<models.Invoice> _invoices = [];
  bool _isLoading = false;
  models.InvoiceType? _selectedType;
  models.PaymentStatus? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  InvoiceService(this._databaseHelper) {
    loadInvoices();
  }

  // Getters
  List<models.Invoice> get invoices => _filteredInvoices();
  List<models.Invoice> get allInvoices => _invoices;
  bool get isLoading => _isLoading;
  models.InvoiceType? get selectedType => _selectedType;
  models.PaymentStatus? get selectedStatus => _selectedStatus;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  List<models.Invoice> _filteredInvoices() {
    List<models.Invoice> filtered = List.from(_invoices);

    // Filtrer par type
    if (_selectedType != null) {
      filtered = filtered.where((i) => i.invoiceType == _selectedType).toList();
    }

    // Filtrer par statut de paiement
    if (_selectedStatus != null) {
      filtered = filtered
          .where((i) => i.paymentStatus == _selectedStatus)
          .toList();
    }

    // Filtrer par période
    if (_startDate != null) {
      filtered = filtered
          .where((i) => i.createdAt.isAfter(_startDate!))
          .toList();
    }
    if (_endDate != null) {
      filtered = filtered
          .where(
            (i) => i.createdAt.isBefore(_endDate!.add(const Duration(days: 1))),
          )
          .toList();
    }

    return filtered..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> loadInvoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _invoices = await _databaseHelper.getAllInvoices(limit: 500);
      debugPrint('${_invoices.length} factures chargées');
    } catch (e) {
      debugPrint('Erreur chargement factures: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void setFilters({
    models.InvoiceType? type,
    models.PaymentStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _selectedType = type;
    _selectedStatus = status;
    _startDate = startDate;
    _endDate = endDate;
    notifyListeners();
  }

  void clearFilters() {
    _selectedType = null;
    _selectedStatus = null;
    _startDate = null;
    _endDate = null;
    notifyListeners();
  }

  Future<String> generateInvoiceNumber() async {
    return await _databaseHelper.generateInvoiceNumber();
  }

  Future<bool> createInvoice(
    models.Cart cart,
    int userId, {
    models.Customer? customer,
  }) async {
    if (cart.isEmpty) return false;

    try {
      final invoiceNumber = await generateInvoiceNumber();

      final invoice = models.Invoice(
        invoiceNumber: invoiceNumber,
        customerId: cart.customer?.id,
        customerName: cart.customer?.name,
        customerPhone: cart.customer?.phone,
        invoiceType: models.InvoiceType.vente,
        paymentType: cart.paymentType,
        subtotal: cart.subtotal,
        discountAmount: cart.totalDiscountAmount,
        taxAmount: cart.taxAmount,
        totalAmount: cart.total,
        paidAmount: cart.paymentType == models.PaymentType.comptant
            ? cart.total
            : 0,
        remainingAmount: cart.paymentType == models.PaymentType.comptant
            ? 0
            : cart.total,
        paymentStatus: cart.paymentType == models.PaymentType.comptant
            ? models.PaymentStatus.paye
            : models.PaymentStatus.impaye,
        notes: cart.notes,
        userId: userId,
      );

      final items = cart.items
          .map(
            (cartItem) => models.InvoiceItem(
              invoiceId: 0, // Sera défini par la base de données
              productId: cartItem.product.id,
              productName: cartItem.product.name,
              productBarcode: cartItem.product.barcode,
              quantity: cartItem.quantity,
              unitPrice: cartItem.unitPrice,
              discountAmount: cartItem.discountAmount,
              totalPrice: cartItem.total,
              hasPrescription: cartItem.hasPrescription,
            ),
          )
          .toList();

      await _databaseHelper.insertInvoice(invoice, items);
      await loadInvoices();
      debugPrint('Facture créée: ${invoice.invoiceNumber}');
      return true;
    } catch (e) {
      debugPrint('Erreur création facture: $e');
      return false;
    }
  }

  Future<models.Invoice?> getInvoiceByNumber(String invoiceNumber) async {
    try {
      return _invoices
          .where((i) => i.invoiceNumber == invoiceNumber)
          .firstOrNull;
    } catch (e) {
      debugPrint('Erreur recherche facture par numéro: $e');
      return null;
    }
  }

  Future<models.Invoice?> getInvoiceById(int id) async {
    return await _databaseHelper.getInvoiceById(id);
  }

  Future<bool> addPayment(int invoiceId, models.Payment payment) async {
    try {
      await _databaseHelper.insertPayment(payment);

      // Mettre à jour le statut de paiement
      final invoice = await _databaseHelper.getInvoiceById(invoiceId);
      if (invoice != null) {
        final payments = await _databaseHelper.getInvoicePayments(invoiceId);
        final totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);

        models.PaymentStatus newStatus;
        if (totalPaid >= invoice.totalAmount) {
          newStatus = models.PaymentStatus.paye;
        } else if (totalPaid > 0) {
          newStatus = models.PaymentStatus.partiel;
        } else {
          newStatus = models.PaymentStatus.impaye;
        }

        await _databaseHelper.updateInvoicePaymentStatus(
          invoiceId,
          newStatus,
          totalPaid,
        );
      }

      await loadInvoices();
      debugPrint('Paiement ajouté pour facture ID: $invoiceId');
      return true;
    } catch (e) {
      debugPrint('Erreur ajout paiement: $e');
      return false;
    }
  }

  Future<List<models.Payment>> getInvoicePayments(int invoiceId) async {
    return await _databaseHelper.getInvoicePayments(invoiceId);
  }

  List<models.Invoice> getUnpaidInvoices() {
    return _invoices
        .where(
          (invoice) =>
              invoice.paymentStatus == models.PaymentStatus.impaye ||
              invoice.paymentStatus == models.PaymentStatus.partiel,
        )
        .toList();
  }

  List<models.Invoice> getTodayInvoices() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _invoices
        .where(
          (invoice) =>
              invoice.createdAt.isAfter(startOfDay) &&
              invoice.createdAt.isBefore(endOfDay),
        )
        .toList();
  }

  List<models.Invoice> getThisMonthInvoices() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    return _invoices
        .where(
          (invoice) =>
              invoice.createdAt.isAfter(startOfMonth) &&
              invoice.createdAt.isBefore(endOfMonth),
        )
        .toList();
  }

  double getTotalUnpaidAmount() {
    return getUnpaidInvoices().fold(
      0,
      (sum, invoice) => sum + invoice.remainingAmount,
    );
  }

  double getTodayTotalSales() {
    return getTodayInvoices().fold(
      0,
      (sum, invoice) => invoice.paymentStatus != models.PaymentStatus.annule
          ? sum + invoice.totalAmount
          : sum,
    );
  }

  double getThisMonthTotalSales() {
    return getThisMonthInvoices().fold(
      0,
      (sum, invoice) => invoice.paymentStatus != models.PaymentStatus.annule
          ? sum + invoice.totalAmount
          : sum,
    );
  }

  Map<String, dynamic> getInvoiceStats() {
    final totalInvoices = _invoices.length;
    final paidInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.paye)
        .length;
    final unpaidInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.impaye)
        .length;
    final partialInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.partiel)
        .length;
    final cancelledInvoices = _invoices
        .where((i) => i.paymentStatus == models.PaymentStatus.annule)
        .length;

    final totalSales = _invoices.fold(
      0.0,
      (sum, i) => i.paymentStatus != models.PaymentStatus.annule
          ? sum + i.totalAmount
          : sum,
    );
    final totalPaid = _invoices.fold(0.0, (sum, i) => sum + i.paidAmount);
    final totalUnpaid = getTotalUnpaidAmount();

    return {
      'totalInvoices': totalInvoices,
      'paidInvoices': paidInvoices,
      'unpaidInvoices': unpaidInvoices,
      'partialInvoices': partialInvoices,
      'cancelledInvoices': cancelledInvoices,
      'totalSales': totalSales,
      'totalPaid': totalPaid,
      'totalUnpaid': totalUnpaid,
      'todaySales': getTodayTotalSales(),
      'monthSales': getThisMonthTotalSales(),
    };
  }
}
