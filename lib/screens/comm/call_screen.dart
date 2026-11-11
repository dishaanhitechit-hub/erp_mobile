import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/api_service.dart';
import '../../services/call_service.dart';
import '../../services/comm_api.dart';
import '../../services/mesh_call.dart';
import '../../theme/app_theme.dart';
import 'people_picker.dart';

const _bgTop = Color(0xFF3B2416);
const _bgBottom = Color(0xFF1C110A);

BoxDecoration get _callBg => const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom]),
    );

// ── Incoming (ringing) ──────────────────────────────────────────────────────

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> call;
  const IncomingCallScreen({super.key, required this.call});
  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _poll;
  Timer? _buzz;
  bool _busy = false;

  int get _id => widget.call['callId'] as int;
  bool get _video => widget.call['callType'] == 'video';

  @override
  void initState() {
    super.initState();
    CallLockScreen.enter();
    _buzz = Timer.periodic(const Duration(milliseconds: 1200), (_) => HapticFeedback.heavyImpact());
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _checkStillRinging());
    CallService.ring(widget.call); // ringtone (cancelled on accept / decline / timeout)
  }

  @override
  void dispose() {
    _poll?.cancel();
    _buzz?.cancel();
    CallService.cancelRingNotification(_id);
    CallLockScreen.leave();
    super.dispose();
  }

  Future<void> _checkStillRinging() async {
    try {
      final d = await CommApi.callDetail(_id);
      final me = ApiService.instance.userId;
      final mine = (d?['participants'] as List? ?? []).whereType<Map>().where((p) => p['userId'] == me).firstOrNull;
      final over = d == null || !['ringing', 'active'].contains(d['status']) || (mine != null && mine['state'] != 'ringing');
      if (over && mounted && !_busy) Navigator.pop(context);
    } catch (_) {}
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await CommApi.leaveCall(_id);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    _poll?.cancel();
    _buzz?.cancel();
    try {
      await CommApi.answerCall(_id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        Navigator.pop(context);
      }
      return;
    }
    if (!mounted) return;
    final names = {
      for (final p in (widget.call['participants'] as List? ?? []).whereType<Map>())
        (p['userId'] as num).toInt(): '${p['userName'] ?? ''}'
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CallScreen(callId: _id, video: _video, names: names)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final from = '${widget.call['initiatorName'] ?? 'Someone'}';
    final others = (widget.call['participants'] as List? ?? []).length - 2;
    return Scaffold(
      body: Container(
        decoration: _callBg,
        child: SafeArea(
          child: Column(children: [
            const Spacer(),
            _BigAvatar(name: from, pulse: true),
            const SizedBox(height: 22),
            Text(from, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '${_video ? 'Video' : 'Voice'} call${others > 0 ? ' • with $others other${others > 1 ? 's' : ''}' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const Spacer(flex: 2),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _RoundAction(icon: Icons.call_end_rounded, color: Colors.red, label: 'Decline', onTap: _busy ? null : _decline),
              _RoundAction(
                icon: _video ? Icons.videocam_rounded : Icons.call_rounded,
                color: Colors.green,
                label: 'Accept',
                onTap: _busy ? null : _accept,
              ),
            ]),
            const SizedBox(height: 50),
          ]),
        ),
      ),
    );
  }
}

// ── In call ──────────────────────────────────────────────────────────────────

class CallScreen extends StatefulWidget {
  final int callId;
  final bool video;
  final bool outgoing;
  final Map<int, String> names;
  const CallScreen({super.key, required this.callId, required this.video, this.names = const {}, this.outgoing = false});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final MeshCall _call;
  Timer? _tick;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    CallLockScreen.enter();
    _call = MeshCall(
      callId: widget.callId,
      isVideo: widget.video,
      myId: ApiService.instance.userId ?? 0,
      names: widget.names,
    )..addListener(_onChange);
    for (final e in widget.names.entries) {
      if (e.key != ApiService.instance.userId) _call.peers[e.key] = CallPeer(e.key, e.value, widget.outgoing ? 'ringing' : 'connecting');
    }
    _call.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onChange() {
    if (!mounted) return;
    if (_call.endedReason != null && !_closing) {
      _closing = true;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _call.removeListener(_onChange);
    if (_call.endedReason == null) _call.hangUp();
    _call.dispose();
    CallLockScreen.leave();
    super.dispose();
  }

  Future<void> _hangUp() async {
    await _call.hangUp();
  }

  Future<void> _addPeople() async {
    final picked = await pickPeople(context, title: 'Add to call', exclude: {
      ApiService.instance.userId ?? 0,
      ..._call.peers.keys,
    });
    if (picked == null || picked.isEmpty) return;
    try {
      await _call.invite(picked.map((p) => (p['userId'] as num).toInt()).toList());
      for (final p in picked) {
        final id = (p['userId'] as num).toInt();
        _call.peers.putIfAbsent(id, () => CallPeer(id, '${p['userName']}', 'ringing'));
      }
      setState(() {});
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String get _status {
    if (_call.endedReason != null) return _call.endedReason!;
    final peers = _call.peers.values.toList();
    final at = _call.connectedAt;
    if (at != null && peers.any((p) => p.state == 'connected')) {
      final s = DateTime.now().difference(at).inSeconds;
      final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
      return '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    if (peers.isNotEmpty && peers.every((p) => p.state == 'ringing')) return 'Ringing…';
    if (peers.isNotEmpty && peers.every((p) => p.state == 'failed')) return _call.stage;
    return _call.stage == 'Waiting for others…' || _call.stage == 'Starting…' ? 'Connecting…' : _call.stage;
  }

  String get _title {
    final names = _call.peers.values.map((p) => p.name).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return widget.video ? 'Video call' : 'Voice call';
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  @override
  Widget build(BuildContext context) {
    final peers = _call.peers.values.toList();
    final anyVideo = peers.any((p) => p.showVideo) || (_call.hasLocalVideo && _call.camOn);
    return PopScope(
      canPop: _call.endedReason != null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Leave call?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Stay')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (leave == true) _hangUp();
      },
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Container(
          decoration: _callBg,
          child: SafeArea(
            child: Column(children: [
              const SizedBox(height: 14),
              Text(_title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              if (_call.mediaError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(_call.mediaError!,
                      textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFC27A), fontSize: 12.5)),
                ),
              const SizedBox(height: 12),
              Expanded(child: anyVideo ? _videoLayout(peers) : _voiceLayout(peers)),
              _controls(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _voiceLayout(List<CallPeer> peers) {
    if (peers.length <= 1) {
      final p = peers.firstOrNull;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _BigAvatar(name: p?.name ?? '?', pulse: p == null || p.state != 'connected'),
        if (p != null && !p.mic && p.state == 'connected')
          const Padding(padding: EdgeInsets.only(top: 14), child: Icon(Icons.mic_off_rounded, color: Colors.white54)),
      ]);
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [for (final p in peers) _PeerTile(peer: p)],
    );
  }

  Widget _videoLayout(List<CallPeer> peers) {
    final local = _call.hasLocalVideo && _call.camOn
        ? RTCVideoView(_call.localRenderer,
            mirror: _call.frontCamera, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
        : null;
    if (peers.length <= 1) {
      final p = peers.firstOrNull;
      return Stack(children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: p != null ? _PeerTile(peer: p, big: true) : const SizedBox(),
            ),
          ),
        ),
        if (local != null)
          Positioned(
            right: 18,
            bottom: 12,
            width: 110,
            height: 160,
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: local),
          ),
      ]);
    }
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.75,
      children: [
        for (final p in peers) ClipRRect(borderRadius: BorderRadius.circular(14), child: _PeerTile(peer: p)),
        if (local != null) ClipRRect(borderRadius: BorderRadius.circular(14), child: local),
      ],
    );
  }

  Widget _controls() {
    final ended = _call.endedReason != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _CtrlButton(
            icon: _call.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: _call.micOn ? 'Mute' : 'Unmute',
            active: !_call.micOn,
            onTap: ended ? null : _call.toggleMic,
          ),
          _CtrlButton(
            icon: _call.speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
            label: _call.speakerOn ? 'Speaker' : 'Earpiece',
            active: _call.speakerOn,
            onTap: ended ? null : _call.toggleSpeaker,
          ),
          if (_call.hasLocalVideo)
            _CtrlButton(
              icon: _call.camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
              label: _call.camOn ? 'Camera' : 'Camera off',
              active: !_call.camOn,
              onTap: ended ? null : _call.toggleCam,
            ),
          if (_call.hasLocalVideo && _call.camOn)
            _CtrlButton(icon: Icons.cameraswitch_rounded, label: 'Flip', onTap: ended ? null : _call.switchCamera),
          _CtrlButton(icon: Icons.person_add_alt_1_rounded, label: 'Add', onTap: ended ? null : _addPeople),
        ]),
        const SizedBox(height: 22),
        _RoundAction(icon: Icons.call_end_rounded, color: Colors.red, onTap: ended ? null : _hangUp),
      ]),
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _PeerTile extends StatelessWidget {
  final CallPeer peer;
  final bool big;
  const _PeerTile({required this.peer, this.big = false});

  @override
  Widget build(BuildContext context) {
    final label = switch (peer.state) {
      'ringing' => 'Ringing…',
      'connecting' => 'Connecting…',
      'failed' => 'Couldn\'t connect',
      _ => '',
    };
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: Stack(children: [
        if (peer.showVideo && peer.renderer != null)
          Positioned.fill(
            child: RTCVideoView(peer.renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          )
        else
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _BigAvatar(name: peer.name, size: big ? 120 : 64, pulse: peer.state != 'connected'),
              const SizedBox(height: 8),
              if (!big)
                Text(peer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              if (label.isNotEmpty) Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
        if (peer.showVideo || !big)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!peer.mic && peer.state == 'connected')
                  const Padding(
                      padding: EdgeInsets.only(right: 4), child: Icon(Icons.mic_off_rounded, size: 13, color: Colors.white)),
                Text(peer.showVideo ? peer.name : (peer.state == 'connected' ? 'Connected' : label),
                    style: const TextStyle(color: Colors.white, fontSize: 11.5)),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _BigAvatar extends StatefulWidget {
  final String name;
  final double size;
  final bool pulse;
  const _BigAvatar({required this.name, this.size = 120, this.pulse = false});
  @override
  State<_BigAvatar> createState() => _BigAvatarState();
}

class _BigAvatarState extends State<_BigAvatar> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _anim.repeat();
  }

  @override
  void didUpdateWidget(covariant _BigAvatar old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_anim.isAnimating) _anim.repeat();
    if (!widget.pulse) _anim.stop();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    return SizedBox(
      width: s * 1.5,
      height: s * 1.5,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Stack(alignment: Alignment.center, children: [
          if (widget.pulse)
            Container(
              width: s * (1 + 0.45 * _anim.value),
              height: s * (1 + 0.45 * _anim.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.35 * (1 - _anim.value)),
              ),
            ),
          child!,
        ]),
        child: Container(
          width: s,
          height: s,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFFC08552), Color(0xFF8C5A3C)]),
          ),
          child: Text(initial, style: TextStyle(color: Colors.white, fontSize: s * 0.42, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _CtrlButton({required this.icon, required this.label, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: active ? _bgTop : Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
      ]);
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;
  const _RoundAction({required this.icon, required this.color, this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: onTap == null ? color.withValues(alpha: 0.4) : color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(20), child: Icon(icon, color: Colors.white, size: 32)),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        ],
      ]);
}
