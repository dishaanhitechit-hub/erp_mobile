import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/comm_api.dart';
import '../../services/comm_notifier.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';
import '../common/session.dart';
import '../../services/call_service.dart';
import 'chat_screen.dart';
import 'group_screens.dart';
import 'people_picker.dart';

/// Communication tab — Chats, Pings, Alerts and Notices, same data as the
/// web ERP's communication panel.
class CommScreen extends StatelessWidget {
  const CommScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(children: [
              const SizedBox(
                height: 52,
                child: Row(children: [
                  SizedBox(width: 16),
                  Text('Communication', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                ]),
              ),
              ListenableBuilder(
                listenable: CommNotifier.instance,
                builder: (_, __) {
                  final n = CommNotifier.instance;
                  return TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    dividerColor: Colors.transparent,
                    labelPadding: EdgeInsets.zero,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: [
                      _tab('Chats', n.unreadChats),
                      _tab('Calls', 0),
                      _tab('Pings', n.unreadPings),
                      _tab('Alerts', n.unreadAlerts),
                      _tab('Notices', 0),
                    ],
                  );
                },
              ),
            ]),
          ),
          const Expanded(
            child: TabBarView(children: [_ChatsTab(), _CallsTab(), _PingsTab(), _AlertsTab(), _NoticesTab()]),
          ),
        ],
      ),
    );
  }

  static Widget _tab(String label, int count) => Tab(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          if (count > 0) ...[const SizedBox(width: 5), CountBadge(count: count, light: true)],
        ]),
      );
}

/// Small red unread-count pill.
class CountBadge extends StatelessWidget {
  final int count;
  final bool light;
  const CountBadge({super.key, required this.count, this.light = false});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: light ? Colors.white : Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(count > 99 ? '99+' : '$count',
            textAlign: TextAlign.center,
            style: TextStyle(color: light ? AppColors.accent : Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

// ── Shared loader for each tab ───────────────────────────────────────────────

abstract class _LoaderState<T extends StatefulWidget, D> extends State<T> with AutomaticKeepAliveClientMixin {
  D? data;
  String? error;
  bool loading = true;

  Future<D> fetch();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await fetch();
      if (mounted) {
        setState(() {
          data = d;
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (e.code == 401 && mounted) return handleSessionExpired(context);
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
    CommNotifier.instance.check();
  }

  Widget wrap(Widget Function(D data) builder, {required IconData emptyIcon, required String emptyTitle, bool Function(D)? isEmpty}) {
    if (loading && data == null) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    Widget child;
    if (error != null && data == null) {
      child = ListView(children: [
        const SizedBox(height: 60),
        EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load', message: error),
      ]);
    } else if (isEmpty?.call(data as D) ?? false) {
      child = ListView(children: [const SizedBox(height: 60), EmptyState(icon: emptyIcon, title: emptyTitle)]);
    } else {
      child = builder(data as D);
    }
    return RefreshIndicator(onRefresh: load, color: AppColors.accent, child: child);
  }
}

// ── Chats ───────────────────────────────────────────────────────────────────

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();
  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends _LoaderState<_ChatsTab, List<Map<String, dynamic>>> {
  List<Map<String, dynamic>> _invites = [];

  @override
  Future<List<Map<String, dynamic>>> fetch() async {
    final r = await Future.wait([CommApi.conversations(), CommApi.invites().catchError((_) => <Map<String, dynamic>>[])]);
    _invites = r[1];
    return r[0];
  }

  Future<void> _respond(Map<String, dynamic> inv, bool accept) async {
    try {
      await CommApi.respondInvite(inv['conversationId'] as int, accept);
      await load();
      if (accept && mounted) _open(inv['conversationId'] as int, '${inv['name']}');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _newMenu() {
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.person_rounded, color: AppColors.accent),
            title: const Text('New chat'),
            onTap: () {
              Navigator.pop(s);
              _newChat();
            },
          ),
          ListTile(
            leading: const Icon(Icons.group_add_rounded, color: AppColors.accent),
            title: const Text('New group'),
            onTap: () {
              Navigator.pop(s);
              _newGroup();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _newGroup() async {
    final r = await Navigator.push<(int, String)>(context, MaterialPageRoute(builder: (_) => const NewGroupScreen()));
    if (r != null && mounted) _open(r.$1, r.$2);
  }

  Widget _invitesCard() => Card(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        color: AppColors.accent.withValues(alpha: 0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          for (final inv in _invites)
            ListTile(
              leading: const PersonAvatar(name: 'G', icon: Icons.group_add_rounded),
              title: Text('${inv['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${inv['invitedBy'] ?? 'Someone'} invited you • ${inv['memberCount'] ?? 0} members',
                  style: const TextStyle(fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Decline',
                  onPressed: () => _respond(inv, false),
                  icon: const Icon(Icons.close_rounded, color: Colors.red),
                ),
                IconButton(
                  tooltip: 'Join',
                  onPressed: () => _respond(inv, true),
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                ),
              ]),
            ),
        ]),
      );

  @override
  void initState() {
    super.initState();
    CommNotifier.instance.addListener(_onCounts);
  }

  @override
  void dispose() {
    CommNotifier.instance.removeListener(_onCounts);
    super.dispose();
  }

  int _lastUnread = 0;
  void _onCounts() {
    // a new message arrived somewhere → refresh the list
    final u = CommNotifier.instance.unreadChats;
    if (u != _lastUnread) {
      _lastUnread = u;
      load();
    }
  }

  Future<void> _open(int id, String title, {String? subtitle}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, title: title, subtitle: subtitle)));
    load();
  }

  Future<void> _newChat() async {
    final p = await pickPerson(context, title: 'New chat');
    if (p == null || !mounted) return;
    try {
      final id = await CommApi.startDirect(p['userId'] as int);
      if (mounted) _open(id, '${p['userName']}', subtitle: '${p['empCode'] ?? ''}');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton(
        heroTag: 'newChat',
        backgroundColor: AppColors.accent,
        onPressed: _newMenu,
        child: const Icon(Icons.edit_square, color: Colors.white),
      ),
      body: wrap(
        (convs) => ListView.separated(
          padding: const EdgeInsets.only(top: 6, bottom: 90),
          itemCount: convs.length + (_invites.isEmpty ? 0 : 1),
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
          itemBuilder: (_, idx) {
            if (_invites.isNotEmpty && idx == 0) return _invitesCard();
            final i = _invites.isEmpty ? idx : idx - 1;
            final c = convs[i];
            final name = '${c['name'] ?? 'Chat'}';
            final type = '${c['type']}';
            final last = c['lastMessage'];
            final unread = (c['unreadCount'] as num? ?? 0).toInt();
            final preview = last is Map
                ? '${type != 'direct' && last['senderName'] != null ? '${last['senderName']}: ' : ''}${last['content'] ?? '📎 Attachment'}'
                : 'No messages yet';
            return ListTile(
              onTap: () => _open(c['conversationId'] as int, name,
                  subtitle: type == 'context' ? '${c['contextModule'] ?? ''} ${c['contextRecordRef'] ?? ''}'.trim() : null),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: PersonAvatar(
                name: name,
                colorIndex: i,
                icon: type == 'group' ? Icons.groups_rounded : (type == 'context' ? Icons.description_rounded : null),
              ),
              title: Row(children: [
                Expanded(
                  child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600, color: AppColors.textPrimary)),
                ),
                Text(CommApi.shortTime(last is Map ? last['sentAt'] as String? : c['updatedAt'] as String?),
                    style: TextStyle(fontSize: 11.5, color: unread > 0 ? AppColors.accent : AppColors.textMuted)),
              ]),
              subtitle: Row(children: [
                if (c['isMuted'] == true) const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.volume_off_rounded, size: 14, color: AppColors.textMuted),
                ),
                Expanded(
                  child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: unread > 0 ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13)),
                ),
                if (unread > 0) CountBadge(count: unread),
              ]),
            );
          },
        ),
        emptyIcon: Icons.forum_outlined,
        emptyTitle: 'No chats yet — tap ✎ to start one',
        isEmpty: (d) => d.isEmpty && _invites.isEmpty,
      ),
    );
  }
}

// ── Calls ───────────────────────────────────────────────────────────────────

class _CallsTab extends StatefulWidget {
  const _CallsTab();
  @override
  State<_CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends _LoaderState<_CallsTab, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> fetch() => CommApi.callHistory();

  List<Map<String, dynamic>> _others(Map<String, dynamic> c) => (c['participants'] as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((p) => p['userId'] != ApiService.instance.userId)
      .toList();

  Future<void> _call(List<Map<String, dynamic>> people, bool video) async {
    await CallService.instance.startCall(context, people, video: video);
    load();
  }

  Future<void> _newCall(bool video) async {
    final picked = await pickPeople(context, title: video ? 'New video call' : 'New voice call', action: 'Call',
        exclude: {ApiService.instance.userId ?? 0});
    if (picked != null && picked.isNotEmpty && mounted) _call(picked, video);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final me = ApiService.instance.userId;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.small(
          heroTag: 'newVideoCall',
          backgroundColor: AppColors.bgCard,
          onPressed: () => _newCall(true),
          child: const Icon(Icons.videocam_rounded, color: AppColors.accent),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'newCall',
          backgroundColor: AppColors.accent,
          onPressed: () => _newCall(false),
          child: const Icon(Icons.add_call, color: Colors.white),
        ),
      ]),
      body: wrap(
        (calls) => ListView.separated(
          padding: const EdgeInsets.only(top: 6, bottom: 140),
          itemCount: calls.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
          itemBuilder: (_, i) {
            final c = calls[i];
            final others = _others(c);
            final video = c['callType'] == 'video';
            final outgoing = c['initiatorId'] == me;
            final mine = (c['participants'] as List? ?? []).whereType<Map>().where((p) => p['userId'] == me).firstOrNull;
            final missed = !outgoing && ['missed', 'declined', 'ringing'].contains(mine?['state']);
            final names = others.map((p) => '${p['userName'] ?? ''}').join(', ');
            final secs = (c['durationSeconds'] as num?)?.toInt() ?? 0;
            final dur = secs > 0 && !missed ? ' • ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}' : '';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: PersonAvatar(
                name: names,
                colorIndex: i,
                icon: others.length > 1 ? Icons.groups_rounded : null,
              ),
              title: Text(names.isEmpty ? 'Call' : names,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: missed ? Colors.red : AppColors.textPrimary)),
              subtitle: Row(children: [
                Icon(
                  missed ? Icons.call_missed_rounded : (outgoing ? Icons.call_made_rounded : Icons.call_received_rounded),
                  size: 15,
                  color: missed ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${CommApi.shortTime(c['startedAt'] as String?)}$dur',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ),
              ]),
              trailing: IconButton(
                tooltip: video ? 'Video call' : 'Voice call',
                onPressed: others.isEmpty ? null : () => _call(others, video),
                icon: Icon(video ? Icons.videocam_rounded : Icons.call_rounded, color: AppColors.accent),
              ),
            );
          },
        ),
        emptyIcon: Icons.call_outlined,
        emptyTitle: 'No calls yet — tap + to call someone',
        isEmpty: (d) => d.isEmpty,
      ),
    );
  }
}

// ── Pings ───────────────────────────────────────────────────────────────────

class _PingsTab extends StatefulWidget {
  const _PingsTab();
  @override
  State<_PingsTab> createState() => _PingsTabState();
}

class _PingsTabState extends _LoaderState<_PingsTab, (List<Map<String, dynamic>>, List<Map<String, dynamic>>)> {
  bool _sent = false;

  @override
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> fetch() async {
    final r = await Future.wait([CommApi.receivedPings(), CommApi.sentPings()]);
    return (r[0], r[1]);
  }

  Future<void> _markRead(Map<String, dynamic> p) async {
    if (p['isRead'] == true || _sent) return;
    try {
      await CommApi.markPingRead(p['id'] as int);
      setState(() => p['isRead'] = true);
      CommNotifier.instance.check();
    } catch (_) {}
  }

  Future<void> _sendPing() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _SendPingSheet(),
    );
    if (ok == true) {
      setState(() => _sent = true);
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sendPing',
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: _sendPing,
        icon: const Icon(Icons.notifications_active_rounded),
        label: const Text('Ping'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Received'), icon: Icon(Icons.call_received_rounded, size: 16)),
                  ButtonSegment(value: true, label: Text('Sent'), icon: Icon(Icons.call_made_rounded, size: 16)),
                ],
                selected: {_sent},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _sent = s.first),
              ),
            ),
            if (!_sent)
              IconButton(
                tooltip: 'Mark all read',
                onPressed: () async {
                  await CommApi.markAllPingsRead();
                  load();
                },
                icon: const Icon(Icons.done_all_rounded, color: AppColors.accent),
              ),
          ]),
        ),
        Expanded(
          child: wrap(
            (d) {
              final list = _sent ? d.$2 : d.$1;
              if (list.isEmpty) {
                return ListView(children: [
                  const SizedBox(height: 60),
                  EmptyState(icon: Icons.notifications_none_rounded, title: _sent ? 'No pings sent' : 'No pings received'),
                ]);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                itemCount: list.length,
                itemBuilder: (_, i) => _PingCard(ping: list[i], sent: _sent, onTap: () => _markRead(list[i])),
              );
            },
            emptyIcon: Icons.notifications_none_rounded,
            emptyTitle: 'No pings',
          ),
        ),
      ]),
    );
  }
}

class _PingCard extends StatelessWidget {
  final Map<String, dynamic> ping;
  final bool sent;
  final VoidCallback onTap;
  const _PingCard({required this.ping, required this.sent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !sent && ping['isRead'] != true;
    final type = '${ping['pingType']}';
    final urgent = type == 'urgent' || type == 'attention';
    final who = sent ? 'To ${ping['receiverName'] ?? ''}' : '${ping['senderName'] ?? ''}';
    final record = [ping['contextModule'], ping['contextRecordRef']].where((v) => v != null && '$v'.isNotEmpty).join(' • ');
    final status = ping['recordStatus'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.sectionCard(),
      child: ListTile(
        onTap: onTap,
        leading: PersonAvatar(name: who.replaceFirst('To ', ''), colorIndex: (ping['senderId'] as int? ?? 0)),
        title: Row(children: [
          Expanded(
            child: Text(who, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
          ),
          Text(CommApi.shortTime(ping['createdAt'] as String?), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _Chip(label: '${ping['pingLabel'] ?? CommApi.pingTypes[type] ?? type}', color: urgent ? Colors.red : AppColors.accent),
            if (status != null) _Chip(label: '$status', color: Colors.blueGrey),
          ]),
          if ((ping['message'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('${ping['message']}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
            ),
          if (record.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(record, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
        ]),
        trailing: unread
            ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
            : null,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

class _SendPingSheet extends StatefulWidget {
  const _SendPingSheet();
  @override
  State<_SendPingSheet> createState() => _SendPingSheetState();
}

class _SendPingSheetState extends State<_SendPingSheet> {
  Map<String, dynamic>? _to;
  String _type = 'ping';
  final _msg = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_to == null) return;
    setState(() => _sending = true);
    try {
      await CommApi.sendPing(_to!['userId'] as int, _type, _msg.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ping sent to ${_to!['userName']}')));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Send a ping', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Material(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.person_rounded, color: AppColors.accent),
            title: Text(_to == null ? 'Choose person' : '${_to!['userName']}'),
            subtitle: _to == null ? null : Text('${_to!['empCode'] ?? ''}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final p = await pickPerson(context, title: 'Ping who?');
              if (p != null) setState(() => _to = p);
            },
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in CommApi.pingTypes.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _type == e.key,
              selectedColor: AppColors.accent.withValues(alpha: 0.2),
              onSelected: (_) => setState(() => _type = e.key),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _msg,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(
            hintText: 'Message (optional)',
            filled: true,
            fillColor: AppColors.bgCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _to == null || _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Send ping'),
          ),
        ),
      ]),
    );
  }
}

// ── Alerts (notifications) ──────────────────────────────────────────────────

class _AlertsTab extends StatefulWidget {
  const _AlertsTab();
  @override
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends _LoaderState<_AlertsTab, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> fetch() async => CommApi.items(await CommApi.notifications());

  Future<void> _read(Map<String, dynamic> n) async {
    if (n['isRead'] == true) return;
    try {
      await CommApi.markNotificationRead(n['id'] as int);
      setState(() => n['isRead'] = true);
      CommNotifier.instance.check();
    } catch (_) {}
  }

  static IconData _icon(String t) => switch (t) {
        'ping' => Icons.notifications_active_rounded,
        'message' => Icons.chat_rounded,
        'call' || 'missed_call' => Icons.call_rounded,
        'meeting' => Icons.event_rounded,
        'announcement' => Icons.campaign_rounded,
        _ => Icons.info_rounded,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return wrap(
      (list) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
        itemCount: list.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await CommApi.markAllNotificationsRead();
                  load();
                },
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark all read'),
              ),
            );
          }
          final n = list[i - 1];
          final unread = n['isRead'] != true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: AppTheme.sectionCard(),
            child: ListTile(
              onTap: () => _read(n),
              leading: PersonAvatar(name: '', icon: _icon('${n['type']}'), colorIndex: i),
              title: Text('${n['title'] ?? ''}', style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if ((n['body'] ?? '').toString().isNotEmpty) Text('${n['body']}'),
                const SizedBox(height: 2),
                Text(CommApi.shortTime(n['createdAt'] as String?), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
              trailing: unread
                  ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))
                  : null,
            ),
          );
        },
      ),
      emptyIcon: Icons.notifications_off_outlined,
      emptyTitle: 'No alerts',
      isEmpty: (d) => d.isEmpty,
    );
  }
}

// ── Notices (announcements) ─────────────────────────────────────────────────

class _NoticesTab extends StatefulWidget {
  const _NoticesTab();
  @override
  State<_NoticesTab> createState() => _NoticesTabState();
}

class _NoticesTabState extends _LoaderState<_NoticesTab, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> fetch() => CommApi.announcements();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return wrap(
      (list) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final a = list[i];
          final high = '${a['priority']}' == 'high' || '${a['priority']}' == 'urgent';
          final unread = a['isRead'] != true;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.sectionCard(),
            child: InkWell(
              onTap: () async {
                if (!unread) return;
                try {
                  await CommApi.markAnnouncementRead(a['id'] as int);
                  setState(() => a['isRead'] = true);
                } catch (_) {}
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.campaign_rounded, color: high ? Colors.red : AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${a['title'] ?? ''}',
                        style: TextStyle(fontSize: 15, fontWeight: unread ? FontWeight.w800 : FontWeight.w700)),
                  ),
                  if (unread) Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                ]),
                const SizedBox(height: 8),
                Text('${a['body'] ?? ''}', style: const TextStyle(color: AppColors.textPrimary, height: 1.35)),
                const SizedBox(height: 8),
                Text(CommApi.shortTime(a['createdAt'] as String?), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ]),
            ),
          );
        },
      ),
      emptyIcon: Icons.campaign_outlined,
      emptyTitle: 'No notices',
      isEmpty: (d) => d.isEmpty,
    );
  }
}
