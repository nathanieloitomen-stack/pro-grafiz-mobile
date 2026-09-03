import 'package:flutter/material.dart';

/// Pro_Grafiz mobile entry point.
///
/// Scaffolding only (PG-001): this file intentionally contains no
/// screens, design tokens, navigation, or business logic. The customer
/// and staff surfaces described in the approved design handoff are
/// built starting with PG-002 (Design System).
void main() {
  runApp(const ProGrafizApp());
}

class ProGrafizApp extends StatelessWidget {
  const ProGrafizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Pro_Grafiz',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text('Pro_Grafiz — foundation build (PG-001)'),
        ),
      ),
    );
  }
}
