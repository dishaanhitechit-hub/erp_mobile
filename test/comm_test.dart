import 'package:erp_mobile/services/comm_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shortTime shows HH:mm for today and "dd Mon" otherwise', () {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final today = '${n.year}-${two(n.month)}-${two(n.day)} 09:42:10';
    expect(CommApi.shortTime(today), '09:42');
    expect(CommApi.shortTime('2020-03-05 10:00:00'), '05 Mar');
    expect(CommApi.shortTime(null), '');
    expect(CommApi.shortTime('bad'), '');
  });

  test('ping types match the backend list', () {
    expect(CommApi.pingTypes.keys,
        containsAll(['ping', 'nudge', 'attention', 'approval_request', 'urgent', 'review', 'check']));
  });
}
