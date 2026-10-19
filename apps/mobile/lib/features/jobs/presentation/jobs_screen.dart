import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/job_repository.dart';
import '../data/models/job_summary.dart';
import 'job_detail_screen.dart';

/// Customer-facing job list — approved screen #7, "Jobs" (list portion;
/// the detail/timeline/approval-card portion is [JobDetailScreen]).
///
/// UNTESTED against a live backend. Will legitimately show an empty
/// list until a staff member accepts a quote request — see
/// docs/customer-job-flow.md for why job creation isn't triggered from
/// this task's own UI.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, required this.jobRepository});

  final JobRepository jobRepository;

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<JobSummary>? _jobs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await widget.jobRepository.fetchMyJobs();
      if (!mounted) return;
      setState(() => _jobs = jobs);
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _error = 'Could not load your jobs. Check your connection.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
        backgroundColor: PGColors.paper,
        elevation: 0,
        title: Text('Jobs',
            style: PGTextStyles.cardTitle
                .copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Text(_error!,
                    style:
                        PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _jobs == null
                ? const Center(child: CircularProgressIndicator())
                : _jobs!.isEmpty
                    ? Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(PGSpacing.screenHorizontal),
                          child: Text(
                            'No jobs yet. Once a request you\'ve sent is reviewed and '
                            'accepted, it will appear here.',
                            textAlign: TextAlign.center,
                            style: PGTextStyles.body
                                .copyWith(color: PGColors.textSoft),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.all(PGSpacing.screenHorizontal),
                        itemCount: _jobs!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final job = _jobs![index];
                          return PGPressable(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(
                                    jobId: job.id,
                                    jobRepository: widget.jobRepository),
                              ),
                            ),
                            child: PGCard(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(job.jobRef,
                                          style: PGTextStyles.body.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: PGColors.ink)),
                                      const SizedBox(height: 4),
                                      Text(
                                        job.currentStage.replaceAll('_', ' '),
                                        style: PGTextStyles.caption
                                            .copyWith(color: PGColors.textSoft),
                                      ),
                                    ],
                                  ),
                                  if (job.status != 'active')
                                    PGTag(
                                      label: job.status.replaceAll('_', ' '),
                                      tone: job.status == 'cancelled'
                                          ? PGTagTone.danger
                                          : PGTagTone.warning,
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
