import 'package:flutter/material.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../project/project_picker.dart';
import 'list_screen.dart';
import 'report_screen.dart';

/// Single entry point for opening any module — checks availability,
/// access level and project selection before navigating.
Future<void> openModule(BuildContext context, ErpModule m) async {
  if (!m.canView) {
    _toast(context, 'You don\'t have access to ${m.title}');
    return;
  }
  if (!m.available) {
    _comingSoon(context, m);
    return;
  }
  if (m.projectScoped && ApiService.instance.projectCode == null) {
    final picked = await showProjectPicker(context);
    if (!picked || !context.mounted) return;
  }
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => m.kind == ModuleKind.report ? ReportScreen(module: m) : ListScreen(module: m),
    ),
  );
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

void _comingSoon(BuildContext context, ErpModule m) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.glassBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
              child: Icon(m.icon, color: AppColors.accent, size: 30),
            ),
            const SizedBox(height: 14),
            Text(m.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Coming soon to mobile.\nUse the web ERP for this module for now.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Okay'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
