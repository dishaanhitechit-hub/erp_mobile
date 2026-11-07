import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';

/// All modules of one navbar section, split by sub-group.
class SectionScreen extends StatelessWidget {
  final ModuleSection section;
  const SectionScreen({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final groups = section.groups
        .map((g) => ModuleGroup(g.title, g.modules.where((m) => m.canView).toList()))
        .where((g) => g.modules.isNotEmpty)
        .toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(title: section.title),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        itemCount: groups.length,
        itemBuilder: (_, i) => SectionCard(
          title: groups[i].title,
          child: ModuleGrid(modules: groups[i].modules, colorOffset: i * 2),
        ),
      ),
    );
  }
}
