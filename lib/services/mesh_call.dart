import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'comm_api.dart';

/// One other person in the call.
class CallPeer {
  final int userId;
  String name;
  /// ringing | connecting | connected | failed
  String state;
  bool cam = false;
  bool mic = true;
  bool sharing = false;
  RTCVideoRenderer? renderer;
  bool hasVideo = false;
  CallPeer(this.userId, this.name, this.state);

  bool get showVideo => hasVideo && (cam || sharing) && state == 'connected';
}

class _Conn {
  final RTCPeerConnection pc;
  bool restarted = false;
  bool tracksSet = false;
  Timer? failTimer;
  MediaStream? remote;
  Completer<void> gathered = Completer<void>();
  _Conn(this.pc);
}

/// Mesh WebRTC call — a Dart port of the web ERP's `useMeshCall`
/// (erp-frontend/src/components/communication/CallPopup.jsx), so phone and
/// browser speak exactly the same protocol:
///
///  • one RTCPeerConnection per other participant
///  • the LOWER user id always sends the offer
///  • non-trickle ICE (wait for gathering, then send the full SDP)
///  • signals: offer / answer / media / left / ended / rejoin, via
///    POST /comm/calls/<id>/signal and polled from /comm/calls/<id>/signals
///  • the participant list comes from GET /comm/calls/<id> every 2.5 s
class MeshCall extends ChangeNotifier {
  final int callId;
  final bool isVideo;
  final int myId;
  final Map<int, String> _names;

  MeshCall({required this.callId, required this.isVideo, required this.myId, Map<int, String>? names})
      : _names = {...?names};

  static const _stun = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  final peers = <int, CallPeer>{};
  final _conns = <int, _Conn>{};
  final _connecting = <int>{}; // offer being prepared (async)
  List<Map<String, dynamic>> _ice = [..._stun];

  MediaStream? _local;
  final localRenderer = RTCVideoRenderer();
  bool micOn = false;
  bool camOn = false;
  bool speakerOn = false;
  bool frontCamera = true;
  bool hasTurn = false;
  String stage = 'Starting…';
  String? mediaError;

  /// Set when the call is over; the screen closes itself.
  String? endedReason;
  DateTime? connectedAt;

  Timer? _sigTimer;
  Timer? _detailTimer;
  bool _busy = false;
  bool _disposed = false;
  bool _rendererReady = false;

  bool get hasLocalVideo => (_local?.getVideoTracks().isNotEmpty ?? false);
  Map<String, dynamic> get _media => {'cam': camOn, 'mic': micOn, 'sharing': false};

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Start / stop ────────────────────────────────────────────────────────

  Future<void> start() async {
    // Whatever happens with camera/mic, keep following the call on the server,
    // so the screen never gets stuck on "Ringing…".
    try {
      await _startMedia();
    } catch (e) {
      debugPrint('[call] media setup failed: $e');
      mediaError ??= e is MissingPluginException
          ? 'Calling is not available in this build. Close the app fully and reinstall / re-run it.'
          : 'Could not start microphone/camera: $e';
    }
    if (_disposed || endedReason != null) return;
    stage = 'Waiting for others…';
    _notify();
    await _pollDetail();
    if (_disposed) return;
    _sigTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _pollSignals());
    _detailTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _pollDetail());
  }

  Future<void> _startMedia() async {
    await localRenderer.initialize();
    _rendererReady = true;
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo ? {'facingMode': 'user'} : false,
      });
    } catch (e) {
      debugPrint('[call] getUserMedia failed: $e');
      if (isVideo) {
        try {
          _local = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
          mediaError = 'Camera unavailable — joined with audio only. Allow Camera for PRAX ERP in phone Settings → Apps.';
        } catch (_) {}
      }
      mediaError ??= 'Microphone blocked. Allow Microphone (and Camera) for PRAX ERP in phone Settings → Apps.';
    }
    if (_disposed) {
      await _stopLocal();
      return;
    }
    micOn = _local?.getAudioTracks().isNotEmpty ?? false;
    camOn = hasLocalVideo;
    localRenderer.srcObject = _local;
    speakerOn = isVideo;
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
    _notify();

    final turn = await CommApi.turnServers();
    hasTurn = turn.isNotEmpty;
    _ice = [..._stun, ...turn];
  }

  /// Hang up: leave (the server ends the call when nobody is left).
  Future<void> hangUp() async {
    if (endedReason != null) return;
    _end('Call ended');
    try {
      await CommApi.leaveCall(callId);
    } catch (_) {}
  }

  void _end(String reason) {
    if (endedReason != null) return;
    endedReason = reason;
    _teardown();
    _notify();
  }

  void _teardown() {
    _sigTimer?.cancel();
    _detailTimer?.cancel();
    for (final c in _conns.values) {
      c.failTimer?.cancel();
      c.pc.close();
      c.remote?.dispose();
    }
    _conns.clear();
    for (final p in peers.values) {
      p.renderer?.srcObject = null;
      p.renderer?.dispose();
      p.renderer = null;
    }
    _stopLocal();
  }

  Future<void> _stopLocal() async {
    for (final t in _local?.getTracks() ?? <MediaStreamTrack>[]) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await _local?.dispose();
    } catch (_) {}
    _local = null;
    try {
      if (_rendererReady) localRenderer.srcObject = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    if (endedReason == null) _teardown();
    _disposed = true;
    if (_rendererReady) localRenderer.dispose();
    try {
      Helper.setSpeakerphoneOn(false);
    } catch (_) {}
    super.dispose();
  }

  // ── Controls ────────────────────────────────────────────────────────────

  void toggleMic() {
    final tracks = _local?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    micOn = !micOn;
    for (final t in tracks) {
      t.enabled = micOn;
    }
    _broadcastMedia();
    _notify();
  }

  void toggleCam() {
    final tracks = _local?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    camOn = !camOn;
    for (final t in tracks) {
      t.enabled = camOn;
    }
    _broadcastMedia();
    _notify();
  }

  Future<void> switchCamera() async {
    final tracks = _local?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
      frontCamera = !frontCamera;
      _notify();
    } catch (_) {}
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
    _notify();
  }

  Future<void> invite(List<int> userIds) => CommApi.inviteToCall(callId, userIds);

  void _broadcastMedia() {
    _conns.forEach((uid, c) {
      if (c.pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        CommApi.sendSignal(callId, uid, 'media', _media).catch_();
      }
    });
  }

  // ── Peers ───────────────────────────────────────────────────────────────

  CallPeer _peer(int uid, String state) =>
      peers.putIfAbsent(uid, () => CallPeer(uid, _names[uid] ?? 'User $uid', state));

  Future<void> _dropPeer(int uid) async {
    final c = _conns.remove(uid);
    c?.failTimer?.cancel();
    await c?.pc.close();
    final p = peers.remove(uid);
    p?.renderer?.srcObject = null;
    await p?.renderer?.dispose();
    await c?.remote?.dispose();
    _notify();
  }

  Future<_Conn> _createConn(int uid, {required bool offerer}) async {
    final pc = await createPeerConnection({'iceServers': _ice, 'sdpSemantics': 'unified-plan'});
    final c = _Conn(pc);
    _conns[uid] = c;

    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete && !c.gathered.isCompleted) c.gathered.complete();
    };

    if (offerer) {
      // Always one audio + one video slot (like the web), so either side can turn video on
      final a = _local?.getAudioTracks();
      final v = _local?.getVideoTracks();
      final init = RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv);
      if (a != null && a.isNotEmpty) {
        await pc.addTransceiver(track: a.first, init: init);
      } else {
        await pc.addTransceiver(kind: RTCRtpMediaType.RTCRtpMediaTypeAudio, init: init);
      }
      if (v != null && v.isNotEmpty) {
        await pc.addTransceiver(track: v.first, init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv));
      } else {
        await pc.addTransceiver(
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv));
      }
      c.tracksSet = true;
    }

    pc.onTrack = (e) async {
      final p = _peer(uid, 'connecting');
      if (e.track.kind != 'video') return; // audio plays by itself
      try {
        MediaStream s;
        if (e.streams.isNotEmpty) {
          s = e.streams.first;
        } else {
          c.remote ??= await createLocalMediaStream('remote_${callId}_$uid');
          await c.remote!.addTrack(e.track);
          s = c.remote!;
        }
        if (p.renderer == null) {
          final r = RTCVideoRenderer();
          await r.initialize();
          p.renderer = r;
        }
        p.renderer!.srcObject = s;
        p.hasVideo = true;
        _notify();
      } catch (_) {}
    };

    pc.onConnectionState = (st) {
      if (endedReason != null) return;
      final p = _peer(uid, 'connecting');
      if (st == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        c.failTimer?.cancel();
        c.failTimer = null;
        p.state = 'connected';
        connectedAt ??= DateTime.now();
        stage = 'Connected';
        CommApi.sendSignal(callId, uid, 'media', _media).catch_();
        _notify();
      } else if (st == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        p.state = 'connecting';
        stage = 'Connection failed — retrying…';
        if (myId < uid && !c.restarted) {
          c.restarted = true;
          _offerTo(uid, iceRestart: true).catch_();
        }
        c.failTimer ??= Timer(const Duration(seconds: 15), () {
          c.failTimer = null;
          if (endedReason == null && c.pc.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            p.state = 'failed';
            stage = hasTurn ? 'Couldn\'t connect — check both networks.' : 'Couldn\'t connect — a TURN relay is needed.';
            _notify();
          }
        });
        _notify();
      }
    };

    _peer(uid, 'connecting').state = 'connecting';
    _notify();
    return c;
  }

  Future<void> _waitIce(_Conn c) async {
    if (c.pc.iceGatheringState == RTCIceGatheringState.RTCIceGatheringStateComplete) return;
    await c.gathered.future.timeout(const Duration(seconds: 4), onTimeout: () {});
  }

  Future<void> _offerTo(int uid, {bool iceRestart = false}) async {
    final c = _conns[uid] ?? await _createConn(uid, offerer: true);
    if (iceRestart) c.gathered = Completer<void>();
    final offer = await c.pc.createOffer(iceRestart ? {'iceRestart': true} : {});
    await c.pc.setLocalDescription(offer);
    await _waitIce(c);
    if (endedReason != null) return;
    final d = await c.pc.getLocalDescription();
    await CommApi.sendSignal(callId, uid, 'offer', {'sdp': d?.toMap()});
    stage = 'Calling…';
    _notify();
  }

  // ── Signals ─────────────────────────────────────────────────────────────

  @visibleForTesting
  Future<void> handleSignal(Map<String, dynamic> s) async {
    final uid = (s['senderId'] as num).toInt();
    final payload = s['payload'] is Map ? Map<String, dynamic>.from(s['payload'] as Map) : <String, dynamic>{};
    switch (s['signalType']) {
      case 'ended':
        _end('Call ended');
        return;
      case 'rejoin':
        final c = _conns.remove(uid);
        c?.failTimer?.cancel();
        await c?.pc.close();
        _peer(uid, 'connecting')
          ..state = 'connecting'
          ..hasVideo = false;
        _notify();
        return;
      case 'left':
        await _dropPeer(uid);
        return;
      case 'media':
        _peer(uid, 'connecting')
          ..cam = payload['cam'] == true
          ..mic = payload['mic'] == true
          ..sharing = payload['sharing'] == true;
        _notify();
        return;
      case 'offer':
        final c = _conns[uid] ?? await _createConn(uid, offerer: false);
        if (c.pc.signalingState != null && c.pc.signalingState != RTCSignalingState.RTCSignalingStateStable) return;
        final sdp = payload['sdp'];
        if (sdp is! Map) return;
        await c.pc.setRemoteDescription(RTCSessionDescription('${sdp['sdp']}', '${sdp['type']}'));
        if (!c.tracksSet) {
          // Send our media on the slots the offer created
          final ts = await c.pc.getTransceivers();
          for (final t in ts) {
            final kind = t.receiver.track?.kind;
            final track = kind == 'audio'
                ? _local?.getAudioTracks().firstOrNull
                : kind == 'video'
                    ? _local?.getVideoTracks().firstOrNull
                    : null;
            await t.setDirection(TransceiverDirection.SendRecv);
            if (track != null) await t.sender.replaceTrack(track);
          }
          c.tracksSet = true;
        }
        final answer = await c.pc.createAnswer({});
        await c.pc.setLocalDescription(answer);
        await _waitIce(c);
        if (endedReason != null) return;
        final d = await c.pc.getLocalDescription();
        await CommApi.sendSignal(callId, uid, 'answer', {'sdp': d?.toMap()});
        stage = 'Connecting…';
        _notify();
        return;
      case 'answer':
        final c = _conns[uid];
        final sdp = payload['sdp'];
        if (c != null && sdp is Map && c.pc.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          await c.pc.setRemoteDescription(RTCSessionDescription('${sdp['sdp']}', '${sdp['type']}'));
          stage = 'Connecting…';
          _notify();
        }
        return;
    }
  }

  Future<void> _pollSignals() async {
    if (_busy || endedReason != null) return;
    _busy = true;
    try {
      final sigs = await CommApi.pollSignals(callId);
      for (final s in sigs) {
        if (endedReason != null) break;
        try {
          await handleSignal(s);
        } catch (e) {
          debugPrint('[call] signal ${s['signalType']} failed: $e');
        }
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  Future<void> _pollDetail() async {
    if (endedReason != null) return;
    try {
      final d = await CommApi.callDetail(callId);
      if (d != null) await sync(d);
    } catch (_) {}
  }

  /// Apply the server's participant list (exposed for tests).
  @visibleForTesting
  Future<void> sync(Map<String, dynamic> detail) async {
    if (endedReason != null) return;
    final status = '${detail['status']}';
    if (status == 'ended' || status == 'missed') {
      _end(status == 'missed' ? 'No answer' : 'Call ended');
      return;
    }
    for (final p in (detail['participants'] as List? ?? []).whereType<Map>()) {
      final uid = (p['userId'] as num?)?.toInt();
      if (uid == null || uid == myId) continue;
      if (p['userName'] != null) _names[uid] = '${p['userName']}';
      final state = '${p['state']}';
      if (state == 'in_call') {
        // They answered: never keep showing "Ringing…" for them
        final peer = _peer(uid, 'connecting');
        if (peer.state == 'ringing') peer.state = 'connecting';
        if (_conns.containsKey(uid) || _connecting.contains(uid)) continue;
        if (myId < uid) {
          _connecting.add(uid);
          try {
            await _createConn(uid, offerer: true);
            _offerTo(uid).catch_();
          } catch (e) {
            _conns.remove(uid); // retry on the next poll
            stage = 'Could not connect: $e';
          } finally {
            _connecting.remove(uid);
          }
        }
      } else if (state == 'away') {
        // reloading their page — keep the tile, they'll send "rejoin"
      } else if (state == 'ringing') {
        _peer(uid, 'ringing');
      } else if (peers.containsKey(uid)) {
        await _dropPeer(uid);
      }
      peers[uid]?.name = _names[uid] ?? peers[uid]!.name;
    }
    _notify();
  }
}

extension _Quiet on Future<void> {
  void catch_() => catchError((_) {});
}
