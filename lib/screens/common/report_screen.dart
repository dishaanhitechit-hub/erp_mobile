import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../services/record_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pp_widgets.dart';
import 'detail_screen.dart';
import 'session.dart';

/// Read-only report modules (P&L, Balance Sheet, My Ledger…).
class ReportScreen extends StatefulWidget {
  final ErpModule module;
  const ReportScreen({super.key, required this.module});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  dynamic _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ApiService.instance.get(widget.module.endpoint!,
          params: widget.module.params, projectScoped: widget.module.projectScoped);
      if (mounted) setState(() { _data = d; _loading = false; });
    } on ApiException catch (e) {
      if (e.code == 401 && mounted) return handleSessionExpired(context);
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ApiService.instance.currentProject;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(title: widget.module.title, subtitle: p?['projectName']?.toString()),
      body: _loading
          ? ListView(padding: const EdgeInsets.all(12), children: List.generate(5,
              (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: ShimmerLoader(height: 90, radius: 16))))
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Couldn\'t load report', message: _error,
                  action: OutlinedButton(onPressed: _load, child: const Text('Retry')))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.accent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    children: [
                      if (_data is Map)
                        FieldsView(data: Map<String, dynamic>.from(_data), title: 'Summary')
                      else if (_data is List && (_data as List).isNotEmpty)
                        for (final r in RecordUtils.extractList(_data))
                          FieldsView(data: r, title: RecordUtils.text(r, RecordUtils.titleKey(r)))
                      else
                        const EmptyState(icon: Icons.insert_chart_outlined_rounded, title: 'No data for this project'),
                    ],
                  ),
                ),
    );
  }
}
