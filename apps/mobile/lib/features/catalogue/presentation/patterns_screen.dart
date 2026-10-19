import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/design_system/design_system.dart';
import '../../auth/data/auth_repository.dart';
import '../data/catalogue_repository.dart';
import '../data/models/pattern_category.dart';
import '../data/models/pattern_summary.dart';
import 'pattern_detail_screen.dart';

/// Approved design screen #2, "Patterns": pill search, horizontal
/// category chips, result count, 2-column grid with a favourite-heart
/// overlay, and a "Load more" pagination action.
///
/// Deliberately not built here (deferred, see docs/catalogue.md):
/// the "Merge" toggle into the Blend flow (screen #5) and the
/// scan-a-sketch entry point (Camera scan, screen #4) — neither is
/// named in Master Spec §6's V1 bullet list for this task, unlike
/// "search and favourites", which is.
///
/// UNTESTED against a live backend.
class PatternsScreen extends StatefulWidget {
  const PatternsScreen(
      {super.key,
      required this.catalogueRepository,
      required this.authRepository});

  final CatalogueRepository catalogueRepository;
  final AuthRepository authRepository;

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  static const _pageSize = 24;

  List<PatternCategory> _categories = [];
  String _selectedCategoryCode = 'All';
  String _query = '';
  final _searchController = TextEditingController();

  final List<PatternSummary> _patterns = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final categories = await widget.catalogueRepository.fetchCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
      await _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the catalogue. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _patterns.clear();
      _hasMore = true;
    });
    try {
      final results = await widget.catalogueRepository.searchPatterns(
        query: _query,
        categoryCode: _selectedCategoryCode,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _patterns.addAll(results);
        _hasMore = results.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load patterns. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final results = await widget.catalogueRepository.searchPatterns(
        query: _query,
        categoryCode: _selectedCategoryCode,
        limit: _pageSize,
        offset: _patterns.length,
      );
      if (!mounted) return;
      setState(() {
        _patterns.addAll(results);
        _hasMore = results.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _toggleFavourite(PatternSummary pattern) async {
    final customerId = await _resolveCustomerId();
    if (customerId == null) return; // signed-out or staff — heart is inert
    final index = _patterns.indexWhere((p) => p.id == pattern.id);
    if (index == -1) return;
    final next = !pattern.isFavourited;
    setState(() {
      _patterns[index] = pattern.copyWith(
        isFavourited: next,
        savedCount: pattern.savedCount + (next ? 1 : -1),
      );
    });
    try {
      await widget.catalogueRepository
          .setFavourite(pattern.id, customerId, favourited: next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _patterns[index] = pattern); // revert on failure
    }
  }

  /// The signed-in customer's own `customers.id` — resolved via a
  /// lightweight lookup rather than threaded through every screen.
  /// Returns null for staff or signed-out sessions (favouriting is a
  /// customer-only action; `pattern_favourites`' RLS would reject a
  /// staff attempt anyway, this just avoids the round trip).
  Future<String?> _resolveCustomerId() async {
    if (widget.authRepository.currentSession == null) return null;
    try {
      final row = await Supabase.instance.client
          .from('customers')
          .select('id')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PGSpacing.screenHorizontal,
                PGSpacing.screenTopMax,
                PGSpacing.screenHorizontal,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patterns',
                      style: PGTextStyles.screenTitle
                          .copyWith(color: PGColors.ink)),
                  const SizedBox(height: PGSpacing.groupGap),
                  TextField(
                    controller: _searchController,
                    style: PGTextStyles.input,
                    decoration: const InputDecoration(
                        hintText: 'Search by name, PGLC code, or category'),
                    onSubmitted: (value) {
                      _query = value;
                      _reload();
                    },
                  ),
                  const SizedBox(height: PGSpacing.groupGap),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        PGPill(
                          label: 'All',
                          selected: _selectedCategoryCode == 'All',
                          onTap: () {
                            setState(() => _selectedCategoryCode = 'All');
                            _reload();
                          },
                        ),
                        for (final category in _categories) ...[
                          const SizedBox(width: 8),
                          PGPill(
                            label: category.name,
                            selected: _selectedCategoryCode == category.code,
                            onTap: () {
                              setState(
                                  () => _selectedCategoryCode = category.code);
                              _reload();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: PGSpacing.groupGap),
                  if (!_loading && _error == null)
                    Text('${_patterns.length} results',
                        style: PGTextStyles.caption
                            .copyWith(color: PGColors.textSoft)),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)));
    }
    if (_patterns.isEmpty) {
      return Center(
        child: Text('No patterns match your search.',
            style: PGTextStyles.body.copyWith(color: PGColors.textSoft)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _patterns.length + 1,
      itemBuilder: (context, index) {
        if (index == _patterns.length) {
          return _hasMore
              ? Center(
                  child: PGSecondaryButton(
                    label: _loadingMore ? 'Loading…' : 'Load 24 more',
                    onPressed: _loadingMore ? null : _loadMore,
                    expand: false,
                  ),
                )
              : const SizedBox.shrink();
        }
        final pattern = _patterns[index];
        return _PatternTile(
          pattern: pattern,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatternDetailScreen(
                patternId: pattern.id,
                catalogueRepository: widget.catalogueRepository,
                authRepository: widget.authRepository,
              ),
            ),
          ),
          onFavouriteTap: () => _toggleFavourite(pattern),
        );
      },
    );
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile(
      {required this.pattern,
      required this.onTap,
      required this.onFavouriteTap});

  final PatternSummary pattern;
  final VoidCallback onTap;
  final VoidCallback onFavouriteTap;

  @override
  Widget build(BuildContext context) {
    return PGPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PGRadius.thumbnail),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: PGColors.clayDeep,
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pattern.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PGTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700, color: PGColors.ink),
                    ),
                    Text(pattern.categoryName,
                        style: PGTextStyles.caption
                            .copyWith(color: PGColors.textSoft)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: PGPressable(
                onTap: onFavouriteTap,
                pressedScale: 0.9,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(
                    pattern.isFavourited
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 16,
                    color: pattern.isFavourited
                        ? PGColors.ember
                        : PGColors.textFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
