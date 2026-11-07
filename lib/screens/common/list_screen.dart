import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../services/record_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pp_widgets.dart';
import 'detail_screen.dart';
import 'session.dart';

/// Generic list for any module (PhonePe "transaction history" style).
class ListScreen extends StatefulWidget {
  final ErpModule module;
  const ListScreen({super.key, required this.module});
  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String? _status;
  final _searchCtrl = TextEditingController();

  ErpModule get m => widget.module;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _error = null; if (_all.isEmpty) _loading = true; });
    try {
      final data = await ApiService.instance.get(m.endpoint!, params: m.params, projectScoped: m.projectScoped);
      if (mounted) setState(() { _all = RecordUtils.extractList(data); _loading = false; });
    } on ApiException catch (e) {
      if (e.code == 401 && mounted) return handleSessionExpired(context);
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<String> get _statuses {
    final s = <String>{};
    for (final r in _all) {
      final k = RecordUtils.statusKey(r);
      if (k != null) s.add('${r[k]}');
    }
    return s.toList()..sort();
  }

  List<Map<String, dynamic>> get _filtered => _all.where((r) {
        if (_status != null) {
          final k = RecordUtils.statusKey(r);
          if (k == null || '${r[k]}' != _status) return false;
        }
        if (_q.isEmpty) return true;
        return r.values.any((v) => v is! Map && v is! List && '$v'.toLowerCase().contains(_q));
      }).toList();

  @override
  Widget build(BuildContext context) {
    final project = ApiService.instance.currentProject;
    final items = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(
        title: m.title,
        subtitle: m.projectScoped && project != null ? '${project['projectCode']} • ${project['projectName'] ?? ''}' : null,
        actions: [
          if (!_loading && _error == null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
              child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      floatingActionButton: m.canEdit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Create form coming soon'))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New'),
            )
          : null,
      body: Column(
        children: [
          _searchBar(),
          if (_statuses.length > 1) _statusChips(),
          Expanded(child: _body(items)),
        ],
      ),
    );
  }

  Widget _searchBar() => Container(
        color: AppColors.bg,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search in ${m.title}',
            filled: true,
            fillColor: AppColors.bgCard,
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            suffixIcon: _q.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                    onPressed: () => setState(() { _searchCtrl.clear(); _q = ''; }))
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.2)),
          ),
        ),
      );

  Widget _statusChips() {
    final chips = [null, ..._statuses];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = chips[i];
          final sel = s == _status;
          return ChoiceChip(
            label: Text(s ?? 'All'),
            selected: sel,
            showCheckmark: false,
            onSelected: (_) => setState(() => _status = s),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.bgCard,
            side: BorderSide(color: sel ? AppColors.accent : AppColors.glassBorder),
            labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _body(List<Map<String, dynamic>> items) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 8,
        itemBuilder: (_, __) => const Padding(padding: EdgeInsets.only(bottom: 8), child: ShimmerLoader(height: 74, radius: 14)),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load ${m.title}',
        message: _error,
        action: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: items.isEmpty
          ? ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
              EmptyState(
                icon: Icons.inbox_rounded,
                title: _all.isEmpty ? 'No records yet' : 'No matches',
                message: _all.isEmpty ? 'Nothing to show for this project.' : 'Try a different search.',
              ),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
              itemCount: items.length,
              itemBuilder: (_, i) => RecordTile(
                record: items[i],
                module: m,
                color: colorFor(i),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DetailScreen(module: m, record: items[i]),
                )),
              ),
            ),
    );
  }
}

class RecordTile extends StatelessWidget {
  final Map<String, dynamic> record;
  final ErpModule module;
  final Color color;
  final VoidCallback onTap;
  const RecordTile({super.key, required this.record, required this.module, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tk = RecordUtils.titleKey(record, module.titleKey);
    final sk = RecordUtils.subtitleKey(record, tk, module.subtitleKey);
    final stk = RecordUtils.statusKey(record);
    final ak = RecordUtils.amountKey(record);
    final dk = RecordUtils.dateKey(record);
    final title = tk == null ? module.title : RecordUtils.text(record, tk);
    final initial = title.isNotEmpty ? title[0].toUpperCase() : '#';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.sectionCard(radius: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(initial, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600)),
                      if (sk != null) ...[
                        const SizedBox(height: 2),
                        Text(RecordUtils.text(record, sk), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                      ],
                      if (dk != null) ...[
                        const SizedBox(height: 4),
                        Text(RecordUtils.text(record, dk),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (ak != null)
                      Text(RecordUtils.money(record[ak]),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    if (stk != null) ...[
                      if (ak != null) const SizedBox(height: 6),
                      StatusBadge('${record[stk]}'),
                    ],
                    if (ak == null && stk == null) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
