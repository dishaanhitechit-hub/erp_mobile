import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_service.dart';
import '../../services/dpr_queue.dart';
import '../../services/photo_stamp.dart';

/// In-app camera for the Daily Progress Report. Every photo is stamped with
/// India time, GPS (and whether it is on site), project, location on site and
/// the user — burned into the image and sent as data. No gallery picking.
class SiteCameraScreen extends StatefulWidget {
  final String projectCode;
  final String projectName;
  final double? siteLat;
  final double? siteLng;
  final int siteRadiusM;
  final List<String> locations;

  const SiteCameraScreen({
    super.key,
    required this.projectCode,
    required this.projectName,
    this.siteLat,
    this.siteLng,
    this.siteRadiusM = 500,
    this.locations = const [],
  });

  @override
  State<SiteCameraScreen> createState() => _SiteCameraScreenState();
}

class _SiteCameraScreenState extends State<SiteCameraScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  String? _camError;
  Position? _pos;
  String? _gpsError;
  StreamSubscription<Position>? _gpsSub;
  Timer? _clock;
  DateTime _now = nowIst();
  bool _busy = false;
  int _taken = 0;
  Uint8List? _lastThumb;
  String _subLocation = '';
  String _caption = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
    _startGps();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = nowIst()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _cam = null;
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'No camera found');
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      if (!mounted) return c.dispose();
      setState(() {
        _cam = c;
        _camError = null;
      });
    } on CameraException catch (e) {
      setState(() => _camError = e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'Camera permission is off. Allow it in Settings › Apps › PRAX ERP › Permissions.'
          : 'Camera could not start (${e.description ?? e.code}).');
    }
  }

  Future<void> _startGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _gpsError = 'Turn on Location to stamp photos with where they were taken.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _gpsError = 'Location permission is off — photos will be marked "location not available".');
        return;
      }
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
      ).listen((p) {
        if (mounted) {
          setState(() {
            _pos = p;
            _gpsError = null;
          });
        }
      }, onError: (_) {
        if (mounted) setState(() => _gpsError = 'Waiting for GPS…');
      });
      final first = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)));
      if (mounted) setState(() => _pos ??= first);
    } catch (_) {
      if (mounted && _pos == null) setState(() => _gpsError = 'Waiting for GPS…');
    }
  }

  int? get _distance {
    final p = _pos;
    if (p == null || widget.siteLat == null || widget.siteLng == null) return null;
    return distanceMeters(p.latitude, p.longitude, widget.siteLat!, widget.siteLng!).round();
  }

  bool? get _onSite => _distance == null ? null : _distance! <= widget.siteRadiusM;

  StampInfo _stamp(DateTime at) => StampInfo(
        takenAt: at,
        latitude: _pos?.latitude,
        longitude: _pos?.longitude,
        accuracyM: _pos?.accuracy,
        onSite: _onSite,
        distanceM: _distance,
        mocked: _pos?.isMocked ?? false,
        project: '${widget.projectName} (${widget.projectCode})',
        subLocation: _subLocation,
        user: ApiService.instance.userName,
      );

  Future<void> _shoot() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final at = nowIst();
      final shot = await c.takePicture();
      final raw = await shot.readAsBytes();
      final info = _stamp(at);
      final stamped = await compute(stampPhoto, StampJob(raw, info.lines()));
      await DprQueue.instance.add(
        stamped,
        projectCode: widget.projectCode,
        reportDate: dayOf(at),
        meta: {
          'source': 'camera',
          'takenAt': istIso(at),
          if (_pos != null) ...{
            'latitude': _pos!.latitude,
            'longitude': _pos!.longitude,
            'accuracy': _pos!.accuracy,
            'isMocked': _pos!.isMocked,
          },
          if (_subLocation.trim().isNotEmpty) 'subLocation': _subLocation.trim(),
          if (_caption.trim().isNotEmpty) 'caption': _caption.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _taken++;
        _lastThumb = stamped;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo not saved: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDetails() async {
    final loc = TextEditingController(text: _subLocation);
    final cap = TextEditingController(text: _caption);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('For the next photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _subLocation),
            optionsBuilder: (v) => widget.locations.where((l) => l.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => loc.text = v,
            fieldViewBuilder: (_, ctrl, focus, __) {
              ctrl.addListener(() => loc.text = ctrl.text);
              return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: const InputDecoration(labelText: 'Location on site', hintText: 'e.g. Block C, 2nd floor'));
            },
          ),
          const SizedBox(height: 8),
          TextField(controller: cap, maxLength: 200, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Done'))),
        ]),
      ),
    );
    if (ok == true) {
      setState(() {
        _subLocation = loc.text;
        _caption = cap.text;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsSub?.cancel();
    _clock?.cancel();
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _stamp(_now).lines();
    final gpsColor = _pos == null
        ? Colors.white70
        : (_pos!.isMocked
            ? Colors.redAccent
            : _onSite == false
                ? Colors.orangeAccent
                : Colors.lightGreenAccent);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: _cam != null && _cam!.value.isInitialized
                ? Center(child: CameraPreview(_cam!))
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          Text(_camError ?? 'Starting camera…', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
          ),
          // Top bar
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context, _taken)),
                Expanded(
                  child: GestureDetector(
                    onTap: _editDetails,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_subLocation.isEmpty ? 'Tap to set location on site' : _subLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      if (_caption.isNotEmpty)
                        Text(_caption,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_location_alt_rounded, color: Colors.white), onPressed: _editDetails),
              ]),
            ),
          ),
          // Live stamp preview + controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity,
                color: Colors.black54,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lines[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(_gpsError ?? lines[1], style: TextStyle(color: _gpsError != null ? Colors.orangeAccent : gpsColor, fontSize: 12)),
                  Text(lines[2], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _lastThumb == null
                            ? null
                            : Stack(children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(_lastThumb!, width: 56, height: 56, fit: BoxFit.cover, gaplessPlayback: true)),
                                Positioned(
                                    right: 0,
                                    top: 0,
                                    child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.amber,
                                        child: Text('$_taken',
                                            style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w700)))),
                              ]),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _busy ? null : _shoot,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                      padding: const EdgeInsets.all(5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _busy ? Colors.white38 : Colors.white),
                        child: _busy ? const Center(child: CircularProgressIndicator(strokeWidth: 3)) : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, _taken),
                        child: const Text('Done', maxLines: 1, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
