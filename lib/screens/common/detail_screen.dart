import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_card.dart';

class DetailScreen extends StatefulWidget {
  final String title;
  final String endpoint;
  final Map<String, dynamic> record;

  const DetailScreen({super.key, required this.title, required this.endpoint, required this.record});
  @override State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.instance.get(widget.endpoint);
      final rec = data is List ? (data.isNotEmpty ? data[0] : {}) : (data is Map ? data : {});
      if (mounted) setState(() { _detail = Map<String, dynamic>.from(rec); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? _buildShimmer()
                    : _error != null
                        ? _buildError()
                        : _buildDetail(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail() {
    final rec = _detail ?? widget.record;
    final entries = rec.entries.where((e) => e.value != null && '${e.value}'.isNotEmpty && '${e.value}' != 'null').toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Audit info if present
        if (rec['createdBy'] != null || rec['updatedBy'] != null) ...[
          _buildAuditCard(rec),
          const SizedBox(height: 14),
        ],
        // All fields grouped in card
        GlassCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: entries.asMap().entries.map((e) {
              final isLast = e.key == entries.length - 1;
              return _FieldRow(
                label: _formatKey(e.value.key),
                value: '${e.value.value}',
                isLast: isLast,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> rec) {
    return GlassCard(
      gradient: [const Color(0x1A3D8EFF), const Color(0x0A1A6FD4)],
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rec['createdBy'] != null)
                Text('Created by ${rec['createdBy']}${rec['createdAt'] != null ? ' · ${_formatDate(rec['createdAt'])}' : ''}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              if (rec['updatedBy'] != null)
                Text('Updated by ${rec['updatedBy']}${rec['updatedAt'] != null ? ' · ${_formatDate(rec['updatedAt'])}' : ''}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildShimmer() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: List.generate(10, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShimmerLoader(height: 44, radius: 10),
    ))),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.textMuted, size: 44),
        const SizedBox(height: 14),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accent)),
          child: const Text('Retry'),
        ),
      ],
    ),
  );

  String _formatKey(String key) {
    // camelCase → Title Case
    return key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatDate(dynamic val) {
    try {
      final dt = DateTime.parse('$val').toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return '$val'; }
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _FieldRow({required this.label, required this.value, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
