import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/call_service.dart';
import '../../services/comm_api.dart';
import '../../services/comm_notifier.dart';
import '../../services/offline_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';
import '../common/session.dart';
import 'group_screens.dart';

/// One conversation: message history, live updates (polling, like the web)
/// and a send box.
class ChatScreen extends StatefulWidget {
  final int conversationId;
  final String title;
  final String? subtitle;
  const ChatScreen({super.key, required this.conversationId, required this.title, this.subtitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <Map<String, dynamic>>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingOlder = false;
  bool _sending = false;
  String? _error;
  Map<String, dynamic>? _info; // type, members, myRole

  int? get _lastId => _messages.isEmpty ? null : _messages.last['id'] as int?;

  @override
  void initState() {
    super.initState();
    _load();
    _loadInfo();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _fetchNew());
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 60) _loadOlder();
    });
    Outbox.instance.addListener(_onOutbox);
    Outbox.instance.delivered.addListener(_fetchNew);
    NetworkStatus.instance.backOnline.addListener(_onBackOnline);
  }

  void _onOutbox() {
    if (mounted) setState(() {});
  }

  void _onBackOnline() {
    if (_error != null) _load();
    _loadInfo();
  }

  /// Messages typed offline, shown with a clock until they are sent.
  List<Map<String, dynamic>> get _pending => [
        for (final i in Outbox.instance.withTag('chat:${widget.conversationId}'))
          {'id': 'p${i.id}', 'isMine': true, 'type': 'text', 'content': i.body['content'], 'pending': true},
      ];

  @override
  void dispose() {
    Outbox.instance.removeListener(_onOutbox);
    Outbox.instance.delivered.removeListener(_fetchNew);
    NetworkStatus.instance.backOnline.removeListener(_onBackOnline);
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    CommNotifier.instance.check(); // refresh unread badges
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await CommApi.messages(widget.conversationId);
      _messages
        ..clear()
        ..addAll(_list(r['messages']));
      _hasMore = r['hasMore'] == true;
      _error = null;
    } on ApiException catch (e) {
      if (e.code == 401 && mounted) return handleSessionExpired(context);
      _error = e.message;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadInfo() async {
    try {
      final d = await CommApi.conversation(widget.conversationId);
      if (mounted) setState(() => _info = d);
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _members =>
      (_info?['members'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  void _call(bool video) => CallService.instance.startCall(context, _members, video: video);

  Future<void> _openInfo() async {
    final left = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => GroupInfoScreen(conversationId: widget.conversationId)));
    if (left == true && mounted) {
      Navigator.pop(context);
    } else {
      _loadInfo();
    }
  }

  Future<void> _loadOlder() async {
    if (!_hasMore || _loadingOlder || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final r = await CommApi.messages(widget.conversationId, beforeId: _messages.first['id'] as int?);
      _messages.insertAll(0, _list(r['messages']));
      _hasMore = r['hasMore'] == true;
    } catch (_) {}
    if (mounted) setState(() => _loadingOlder = false);
  }

  Future<void> _fetchNew() async {
    if (_loading) return;
    try {
      final fresh = await CommApi.newMessages(widget.conversationId, _lastId);
      final ids = _messages.map((m) => m['id']).toSet();
      final add = fresh.where((m) => !ids.contains(m['id'])).toList();
      if (add.isNotEmpty && mounted) setState(() => _messages.addAll(add));
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final queued = await CommApi.sendMessage(widget.conversationId, text);
      _input.clear();
      if (!queued) await _fetchNew();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  @override
  Widget build(BuildContext context) {
    final msgs = [..._messages, ..._pending].reversed.toList(); // newest at the bottom (reverse list)
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(
        title: '${_info?['type'] == 'group' && _info?['name'] != null ? _info!['name'] : widget.title}',
        subtitle: widget.subtitle ?? (_info?['type'] == 'group' ? '${_info?['memberCount'] ?? ''} members' : null),
        actions: [
          if (_members.length > 1) ...[
            IconButton(
              tooltip: 'Video call',
              onPressed: () => _call(true),
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Voice call',
              onPressed: () => _call(false),
              icon: const Icon(Icons.call_rounded, color: Colors.white),
            ),
          ],
          if (_info?['type'] == 'group')
            IconButton(
              tooltip: 'Group info',
              onPressed: _openInfo,
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null
                    ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load messages', message: _error)
                    : msgs.isEmpty
                        ? const EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No messages yet', message: 'Say hello 👋')
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                            itemCount: msgs.length + (_loadingOlder ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == msgs.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                );
                              }
                              final m = msgs[i];
                              final older = i + 1 < msgs.length ? msgs[i + 1] : null;
                              final showName = m['isMine'] != true && (older == null || older['senderId'] != m['senderId']);
                              return _Bubble(msg: m, showName: showName);
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              color: AppColors.bgCard,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      filled: true,
                      fillColor: AppColors.bg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool showName;
  const _Bubble({required this.msg, required this.showName});

  @override
  Widget build(BuildContext context) {
    final mine = msg['isMine'] == true;
    final type = '${msg['type'] ?? 'text'}';
    final text = '${msg['content'] ?? ''}';
    final reply = msg['replyTo'];
    final fileUrl = msg['fileUrl'] as String?;
    final isImage = type == 'image' && fileUrl != null && fileUrl.startsWith('https');

    final body = <Widget>[
      if (showName)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text('${msg['senderName'] ?? ''}',
              style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      if (reply is Map)
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
          ),
          child: Text('${reply['senderName'] ?? ''}: ${reply['content'] ?? reply['fileName'] ?? ''}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      if (isImage)
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(fileUrl, width: 220, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FileChip(name: '${msg['fileName'] ?? 'Image'}')),
        )
      else if (fileUrl != null)
        _FileChip(name: '${msg['fileName'] ?? 'Attachment'}', size: msg['fileSize']),
      if (text.isNotEmpty && !(fileUrl != null && text == msg['fileName']))
        Padding(
          padding: EdgeInsets.only(top: fileUrl != null ? 5 : 0),
          child: Text(text, style: TextStyle(color: AppColors.textPrimary, fontSize: 14.5, height: 1.3)),
        ),
      const SizedBox(height: 3),
      Align(
        alignment: Alignment.bottomRight,
        child: msg['pending'] == true
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Text('Waiting for internet', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
              ])
            : Text(CommApi.shortTime(msg['sentAt'] as String?),
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
      ),
    ];

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: EdgeInsets.only(top: showName ? 8 : 3, bottom: 1),
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.accent.withValues(alpha: 0.14) : AppColors.bgCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: body),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String name;
  final Object? size;
  const _FileChip({required this.name, this.size});

  @override
  Widget build(BuildContext context) {
    final kb = size is num ? (size as num) / 1024 : null;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.insert_drive_file_rounded, color: AppColors.accent, size: 22),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            kb == null ? name : '$name  •  ${kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.toStringAsFixed(0)} KB'}',
            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ]),
    );
  }
}
