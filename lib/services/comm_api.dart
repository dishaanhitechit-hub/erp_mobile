import 'api_service.dart';

/// Communication API — same endpoints the web ERP uses (erp-frontend/src/lib/commApi.js).
class CommApi {
  CommApi._();
  static const _c = '/comm';
  static ApiService get _api => ApiService.instance;

  static Future<dynamic> _get(String path, [Map<String, String>? params]) =>
      _api.get('$_c$path', params: params, projectScoped: false);

  static List<Map<String, dynamic>> _list(dynamic d, [String? key]) {
    final v = key != null && d is Map ? d[key] : d;
    return v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  // Conversations & messages
  static Future<List<Map<String, dynamic>>> conversations() async => _list(await _get('/conversations'));
  static Future<int> startDirect(int userId) async {
    final r = await _api.post('$_c/conversations/direct', body: {'userId': userId});
    return (r as Map)['conversationId'] as int;
  }

  static Future<Map<String, dynamic>> messages(int convId, {int? beforeId}) async {
    final r = await _get('/conversations/$convId/messages', beforeId != null ? {'beforeId': '$beforeId'} : null);
    return r is Map ? Map<String, dynamic>.from(r) : {'messages': [], 'hasMore': false};
  }

  static Future<List<Map<String, dynamic>>> newMessages(int convId, int? afterId) async =>
      _list(await _get('/conversations/$convId/messages/new', afterId != null ? {'afterId': '$afterId'} : null));

  static Future<void> sendMessage(int convId, String text) =>
      _api.post('$_c/conversations/$convId/messages', body: {'content': text, 'type': 'text'});

  // People
  static Future<List<Map<String, dynamic>>> directory([String? search]) async =>
      _list(await _get('/directory', (search ?? '').isEmpty ? null : {'search': search!}));

  // Pings
  static const pingTypes = {
    'ping': 'Ping',
    'nudge': 'Nudge',
    'attention': 'Attention Required',
    'approval_request': 'Approval Requested',
    'urgent': 'URGENT',
    'review': 'Need Review',
    'check': 'Please Check',
  };
  static Future<List<Map<String, dynamic>>> receivedPings() async => _list(await _get('/pings/received'));
  static Future<List<Map<String, dynamic>>> sentPings() async => _list(await _get('/pings/sent'));
  static Future<int> unreadPingCount() async {
    final r = await _get('/pings/unread-count');
    return r is Map ? (r['count'] as num? ?? 0).toInt() : 0;
  }

  static Future<void> sendPing(int receiverId, String type, String? message) => _api.post('$_c/pings',
      body: {'receiverId': receiverId, 'pingType': type, if ((message ?? '').isNotEmpty) 'message': message});
  static Future<void> markPingRead(int id) => _api.post('$_c/pings/$id/read');
  static Future<void> markAllPingsRead() => _api.post('$_c/pings/read-all');

  // Notifications
  static Future<Map<String, dynamic>> notifications({bool unreadOnly = false}) async {
    final r = await _get('/notifications', unreadOnly ? {'unreadOnly': 'true'} : {'limit': '100'});
    return r is Map ? Map<String, dynamic>.from(r) : {'items': [], 'unreadCount': 0};
  }

  static List<Map<String, dynamic>> items(Map<String, dynamic> n) => _list(n, 'items');
  static Future<void> markNotificationRead(int id) => _api.post('$_c/notifications/$id/read');
  static Future<void> markAllNotificationsRead() => _api.post('$_c/notifications/read-all');

  // Announcements
  static Future<List<Map<String, dynamic>>> announcements() async => _list(await _get('/announcements'));
  static Future<void> markAnnouncementRead(int id) => _api.post('$_c/announcements/$id/read');

  /// "2026-11-07 10:05:00" → "10:05" today, otherwise "07 Nov".
  static String shortTime(String? s) {
    if (s == null || s.length < 16) return '';
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (s.startsWith(today)) return s.substring(11, 16);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final m = int.tryParse(s.substring(5, 7)) ?? 1;
    return '${s.substring(8, 10)} ${months[(m - 1).clamp(0, 11)]}';
  }
}
