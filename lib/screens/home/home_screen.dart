import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';
import '../modules/section_screen.dart';
import '../project/project_picker.dart';

/// PhonePe-style home: brand header, project card, then one card per
/// navbar section with a 4-column icon grid.
class HomeScreen extends StatelessWidget {
  final VoidCallback onSearch;
  const HomeScreen({super.key, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final api = ApiService.instance;
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final sections = visibleSections;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  Column(children: [_Header(onSearch: onSearch), const SizedBox(height: 52)]),
                  Positioned(left: 0, right: 0, bottom: 0, child: _ProjectBanner(project: api.currentProject)),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (sections.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'No modules available',
                  message: api.currentProject == null
                      ? 'Select a project to see the modules you can access.'
                      : 'You don\'t have access to any module in this project. Ask your admin for permission or switch project.',
                ),
              ),
            SliverList.builder(
              itemCount: sections.length,
              itemBuilder: (context, i) {
                final s = sections[i];
                final mods = s.visibleModules;
                final shown = mods.take(8).toList();
                return SectionCard(
                  title: s.title,
                  actionLabel: mods.length > 8 ? 'View all' : null,
                  onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SectionScreen(section: s))),
                  child: ModuleGrid(modules: shown, colorOffset: i * 3),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSearch;
  const _Header({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final api = ApiService.instance;
    final name = api.userName;
    final p = api.currentProject;
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 8, 52),
      child: Row(
        children: [
          const UserAvatar(radius: 21),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => showProjectPicker(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hi, $name', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(p == null ? 'Select project' : '${p['projectCode']} • ${p['projectName'] ?? ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                  ]),
                ],
              ),
            ),
          ),
          IconButton(onPressed: onSearch, icon: const Icon(Icons.search_rounded, color: Colors.white)),
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('No new notifications'))),
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ProjectBanner extends StatelessWidget {
  final Map<String, dynamic>? project;
  const _ProjectBanner({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.sectionCard(),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: AppTheme.glossyBrown(radius: 14),
              child: const Icon(Icons.apartment_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project == null ? 'No project selected' : '${project!['projectName'] ?? project!['projectCode']}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    project == null
                        ? 'Pick a project to see its records'
                        : [project!['projectCode'], if (project!['clientName'] != null) project!['clientName']].join(' • '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => showProjectPicker(context),
              child: Text(project == null ? 'Select' : 'Switch'),
            ),
          ],
        ),
    );
  }
}
