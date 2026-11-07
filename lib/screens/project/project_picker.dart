import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

/// Bottom sheet to choose the working project. Returns true if one was entered.
Future<bool> showProjectPicker(BuildContext context) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _ProjectPicker(),
  );
  return res ?? false;
}

class _ProjectPicker extends StatefulWidget {
  const _ProjectPicker();
  @override
  State<_ProjectPicker> createState() => _ProjectPickerState();
}

class _ProjectPickerState extends State<_ProjectPicker> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String? _entering;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await ApiService.instance.projects();
      if (mounted) setState(() { _all = p; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pick(Map<String, dynamic> p) async {
    setState(() => _entering = p['projectCode']?.toString());
    try {
      await ApiService.instance.enterProject(p);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _entering = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ApiService.instance.projectCode;
    final list = _all.where((p) {
      if (_q.isEmpty) return true;
      return '${p['projectCode']} ${p['projectName']} ${p['clientName']}'.toLowerCase().contains(_q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              Icon(Icons.business_center_rounded, color: AppColors.accent),
              SizedBox(width: 10),
              Text('Select Project', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search project code or name',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: List.generate(6, (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10), child: ShimmerLoader(height: 64, radius: 14))),
                  )
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ]))
                    : list.isEmpty
                        ? const Center(child: Text('No projects assigned to you', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.separated(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final p = list[i];
                              final code = p['projectCode']?.toString() ?? '';
                              final selected = code == current;
                              return Material(
                                color: selected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _entering == null ? () => _pick(p) : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: AppTheme.glossyBrown(radius: 12),
                                        alignment: Alignment.center,
                                        child: Text(code.isNotEmpty ? code.substring(0, code.length.clamp(0, 3)).toUpperCase() : 'P',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('${p['projectName'] ?? code}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
                                          const SizedBox(height: 2),
                                          Text([code, if (p['clientName'] != null) '${p['clientName']}'].join(' • '),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ]),
                                      ),
                                      if (_entering == code)
                                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      else if (selected)
                                        const Icon(Icons.check_circle_rounded, color: AppColors.accent2)
                                      else
                                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                    ]),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
