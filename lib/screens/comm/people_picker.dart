import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/comm_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pp_widgets.dart';

/// Bottom sheet to pick a colleague from the ERP directory.
Future<Map<String, dynamic>?> pickPerson(BuildContext context, {String title = 'Choose a person'}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PeopleSheet(title: title),
  );
}

/// Multi-select version (new group, add members, add to call).
/// Returns null when cancelled.
Future<List<Map<String, dynamic>>?> pickPeople(BuildContext context,
    {String title = 'Choose people', Set<int> exclude = const {}, String action = 'Done'}) {
  return showModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _PeopleSheet(title: title, multi: true, exclude: exclude, action: action),
  );
}

class _PeopleSheet extends StatefulWidget {
  final String title;
  final bool multi;
  final Set<int> exclude;
  final String action;
  const _PeopleSheet({required this.title, this.multi = false, this.exclude = const {}, this.action = 'Done'});
  @override
  State<_PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends State<_PeopleSheet> {
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  final _picked = <int, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final p = await CommApi.directory(q);
      if (mounted) {
        setState(() {
          _people = p.where((x) => !widget.exclude.contains(x['userId'])).toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(children: [
              Expanded(
                child: Text(widget.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              if (widget.multi)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                  onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.values.toList()),
                  child: Text(_picked.isEmpty ? widget.action : '${widget.action} (${_picked.length})'),
                ),
            ]),
          ),
          if (widget.multi && _picked.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final p in _picked.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text('${p['userName']}'),
                        onDeleted: () => setState(() => _picked.remove(p['userId'])),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () => _load(v.trim()));
              },
              decoration: InputDecoration(
                hintText: 'Search name or employee code',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.bgCard,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null
                    ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load people', message: _error)
                    : _people.isEmpty
                        ? const EmptyState(icon: Icons.person_search_rounded, title: 'No one found')
                        : ListView.builder(
                            controller: scroll,
                            itemCount: _people.length,
                            itemBuilder: (_, i) {
                              final p = _people[i];
                              final name = '${p['userName'] ?? ''}';
                              final online = p['status'] == 'online';
                              final id = p['userId'] as int;
                              final sel = _picked.containsKey(id);
                              return ListTile(
                                onTap: () {
                                  if (!widget.multi) return Navigator.pop(context, p);
                                  setState(() => sel ? _picked.remove(id) : _picked[id] = p);
                                },
                                trailing: widget.multi
                                    ? Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: sel ? AppColors.accent : AppColors.textMuted)
                                    : null,
                                leading: PersonAvatar(name: name, online: online, colorIndex: i),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${p['empCode'] ?? ''}${online ? ' • online' : ''}',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

/// Initial-letter avatar with an optional online dot.
class PersonAvatar extends StatelessWidget {
  final String name;
  final bool online;
  final int colorIndex;
  final double radius;
  final IconData? icon;
  const PersonAvatar({super.key, required this.name, this.online = false, this.colorIndex = 0, this.radius = 22, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = colorFor(colorIndex);
    return Stack(children: [
      CircleAvatar(
        radius: radius,
        backgroundColor: c.withValues(alpha: 0.15),
        child: icon != null
            ? Icon(icon, color: c, size: radius)
            : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
      ),
      if (online)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          ),
        ),
    ]);
  }
}
