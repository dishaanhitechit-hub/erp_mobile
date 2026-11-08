import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';

/// "Modules" tab — the web navbar as horizontal section tabs, each showing
/// its sub-groups as PhonePe-style cards.
class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild when the project (and so the permissions) changes.
    return ListenableBuilder(listenable: ApiService.instance, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final sections = visibleSections;
    if (sections.isEmpty) {
      return Column(children: [
        Container(
          decoration: BoxDecoration(gradient: AppTheme.headerGradient),
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 16),
          alignment: Alignment.centerLeft,
          child: const Text('All Modules', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
        ),
        const Expanded(
          child: EmptyState(icon: Icons.lock_outline_rounded, title: 'No modules available',
              message: 'You don\'t have access to any module in this project.'),
        ),
      ]);
    }
    return DefaultTabController(
      // New controller whenever the visible sections change.
      key: ValueKey(sections.map((s) => s.key).join(',')),
      length: sections.length,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(gradient: AppTheme.headerGradient),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(
              children: [
                const SizedBox(
                  height: 52,
                  child: Row(children: [
                    SizedBox(width: 16),
                    Text('All Modules', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                  ]),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  tabs: [
                    for (final s in sections)
                      Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(s.icon, size: 17),
                        const SizedBox(width: 6),
                        Text(s.shortTitle),
                      ])),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final s in sections)
                  ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    children: [
                      for (final (gi, g) in s.groups.indexed)
                        if (g.modules.any((m) => m.canView))
                          SectionCard(
                            title: g.title,
                            child: ModuleGrid(modules: g.modules.where((m) => m.canView).toList(), colorOffset: gi * 2),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
