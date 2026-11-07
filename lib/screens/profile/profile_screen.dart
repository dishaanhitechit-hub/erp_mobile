import 'package:flutter/material.dart';
import '../../config/access_control.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';
import '../project/project_picker.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService.instance;
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final name = api.userName;
        final p = api.currentProject;
        final all = [for (final s in allSections) ...s.modules];
        final live = all.where((m) => m.available).length;
        final visible = all.where((m) => m.canView).length;
        final editable = all.where((m) => m.canEdit).length;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 28),
              child: Row(children: [
                const UserAvatar(radius: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text(Roles.label(api.userRole).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            _card([
              _tile(Icons.apartment_rounded, 'Current project',
                  p == null ? 'Not selected' : '${p['projectCode']} • ${p['projectName'] ?? ''}',
                  onTap: () => showProjectPicker(context)),
              _tile(Icons.visibility_rounded, 'Access mode', AccessControl.modeLabel),
              _tile(Icons.verified_user_rounded, 'Your access',
                  '$visible module(s) visible • ${editable == 0 ? 'none editable' : '$editable editable'}'),
              _tile(Icons.apps_rounded, 'Modules on mobile', '$live of ${all.length} live'),
            ]),
            _card([
              _tile(Icons.info_outline_rounded, 'App version', '1.0.1'),
              _tile(Icons.logout_rounded, 'Log out', null, danger: true, onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
                    ],
                  ),
                );
                if (ok != true) return;
                await api.logout();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/login', (_) => false);
                }
              }),
            ]),
            if (!AccessControl.allowEdit)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Text('Editing is turned off on mobile for now. Records are view-only.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: AppTheme.sectionCard(),
        child: Column(children: children),
      );

  Widget _tile(IconData icon, String title, String? subtitle, {VoidCallback? onTap, bool danger = false}) {
    final c = danger ? AppColors.accent3 : AppColors.accent;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(title, style: TextStyle(color: danger ? c : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14.5)),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }
}
