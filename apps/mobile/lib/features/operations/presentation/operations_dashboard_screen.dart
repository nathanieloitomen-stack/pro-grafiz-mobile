import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/operations_repository.dart';

/// Basic management dashboard — Master Spec §6 V1 bullet, no further
/// detail or approved pixel design given anywhere. Minimal, functional
/// counts only: pending requests, jobs per stage, held/cancelled totals
/// — all derived from the same RLS-scoped queries Intake/Job Queue
/// already use, just summarized. Not pixel-matched to anything, since
/// nothing to match exists.
///
/// UNTESTED against a live backend.
class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({super.key, required this.repository});

  final OperationsRepository repository;

  @override
  State<OperationsDashboardScreen> createState() => _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  Map<String, int>? _counts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final counts = await widget.repository.fetchDashboardCounts();
      if (!mounted) return;
      setState(() => _counts = counts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load dashboard data.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
        backgroundColor: PGColors.paper,
        elevation: 0,
        title: Text('Dashboard', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _counts == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
                    children: _counts!.entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: PGCard(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key.replaceAll('_', ' '), style: PGTextStyles.body.copyWith(color: PGColors.ink)),
                                  Text('${entry.value}', style: PGTextStyles.numeric.copyWith(color: PGColors.ember)),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
      ),
    );
  }
}
