import 'package:flutter/material.dart';
import '../../config/access_control.dart';
import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../services/offline_store.dart';
import '../../services/offline_sync.dart';
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
              decoration: BoxDecoration(gradient: AppTheme.headerGradient),
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
              _tile(Icons.palette_rounded, 'Theme', ThemeController.instance.value.name,
                  onTap: () => showThemePicker(context)),
            ]),
            const _OfflineCard(),
            _card([
              _tile(Icons.info_outline_rounded, 'App version', '1.0.3'),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
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
      subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
      trailing: onTap == null ? null : Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }
}


/// Bottom sheet with the colour themes.
Future<void> showThemePicker(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choose theme', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final p in AppThemes.all) _ThemeSwatch(p, onTap: () {
                Navigator.pop(ctx);
                ThemeController.instance.set(p);
              })],
            ),
          ]),
        ),
      ),
    );

class _ThemeSwatch extends StatelessWidget {
  final AppPalette p;
  final VoidCallback onTap;
  const _ThemeSwatch(this.p, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = ThemeController.instance.value.id == p.id;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppColors.accent : AppColors.glassBorder, width: sel ? 2.4 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: p.isDark ? const [Color(0xFF2A2F3A), Color(0xFF1C2028)] : [p.accentDark, p.accent]),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (sel) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                for (final c in [p.accent, p.accent2, p.accent4, p.accent3])
                  Container(
                    width: 20, height: 20, margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                const Spacer(),
                Container(
                  width: 34, height: 24,
                  decoration: BoxDecoration(color: p.bgCard, borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: p.textMuted.withValues(alpha: 0.4))),
                  alignment: Alignment.center,
                  child: Text('Aa', style: TextStyle(color: p.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Offline: sync now, last sync, saved data size, queued items.
class _OfflineCard extends StatefulWidget {
  const _OfflineCard();
  @override
  State<_OfflineCard> createState() => _OfflineCardState();
}

class _OfflineCardState extends State<_OfflineCard> {
  (int, int) _stats = (0, 0);

  @override
  void initState() {
    super.initState();
    OfflineSync.instance.loadLastSync();
    _refreshStats();
    OfflineSync.instance.addListener(_onSync);
  }

  @override
  void dispose() {
    OfflineSync.instance.removeListener(_onSync);
    super.dispose();
  }

  bool _wasRunning = false;
  void _onSync() {
    final running = OfflineSync.instance.running;
    if (_wasRunning && !running) _refreshStats();
    _wasRunning = running;
  }

  Future<void> _refreshStats() async {
    final s = await OfflineStore.instance.stats();
    if (mounted) setState(() => _stats = s);
  }

  static String _size(int b) => b < 1024 * 1024 ? '${(b / 1024).toStringAsFixed(0)} KB' : '${(b / 1048576).toStringAsFixed(1)} MB';

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear saved data?'),
        content: const Text('Offline copies on this phone will be removed. They are downloaded again when you use the app online.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await OfflineStore.instance.clear();
    _refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([OfflineSync.instance, Outbox.instance, NetworkStatus.instance]),
      builder: (context, _) {
        final sync = OfflineSync.instance;
        final online = NetworkStatus.instance.online;
        final pending = Outbox.instance.items.length;
        final last = sync.lastSync;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: AppTheme.sectionCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Offline use', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Text(online ? 'Online' : 'Offline',
                  style: TextStyle(color: online ? AppColors.accent2 : AppColors.accent3, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Lists, details, reports and chats you can see are saved on this phone, so the app works without internet. '
              'Messages and pings sent offline go out automatically when you are back online.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              [
                last == null ? 'Not synced yet' : 'Last synced ${savedAgo(last)}',
                '${_stats.$1} saved • ${_size(_stats.$2)}',
                if (pending > 0) '$pending waiting to send',
              ].join('  •  '),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (sync.running) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: sync.progress, minHeight: 4, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 4),
              Text('Saving ${sync.step}…', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ] else if (sync.lastError != null) ...[
              const SizedBox(height: 6),
              Text(sync.lastError!, style: TextStyle(color: AppColors.accent3, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: sync.running || !online ? null : () => sync.run(),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                  icon: const Icon(Icons.download_for_offline_rounded, size: 19),
                  label: Text(sync.running ? 'Syncing…' : 'Sync for offline'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: sync.running ? null : _clear,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: BorderSide(color: AppColors.glassBorder)),
                child: const Text('Clear'),
              ),
            ]),
          ]),
        );
      },
    );
  }
}
