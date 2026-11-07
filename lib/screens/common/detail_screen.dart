import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../services/record_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pp_widgets.dart';
import 'session.dart';

/// Record detail (PhonePe "transaction details" style). Shows the list row
/// immediately, then enriches it from the module's detail endpoint if any.
class DetailScreen extends StatefulWidget {
  final ErpModule module;
  final Map<String, dynamic> record;
  const DetailScreen({super.key, required this.module, required this.record});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Map<String, dynamic> _data = widget.record;
  bool _loading = false;

  ErpModule get m => widget.module;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.record[m.idKey];
    if (m.detail == null || id == null) return;
    setState(() => _loading = true);
    try {
      final d = await ApiService.instance.get('${m.detail}/$id', projectScoped: false);
      final rec = d is List ? (d.isNotEmpty ? d.first : null) : d;
      if (rec is Map && mounted) setState(() => _data = {...widget.record, ...Map<String, dynamic>.from(rec)});
    } on ApiException catch (e) {
      if (e.code == 401 && mounted) return handleSessionExpired(context);
      // Keep showing the list data if the detail call fails.
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = RecordUtils.titleKey(_data, m.titleKey);
    final sk = RecordUtils.subtitleKey(_data, tk, m.subtitleKey);
    final stk = RecordUtils.statusKey(_data);
    final ak = RecordUtils.amountKey(_data);
    final dk = RecordUtils.dateKey(_data);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(
        title: m.title,
        subtitle: m.canEdit ? null : (m.canApprove ? 'Approver • view only' : 'View only'),
        actions: [
          if (m.canEdit)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Edit form coming soon'))),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.sectionCard(),
              child: Column(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: AppTheme.glossyBrown(radius: 18),
                    child: Icon(m.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(tk == null ? m.title : RecordUtils.text(_data, tk), textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  if (sk != null) ...[
                    const SizedBox(height: 4),
                    Text(RecordUtils.text(_data, sk), textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                  ],
                  if (ak != null) ...[
                    const SizedBox(height: 12),
                    Text(RecordUtils.money(_data[ak]),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8, runSpacing: 6,
                    children: [
                      if (stk != null) StatusBadge('${_data[stk]}'),
                      if (dk != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(RecordUtils.text(_data, dk), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                    ],
                  ),
                ],
              ),
            ),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2)),
            const SizedBox(height: 12),
            FieldsView(data: _data),
          ],
        ),
      ),
    );
  }
}

/// Renders any JSON map: scalars as rows, nested maps as cards and
/// lists of maps as expandable item lists.
class FieldsView extends StatelessWidget {
  final Map<String, dynamic> data;
  final String title;
  const FieldsView({super.key, required this.data, this.title = 'Details'});

  @override
  Widget build(BuildContext context) {
    final scalars = <MapEntry<String, dynamic>>[];
    final maps = <MapEntry<String, Map>>[];
    final lists = <MapEntry<String, List>>[];
    for (final e in data.entries) {
      if (RecordUtils.isInternal(e.key)) continue;
      final v = e.value;
      if (v is Map) {
        if (v.isNotEmpty) maps.add(MapEntry(e.key, v));
      } else if (v is List) {
        if (v.isNotEmpty) lists.add(MapEntry(e.key, v));
      } else if (v != null && '$v'.trim().isNotEmpty) {
        scalars.add(e);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scalars.isNotEmpty)
          SectionCard(
            title: title,
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              for (var i = 0; i < scalars.length; i++)
                _Row(label: RecordUtils.humanize(scalars[i].key),
                    value: RecordUtils.format(scalars[i].key, scalars[i].value), last: i == scalars.length - 1),
            ]),
          ),
        for (final e in maps)
          FieldsView(data: Map<String, dynamic>.from(e.value), title: RecordUtils.humanize(e.key)),
        for (final e in lists) _ListSection(title: RecordUtils.humanize(e.key), items: e.value),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool last;
  const _Row({required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: Color(0x147B4A2A))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5))),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: SelectableText(value, textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _ListSection extends StatelessWidget {
  final String title;
  final List items;
  const _ListSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final maps = items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.sectionCard(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: maps.length <= 5,
          iconColor: AppColors.accent,
          collapsedIconColor: AppColors.textMuted,
          title: Text('$title (${items.length})',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: maps.isEmpty
              ? [Align(alignment: Alignment.centerLeft, child: Text(items.join(', ')))]
              : [
                  for (var i = 0; i < maps.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      decoration: BoxDecoration(color: AppColors.inputFill.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Row(children: [
                            CircleAvatar(radius: 11, backgroundColor: colorFor(i),
                                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                RecordUtils.text(maps[i], RecordUtils.titleKey(maps[i])),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                        for (final e in maps[i].entries.where((e) => !RecordUtils.isInternal(e.key) && e.value is! Map && e.value is! List && e.value != null))
                          _Row(label: RecordUtils.humanize(e.key), value: RecordUtils.format(e.key, e.value), last: true),
                      ]),
                    ),
                ],
        ),
      ),
    );
  }
}
