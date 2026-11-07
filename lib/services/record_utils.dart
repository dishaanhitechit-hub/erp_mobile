import 'package:intl/intl.dart';

/// Helpers that let one generic list/detail screen show any backend record.
class RecordUtils {
  RecordUtils._();

  static final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  /// Pulls the list of rows out of whatever shape the API returned.
  static List<Map<String, dynamic>> extractList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (data is Map) {
      for (final k in ['items', 'rows', 'records', 'list', 'results', 'data']) {
        if (data[k] is List) return extractList(data[k]);
      }
      final firstList = data.values.firstWhere((v) => v is List && v.isNotEmpty && v.first is Map, orElse: () => null);
      if (firstList != null) return extractList(firstList);
    }
    return [];
  }

  static bool _isBlank(dynamic v) => v == null || (v is String && v.trim().isEmpty) || v is Map || v is List;

  static String? _firstMatch(Map<String, dynamic> r, bool Function(String k) test, {Set<String> skip = const {}}) {
    for (final e in r.entries) {
      if (skip.contains(e.key) || _isBlank(e.value)) continue;
      if (test(e.key.toLowerCase())) return e.key;
    }
    return null;
  }

  static String? titleKey(Map<String, dynamic> r, [String? hint]) {
    if (hint != null && !_isBlank(r[hint])) return hint;
    return _firstMatch(r, (k) => k.endsWith('no') || k.endsWith('number') && !k.contains('mobile') && !k.contains('phone')) ??
        _firstMatch(r, (k) => k.endsWith('name') && !k.contains('project') && !k.contains('created')) ??
        _firstMatch(r, (k) => k.endsWith('code') && k != 'projectcode') ??
        _firstMatch(r, (k) => k == 'title' || k.endsWith('title'));
  }

  static String? subtitleKey(Map<String, dynamic> r, String? title, [String? hint]) {
    if (hint != null && !_isBlank(r[hint])) return hint;
    final skip = {if (title != null) title};
    return _firstMatch(r, (k) => (k.contains('vendor') || k.contains('party') || k.contains('supplier') ||
                k.contains('customer') || k.contains('client')) && k.endsWith('name'), skip: skip) ??
        _firstMatch(r, (k) => k.endsWith('name') && !k.contains('created') && !k.contains('updated'), skip: skip) ??
        _firstMatch(r, (k) => k.contains('category') || k.contains('type') || k.contains('designation'), skip: skip) ??
        _firstMatch(r, (k) => k.endsWith('code'), skip: skip);
  }

  static String? statusKey(Map<String, dynamic> r) =>
      _firstMatch(r, (k) => k == 'workflowstatus') ?? _firstMatch(r, (k) => k.endsWith('status'));

  static String? amountKey(Map<String, dynamic> r) => _firstMatch(r,
      (k) => (k.contains('amount') || k.contains('total') || k.contains('value') || k.contains('salary') || k == 'net' || k.endsWith('pay')) &&
          !k.contains('word') && !k.contains('percent'));

  static String? dateKey(Map<String, dynamic> r) =>
      _firstMatch(r, (k) => k.endsWith('date') && !k.contains('update')) ?? _firstMatch(r, (k) => k.contains('date') || k == 'createdat');

  static String text(Map<String, dynamic> r, String? key) => key == null ? '' : format(key, r[key]);

  /// "indentCategoryName" → "Indent Category Name"
  static String humanize(String key) {
    final spaced = key
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  static String format(String key, dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Yes' : 'No';
    final k = key.toLowerCase();
    if (v is num && (k.contains('amount') || k.contains('total') || k.contains('value') || k.contains('salary'))) {
      return _inr.format(v);
    }
    final s = v.toString();
    if ((k.contains('date') || k.endsWith('at')) && s.length >= 10) {
      final d = DateTime.tryParse(s);
      if (d != null) return DateFormat(s.length > 10 && (d.hour + d.minute) > 0 ? 'dd MMM yyyy, hh:mm a' : 'dd MMM yyyy').format(d.toLocal());
    }
    return s;
  }

  static String money(dynamic v) {
    final n = v is num ? v : num.tryParse('$v');
    return n == null ? '$v' : _inr.format(n);
  }

  /// Hidden from the detail view: ids, tokens, internal fields.
  static bool isInternal(String key) {
    final k = key.toLowerCase();
    return k == 'id' || k == 'uuid' || k.endsWith('uuid') || k.contains('token') || k.contains('password');
  }
}
