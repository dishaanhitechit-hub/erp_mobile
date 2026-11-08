import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/call_service.dart';
import '../../services/comm_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';
import 'people_picker.dart';

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

// ── New group ───────────────────────────────────────────────────────────────

/// Create a group (same as the web: members get an invite they accept).
/// Pops with the new conversation id.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});
  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _members = <Map<String, dynamic>>[];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final picked = await pickPeople(context, title: 'Add members', exclude: {
      ApiService.instance.userId ?? 0,
      ..._members.map((m) => m['userId'] as int),
    });
    if (picked != null) setState(() => _members.addAll(picked));
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return _snack(context, 'Enter a group name');
    if (_members.isEmpty) return _snack(context, 'Add at least one member');
    setState(() => _saving = true);
    try {
      final id = await CommApi.createGroup(name, _members.map((m) => m['userId'] as int).toList(),
          description: _desc.text.trim());
      if (mounted) Navigator.pop(context, (id, name));
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const PPAppBar(title: 'New group'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: _saving ? null : _create,
        icon: _saving
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_rounded, color: Colors.white),
        label: const Text('Create group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: _input('Group name', Icons.groups_rounded),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: _input('Description (optional)', Icons.notes_rounded),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Text('Members (${_members.length})',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
          const Spacer(),
          TextButton.icon(onPressed: _add, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add')),
        ]),
        if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('No members yet. They get an invite to join the group.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ),
        for (final (i, m) in _members.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PersonAvatar(name: '${m['userName']}', colorIndex: i),
            title: Text('${m['userName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${m['empCode'] ?? ''}'),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _members.removeAt(i)),
            ),
          ),
      ]),
    );
  }
}

InputDecoration _input(String hint, IconData icon) => InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );

// ── Group info ──────────────────────────────────────────────────────────────

/// Members, admin actions, rename, leave. Pops with `true` if you left the group.
class GroupInfoScreen extends StatefulWidget {
  final int conversationId;
  const GroupInfoScreen({super.key, required this.conversationId});
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? _info;
  String? _error;

  int get _id => widget.conversationId;
  bool get _admin => _info?['myRole'] == 'admin';
  List<Map<String, dynamic>> get _members =>
      (_info?['members'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await CommApi.conversation(_id);
      if (mounted) {
        setState(() {
          _info = d;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) _snack(context, done);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.code == 403 ? 'Only group admins can do that' : e.message);
    }
  }

  Future<void> _addMembers() async {
    final picked = await pickPeople(context,
        title: 'Invite to group', action: 'Invite', exclude: _members.map((m) => m['userId'] as int).toSet());
    if (picked == null || picked.isEmpty) return;
    await _run(() => CommApi.inviteToGroup(_id, picked.map((p) => p['userId'] as int).toList()),
        'Invited ${picked.length} ${picked.length == 1 ? 'person' : 'people'}');
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: '${_info?['name'] ?? ''}');
    final desc = TextEditingController(text: '${_info?['description'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Edit group'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await _run(() => CommApi.updateGroupInfo(_id, name: ctrl.text.trim(), description: desc.text.trim()), 'Group updated');
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text('You will stop getting messages from this group.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CommApi.leaveConversation(_id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  void _memberMenu(Map<String, dynamic> m) {
    final me = ApiService.instance.userId;
    final uid = m['userId'] as int;
    if (uid == me) return;
    showModalBottomSheet(
      context: context,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('${m['userName']}', style: const TextStyle(fontWeight: FontWeight.w700))),
          ListTile(
            leading: const Icon(Icons.call_rounded),
            title: const Text('Voice call'),
            onTap: () {
              Navigator.pop(s);
              CallService.instance.startCall(context, [m], video: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_rounded),
            title: const Text('Video call'),
            onTap: () {
              Navigator.pop(s);
              CallService.instance.startCall(context, [m], video: true);
            },
          ),
          if (_admin && m['role'] != 'admin')
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: const Text('Make group admin'),
              onTap: () {
                Navigator.pop(s);
                _run(() => CommApi.promoteMember(_id, uid), '${m['userName']} is now an admin');
              },
            ),
          if (_admin)
            ListTile(
              leading: const Icon(Icons.person_remove_rounded, color: Colors.red),
              title: const Text('Remove from group', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(s);
                _run(() => CommApi.removeMember(_id, uid), '${m['userName']} removed');
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final members = _members;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(title: 'Group info', actions: [
        if (_admin) IconButton(onPressed: _rename, icon: const Icon(Icons.edit_rounded, color: Colors.white)),
      ]),
      body: info == null
          ? (_error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load group', message: _error)
              : Center(child: CircularProgressIndicator(color: AppColors.accent)))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                const SizedBox(height: 20),
                Center(child: PersonAvatar(name: '${info['name']}', radius: 42, icon: Icons.groups_rounded)),
                const SizedBox(height: 12),
                Center(
                  child: Text('${info['name'] ?? 'Group'}',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
                if ('${info['description'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 6, 30, 0),
                    child: Text('${info['description']}',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _QuickAction(
                    icon: Icons.call_rounded,
                    label: 'Group call',
                    onTap: () => CallService.instance.startCall(context, members, video: false),
                  ),
                  const SizedBox(width: 14),
                  _QuickAction(
                    icon: Icons.videocam_rounded,
                    label: 'Video call',
                    onTap: () => CallService.instance.startCall(context, members, video: true),
                  ),
                  const SizedBox(width: 14),
                  _QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'Invite', onTap: _addMembers),
                ]),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text('${members.length} members',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
                for (final (i, m) in members.indexed)
                  ListTile(
                    onTap: () => _memberMenu(m),
                    leading: PersonAvatar(name: '${m['userName']}', colorIndex: i),
                    title: Text(
                      m['userId'] == ApiService.instance.userId ? '${m['userName']} (You)' : '${m['userName']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${m['empCode'] ?? ''}'),
                    trailing: m['role'] == 'admin'
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Admin',
                                style: TextStyle(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          )
                        : null,
                  ),
                const Divider(height: 30),
                ListTile(
                  onTap: _leave,
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Leave group', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
