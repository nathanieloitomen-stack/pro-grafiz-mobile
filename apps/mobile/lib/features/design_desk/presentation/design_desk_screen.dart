import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/design_desk_repository.dart';
import 'draft_review_screen.dart';

/// Design Desk — approved screens #15/16 area. Lists jobs needing
/// design attention (PAYMENT_CONFIRMED, not yet started, or
/// DESIGN_IN_PROGRESS). Visibility follows `jobs_select_own_or_staff`
/// (PG-005) exactly — this screen makes no access decisions of its own.
///
/// UNTESTED against a live backend.
class DesignDeskScreen extends StatefulWidget {
  const DesignDeskScreen({super.key, required this.repository});

  final DesignDeskRepository repository;

  @override
  State<DesignDeskScreen> createState() => _DesignDeskScreenState();
}

class _DesignDeskScreenState extends State<DesignDeskScreen> {
  List<DesignJob>? _jobs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await widget.repository.fetchJobsNeedingDesign();
      if (!mounted) return;
      setState(() => _jobs = jobs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load jobs. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
        backgroundColor: PGColors.paper,
        elevation: 0,
        title: Text('Design Desk', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _jobs == null
                ? const Center(child: CircularProgressIndicator())
                : _jobs!.isEmpty
                    ? Center(child: Text('No jobs need design work right now.', style: PGTextStyles.body.copyWith(color: PGColors.textSoft)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
                        itemCount: _jobs!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final job = _jobs![index];
                          return PGPressable(
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DraftReviewScreen(job: job, repository: widget.repository),
                                ),
                              );
                              _load();
                            },
                            child: PGCard(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(job.jobRef, style: PGTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: PGColors.ink)),
                                  PGTag(
                                    label: job.currentStage.replaceAll('_', ' '),
                                    tone: job.currentStage == 'PAYMENT_CONFIRMED' ? PGTagTone.warning : PGTagTone.auto,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
