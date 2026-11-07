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

class _PeopleSheet extends StatefulWidget {
  final String title;
  const _PeopleSheet({required this.title});
  @override
  State<_PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends State<_PeopleSheet> {
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

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
          _people = p;
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
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
                              return ListTile(
                                onTap: () => Navigator.pop(context, p),
                                leading: PersonAvatar(name: name, online: online, colorIndex: i),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${p['empCode'] ?? ''}${online ? ' • online' : ''}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
