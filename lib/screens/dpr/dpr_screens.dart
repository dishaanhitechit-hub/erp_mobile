import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../config/module_registry.dart';
import '../../services/api_service.dart';
import '../../services/dpr_queue.dart';
import '../../services/offline_store.dart';
import '../../services/photo_stamp.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/pp_widgets.dart';
import '../common/print_view_screen.dart';
import 'site_camera_screen.dart';

const _base = '/project-mgmt/dpr';

String _longDay(String day) {
  final d = DateTime.tryParse(day);
  if (d == null) return day;
  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${w[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
}

Color _sevColor(String? s) => s == 'high' ? Colors.red.shade700 : s == 'medium' ? Colors.orange.shade800 : AppColors.textSecondary;

void _snack(BuildContext context, String msg) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

/// Daily Progress Report — one row per site day.
class DprScreen extends StatefulWidget {
  final ErpModule module;
  const DprScreen({super.key, required this.module});

  @override
  State<DprScreen> createState() => _DprScreenState();
}

class _DprScreenState extends State<DprScreen> {
  List<Map<String, dynamic>> _days = [];
  bool _loading = true;
  String? _error;
  DateTime? _savedAt;

  @override
  void initState() {
    super.initState();
    _load();
    DprQueue.instance.uploaded.addListener(_load);
    NetworkStatus.instance.backOnline.addListener(_load);
  }

  @override
  void dispose() {
    DprQueue.instance.uploaded.removeListener(_load);
    NetworkStatus.instance.backOnline.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      DateTime? saved;
      final data = await ApiService.instance.get('$_base/list', onCached: (t) => saved = t);
      if (!mounted) return;
      setState(() {
        _days = data is List ? data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
        _savedAt = saved;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _openDay(String day) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DprDayScreen(module: widget.module, day: day)),
      ).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final today = dayOf(nowIst());
    final hasToday = _days.any((d) => d['reportDate'] == today);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(title: 'Daily Progress', subtitle: ApiService.instance.currentProject?['projectName']?.toString()),
      floatingActionButton: widget.module.canEdit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              onPressed: () => _openDay(today),
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Today'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListenableBuilder(
          listenable: DprQueue.instance,
          builder: (context, _) {
            final waiting = DprQueue.instance.items.where((q) => q.projectCode == ApiService.instance.projectCode).length;
            if (_loading) return ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]);
            if (_error != null && _days.isEmpty) {
              return ListView(children: [EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load', message: _error)]);
            }
            return ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 96),
              children: [
                if (_savedAt != null) SavedCopyNote(savedAt: _savedAt!),
                if (waiting > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Row(children: [
                      Icon(Icons.schedule_rounded, size: 16, color: AppColors.accent4),
                      const SizedBox(width: 6),
                      Text('$waiting photo(s) waiting to upload', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    ]),
                  ),
                if (!hasToday && widget.module.canEdit)
                  _DayTile(day: {'reportDate': today, 'workflowStatus': 'No report', 'photoCount': 0}, onTap: () => _openDay(today)),
                if (_days.isEmpty && !widget.module.canEdit)
                  const EmptyState(icon: Icons.photo_library_outlined, title: 'No reports yet'),
                for (final d in _days) _DayTile(day: d, onTap: () => _openDay('${d['reportDate']}')),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final Map<String, dynamic> day;
  final VoidCallback onTap;
  const _DayTile({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = '${day['workflowStatus'] ?? ''}'.replaceAll('_', ' ');
    final thumb = day['thumbUrl'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: GlassCard(
        onTap: onTap,
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56, height: 56,
              child: thumb != null
                  ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _thumbIcon())
                  : _thumbIcon(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_longDay('${day['reportDate']}'), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [
                  if (day['dprNo'] != null) day['dprNo'],
                  '${day['photoCount'] ?? 0} photo(s)',
                  if (day['manpowerTotal'] != null) '${day['manpowerTotal']} workers',
                ].join(' · '),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              if ((day['summary'] ?? '').toString().isNotEmpty)
                Text('${day['summary']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          StatusBadge(status.isEmpty ? '—' : status),
        ]),
      ),
    );
  }

  Widget _thumbIcon() => Container(color: AppColors.inputFill, child: Icon(Icons.photo_camera_outlined, color: AppColors.textMuted));
}

/// One site day: photos (with the ones still uploading), the AI report, actions.
class DprDayScreen extends StatefulWidget {
  final ErpModule module;
  final String day;
  const DprDayScreen({super.key, required this.module, required this.day});

  @override
  State<DprDayScreen> createState() => _DprDayScreenState();
}

class _DprDayScreenState extends State<DprDayScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  DateTime? _savedAt;
  bool _busy = false;
  bool _pendingForMe = false;
  List<String> _locations = [];
  Timer? _poll;

  String get _project => ApiService.instance.projectCode ?? '';
  Map<String, dynamic>? get _report => _data?['report'] is Map ? Map<String, dynamic>.from(_data!['report']) : null;
  List<Map<String, dynamic>> get _photos =>
      (_data?['photos'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  bool get _canEdit => widget.module.canEdit && (_data?['canEdit'] == true);
  bool get _isToday => widget.day == dayOf(nowIst());
  bool get _editable => _report == null || ['Draft', 'Reback', 'Rejected'].contains(_report!['workflowStatus']);

  @override
  void initState() {
    super.initState();
    _load();
    _loadLocations();
    DprQueue.instance.uploaded.addListener(_load);
    NetworkStatus.instance.backOnline.addListener(_load);
  }

  @override
  void dispose() {
    _poll?.cancel();
    DprQueue.instance.uploaded.removeListener(_load);
    NetworkStatus.instance.backOnline.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      DateTime? saved;
      final data = await ApiService.instance.get('$_base/day', params: {'date': widget.day}, onCached: (t) => saved = t);
      if (!mounted) return;
      setState(() {
        _data = data is Map ? Map<String, dynamic>.from(data) : null;
        _savedAt = saved;
        _error = null;
      });
      final reading = _photos.any((p) => p['aiStatus'] == 'pending' || p['aiStatus'] == 'working');
      _poll?.cancel();
      if (reading && saved == null) _poll = Timer(const Duration(seconds: 6), _load);
      _checkApproval();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _checkApproval() async {
    final r = _report;
    if (r == null || !'${r['workflowStatus']}'.startsWith('Pending') || !widget.module.canApprove) {
      if (_pendingForMe && mounted) setState(() => _pendingForMe = false);
      return;
    }
    try {
      final s = await ApiService.instance.get('$_base/my-approval-status/${r['id']}', projectScoped: false);
      if (mounted) setState(() => _pendingForMe = s is Map && s['isPendingForMe'] == true);
    } catch (_) {}
  }

  Future<void> _loadLocations() async {
    try {
      final rows = await ApiService.instance.get('/setting/project-location/$_project', projectScoped: false);
      if (rows is List && mounted) {
        setState(() => _locations = rows.whereType<Map>().map((l) => '${l['locationName'] ?? ''}').where((s) => s.isNotEmpty).toSet().toList());
      }
    } catch (_) {}
  }

  Future<void> _openCamera() async {
    final site = _data?['site'] as Map? ?? {};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteCameraScreen(
          projectCode: _project,
          projectName: '${_data?['projectName'] ?? ApiService.instance.currentProject?['projectName'] ?? _project}',
          siteLat: (site['latitude'] as num?)?.toDouble(),
          siteLng: (site['longitude'] as num?)?.toDouble(),
          siteRadiusM: (site['radiusM'] as num?)?.toInt() ?? 500,
          locations: _locations,
        ),
      ),
    );
    unawaited(DprQueue.instance.flush());
    _load();
  }

  Future<void> _act(String label, Future<dynamic> Function() call, {String? confirm}) async {
    if (confirm != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(confirm),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(label)),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await call();
      if (mounted) _snack(context, '$label — done');
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendBack(bool reject) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(reject ? 'Reject report' : 'Send back for correction'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Comments (required)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim().isNotEmpty), child: Text(reject ? 'Reject' : 'Send back')),
        ],
      ),
    );
    if (ok != true) return;
    await _act(reject ? 'Rejected' : 'Sent back',
        () => ApiService.instance.post('$_base/${reject ? 'reject' : 'reback'}/${_report!['id']}', body: {'comments': ctrl.text.trim()}));
  }

  void _openPhoto(Map<String, dynamic> p) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.bgCard,
        builder: (_) => _PhotoSheet(photo: p),
      );

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PPAppBar(
        title: _longDay(widget.day),
        subtitle: r == null ? 'Daily Progress Report' : '${r['dprNo']} · ${'${r['workflowStatus']}'.replaceAll('_', ' ')}',
        actions: [
          if (r != null && r['uuid'] != null)
            IconButton(
              tooltip: 'View PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              onPressed: () => openDocumentView(context, widget.module, r, title: 'DPR ${r['dprNo']}'),
            ),
        ],
      ),
      floatingActionButton: _canEdit && _isToday && _editable
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              onPressed: _openCamera,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Take photos'),
            )
          : null,
      body: _data == null
          ? Center(child: _error != null ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListenableBuilder(
                listenable: DprQueue.instance,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.only(top: 12, bottom: 100),
                  children: [
                    if (_savedAt != null) SavedCopyNote(savedAt: _savedAt!),
                    _photosCard(),
                    _reportCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _photosCard() {
    final queued = DprQueue.instance.forDay(_project, widget.day);
    final photos = _photos;
    final site = _data?['site'] as Map? ?? {};
    return SectionCard(
      title: 'Site photos (${photos.length + queued.length})',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (site['latitude'] == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Site location not set for this project — photos can\'t be checked as on/off site.',
                style: TextStyle(color: AppColors.accent4, fontSize: 12)),
          ),
        if (photos.isEmpty && queued.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _isToday && _canEdit ? 'No photos yet. Tap "Take photos" — each photo is stamped with time and GPS.' : 'No photos for this day.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final q in queued)
              Stack(fit: StackFit.expand, children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(q.filePath), fit: BoxFit.cover)),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.vertical(bottom: Radius.circular(8))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(DprQueue.instance.flushing ? Icons.cloud_upload_rounded : Icons.schedule_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(DprQueue.instance.flushing ? 'Uploading' : 'Waiting', style: const TextStyle(color: Colors.white, fontSize: 10.5)),
                    ]),
                  ),
                ),
              ]),
            for (final p in photos) _PhotoThumb(photo: p, onTap: () => _openPhoto(p)),
          ],
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _reportCard() {
    final r = _report;
    final waiting = _photos.where((p) => p['aiStatus'] == 'pending' || p['aiStatus'] == 'working').length;
    final txt = TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.35);
    final muted = TextStyle(color: AppColors.textSecondary, fontSize: 12.5);
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(t.toUpperCase(), style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        );

    final buttons = <Widget>[
      if (_canEdit && _editable && (_photos.isNotEmpty || r != null))
        OutlinedButton.icon(
          onPressed: _busy || waiting > 0 || _savedAt != null
              ? null
              : () => _act(r == null ? 'Report written' : 'Report rewritten',
                  () => ApiService.instance.post('$_base/generate', body: {'projectCode': _project, 'date': widget.day}),
                  confirm: r?['edited'] == true ? 'Write the report again with AI? Edits made on the web will be replaced.' : null),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(r == null ? 'Write report with AI' : 'Rewrite with AI'),
        ),
      if (_canEdit && r != null && ['Draft', 'Reback'].contains(r['workflowStatus']))
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
          onPressed: _busy || _savedAt != null
              ? null
              : () => _act('Submitted', () => ApiService.instance.post('$_base/submit/${r['id']}'),
                  confirm: 'Submit this report for approval? It can\'t be changed after that.'),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit'),
        ),
      if (_pendingForMe && r != null) ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
          onPressed: _busy ? null : () => _act('Approved', () => ApiService.instance.post('$_base/approve/${r['id']}', body: {})),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Approve'),
        ),
        OutlinedButton(onPressed: _busy ? null : () => _sendBack(false), child: const Text('Send back')),
        TextButton(onPressed: _busy ? null : () => _sendBack(true), child: Text('Reject', style: TextStyle(color: Colors.red.shade700))),
      ],
    ];

    if (r == null) {
      return SectionCard(
        title: 'Report',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            waiting > 0
                ? 'AI is reading $waiting photo(s)…'
                : 'No report yet. AI writes it from the photos and site records — tap below, or it is drafted automatically every evening.',
            style: muted,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
          const SizedBox(height: 8),
        ]),
      );
    }

    final c = r['content'] is Map ? Map<String, dynamic>.from(r['content']) : <String, dynamic>{};
    final work = (c['work_done'] as List? ?? []).whereType<Map>();
    final safety = (c['safety'] as List? ?? []).whereType<Map>();
    final issues = (c['issues'] as List? ?? []).map((e) => '$e');
    final mp = c['manpower'] is Map ? c['manpower'] as Map : {};
    return SectionCard(
      title: 'Report',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['summary'] ?? ''}', style: txt),
        if (work.isNotEmpty) head('Work done'),
        for (final w in work)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: RichText(text: TextSpan(style: txt, children: [
              TextSpan(text: '${w['area']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' — ${w['description']}'),
            ])),
          ),
        head('Manpower'),
        Text(
          [
            'Total ${mp['total'] ?? r['manpowerTotal'] ?? '—'}',
            for (final m in (mp['by_category'] as List? ?? []).whereType<Map>()) '${m['category']} ${m['count']}',
          ].join(' · '),
          style: txt,
        ),
        if ((mp['note'] ?? '').toString().isNotEmpty) Text('${mp['note']}', style: muted),
        if ((r['weather'] ?? '').toString().isNotEmpty) ...[head('Weather'), Text('${r['weather']}', style: txt)],
        if (issues.isNotEmpty) ...[head('Issues'), for (final s in issues) Text('• $s', style: txt)],
        if (safety.isNotEmpty) head('Safety'),
        for (final s in safety)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text('${'${s['severity']}'.toUpperCase()} — ${s['issue']}',
                style: TextStyle(color: _sevColor('${s['severity']}'), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        if ((r['remarks'] ?? '').toString().isNotEmpty) ...[head("Engineer's remarks"), Text('${r['remarks']}', style: txt)],
        const SizedBox(height: 6),
        Text('Drafted by AI from photos and site records${r['edited'] == true ? ', edited by the team' : ''}. Edit details on the web.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        if (buttons.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: buttons)],
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final Map<String, dynamic> photo;
  final VoidCallback onTap;
  const _PhotoThumb({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ai = photo['ai'] is Map ? photo['ai'] as Map : {};
    final issues = (ai['safety_issues'] as List? ?? []).whereType<Map>();
    final high = issues.any((s) => s['severity'] == 'high');
    final reading = photo['aiStatus'] == 'pending' || photo['aiStatus'] == 'working';
    return GestureDetector(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network('${photo['thumbUrl'] ?? photo['fileUrl']}', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppColors.inputFill, child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted))),
        ),
        if (high || issues.isNotEmpty)
          Positioned(right: 4, top: 4, child: Icon(Icons.warning_amber_rounded, size: 18, color: high ? Colors.redAccent : Colors.orangeAccent)),
        if (photo['onSite'] == false || photo['isMockLocation'] == true)
          const Positioned(left: 4, top: 4, child: Icon(Icons.wrong_location_rounded, size: 18, color: Colors.orangeAccent)),
        if (reading)
          const Positioned(left: 4, bottom: 4, child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
      ]),
    );
  }
}

class _PhotoSheet extends StatelessWidget {
  final Map<String, dynamic> photo;
  const _PhotoSheet({required this.photo});

  @override
  Widget build(BuildContext context) {
    final ai = photo['ai'] is Map ? photo['ai'] as Map : {};
    final txt = TextStyle(color: AppColors.textPrimary, fontSize: 13.5);
    final muted = TextStyle(color: AppColors.textSecondary, fontSize: 12.5);
    final checks = <String>[
      photo['source'] == 'camera' ? 'App camera' : 'Uploaded',
      if (photo['isMockLocation'] == true) 'FAKE GPS',
      if (photo['onSite'] == true) 'On site',
      if (photo['onSite'] == false) 'Off-site (${photo['distanceM']} m)',
      if (photo['timeVerified'] != true) photo['timeSource'] == 'exif' ? 'Time from photo' : 'Upload time',
    ];
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(14), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: InteractiveViewer(child: Image.network('${photo['fileUrl']}', fit: BoxFit.contain)),
          ),
          const SizedBox(height: 10),
          Text('${ai['activity'] ?? 'Site photo'}', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          Text('${photo['takenAt'] ?? ''} · ${photo['uploadedBy'] ?? ''}', style: muted),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final c in checks) StatusBadge(c)]),
          const SizedBox(height: 8),
          if ((photo['subLocation'] ?? '').toString().isNotEmpty) Text('Location: ${photo['subLocation']}', style: txt),
          if ((photo['caption'] ?? '').toString().isNotEmpty) Text('Note: ${photo['caption']}', style: txt),
          if (photo['aiStatus'] == 'done') ...[
            if ((ai['stage'] ?? '').toString().isNotEmpty) Text('Stage: ${ai['stage']}', style: txt),
            Text('Workers seen: ${ai['workers_visible'] ?? 0}', style: txt),
            if ((ai['machinery'] as List? ?? []).isNotEmpty) Text('Machinery: ${(ai['machinery'] as List).join(', ')}', style: txt),
            if ((ai['materials'] as List? ?? []).isNotEmpty) Text('Materials: ${(ai['materials'] as List).join(', ')}', style: txt),
            if ((ai['notes'] ?? '').toString().isNotEmpty) Text('${ai['notes']}', style: muted),
            for (final s in (ai['safety_issues'] as List? ?? []).whereType<Map>())
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${'${s['severity']}'.toUpperCase()} — ${s['issue']}',
                    style: TextStyle(color: _sevColor('${s['severity']}'), fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 4),
            Text('AI reading — check before relying on counts.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ] else
            Text(photo['aiStatus'] == 'failed' ? 'AI could not read this photo.' : 'AI is reading this photo…', style: muted),
        ]),
      ),
    );
  }
}
