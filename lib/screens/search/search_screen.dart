import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';
import '../common/module_router.dart';

/// Search across every module the user can view.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    // Rebuild when the project (and so the permissions) changes.
    return ListenableBuilder(listenable: ApiService.instance, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final results = <(ModuleSection, ModuleGroup, ErpModule)>[
      for (final s in visibleSections)
        for (final g in s.groups)
          for (final m in g.modules)
            if (m.canView &&
                (_q.isEmpty ||
                    '${m.title} ${g.title} ${s.title}'.toLowerCase().contains(_q)))
              (s, g, m),
    ];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(gradient: AppTheme.headerGradient),
          padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 10, 12, 14),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search modules — indent, GRN, payroll…',
              filled: true,
              fillColor: AppColors.bgCard,
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const EmptyState(icon: Icons.search_off_rounded, title: 'No module found')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final (s, g, m) = results[i];
                    final c = colorFor(i);
                    return Material(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onTap: () => openModule(context, m),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: m.available ? c : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(m.icon, color: m.available ? Colors.white : AppColors.textMuted, size: 20),
                        ),
                        title: Text(m.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text(g.title == s.title ? s.title : '${s.title} › ${g.title}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: m.available
                            ? Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)
                            : Text('Soon', style: TextStyle(color: AppColors.accent4, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
