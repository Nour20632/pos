import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/prescription_service.dart';

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PrescriptionService>(
        builder: (context, service, _) {
          // You can fetch and display prescriptions here
          return Center(
            child: Text(
              'Gestion des prescriptions\n(Fonctionnalité à compléter)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/prescriptions/add'),
        backgroundColor: Colors.teal,
        tooltip: 'Ajouter une prescription',
        child: const Icon(Icons.add),
      ),
    );
  }
}
