import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/module.dart';
import '../../widgets/glass_card.dart';
import 'detail_screen.dart';

class ListScreen extends StatefulWidget {
  final ErpModule module;
  const ListScreen({super.key, required this.module});
  @override State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final data = await ApiService.instance.get(widget.module.endpoint, params: widget.module.params);
      final list = data is List ? data : (data is Map ? (data['data'] ?? [data]) : []);
      if (mounted) setState(() { _all = list; _filtered = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) { setState(() => _filtered = _all); return; }
    setState(() {
      _filtered = _all.where((item) {
        if (item is! Map) return false;
        return item.values.any((v) => v.toString().toLowerCase().contains(q));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSearch(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(child: Text(widget.module.title, style: Theme.of(context).textTheme.headlineSmall)),
        if (!_loading && _all.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: Text('${_filtered.length}', style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
      ],
    ),
  );

  Widget _buildSearch() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search ${widget.module.title.toLowerCase()}...',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted, size: 18), onPressed: () { _searchCtrl.clear(); })
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return const Center(child: Text('No records found', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _RecordCard(
          record: _filtered[i],
          module: widget.module,
          index: i,
          onTap: widget.module.detailEndpoint != null ? () {
            final id = _filtered[i][widget.module.idKey ?? 'id'];
            if (id != null) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => DetailScreen(
                  title: widget.module.title,
                  endpoint: '${widget.module.detailEndpoint}/$id',
                  record: _filtered[i],
                ),
              ));
            }
          } : null,
        ),
      ),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    itemCount: 8,
    itemBuilder: (_, i) => const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: ShimmerLoader(height: 72, radius: 16),
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
          ),
        ],
      ),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final ErpModule module;
  final int index;
  final VoidCallback? onTap;

  const _RecordCard({required this.record, required this.module, required this.index, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cols = module.columns;
    final titleCol = cols.firstWhere((c) => c.isTitle, orElse: () => cols.first);
    final subtitleCol = cols.cast<ColumnDef?>().firstWhere((c) => c!.isSubtitle, orElse: () => null);
    final badgeCols = cols.where((c) => c.isBadge).toList();
    final otherCols = cols.where((c) => !c.isTitle && !c.isSubtitle && !c.isBadge).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.moduleColors[index % AppColors.moduleColors.length].withOpacity(0.15),
              ),
              child: Center(child: Icon(module.icon, size: 18, color: AppColors.moduleColors[index % AppColors.moduleColors.length])),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(
                        '${record[titleCol.key] ?? '—'}',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      )),
                      ...badgeCols.map((c) {
                        final v = '${record[c.key] ?? ''}';
                        if (v.isEmpty) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(left: 8), child: StatusBadge(v));
                      }),
                    ],
                  ),
                  if (subtitleCol != null && record[subtitleCol.key] != null) ...[
                    const SizedBox(height: 2),
                    Text('${record[subtitleCol.key]}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                  if (otherCols.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12, runSpacing: 4,
                      children: otherCols.where((c) => record[c.key] != null).map((c) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${c.label}: ', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text('${record[c.key]}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
