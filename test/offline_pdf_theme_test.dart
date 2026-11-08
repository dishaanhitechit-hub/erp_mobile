import 'package:erp_mobile/config/module_registry.dart';
import 'package:erp_mobile/screens/common/print_view_screen.dart';
import 'package:erp_mobile/services/offline_store.dart';
import 'package:erp_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const indent = ErpModule(key: 'indent', title: 'Indent', icon: Icons.list_alt_rounded, endpoint: '/x', detail: '/y');
  const unit = ErpModule(key: 'unit', title: 'Unit', icon: Icons.straighten_rounded, endpoint: '/x');

  test('web print URL uses the module route and record uuid', () {
    expect(webPrintUrl(indent, {'id': 3, 'uuid': 'ab-12'}), 'https://132.154.156.82/print/indent/ab-12');
    expect(webPrintUrl(indent, {'id': 3, 'indentUuid': 'zz'}), endsWith('/print/indent/zz'));
    expect(webPrintUrl(indent, {'id': 3}), isNull); // no uuid → phone-made PDF
    expect(webPrintUrl(unit, {'uuid': 'q'}), isNull); // no web print page
  });

  test('phone-made PDF builds for any record, including ₹ and item tables', () async {
    final bytes = await buildRecordPdf(indent, {
      'indentNo': 'IND-7',
      'totalAmount': 12500.5,
      'remarks': 'Urgent — cement “OPC”',
      'project': {'projectName': 'Bridge'},
      'items': [
        {'itemName': 'Cement', 'qty': 10, 'unit': 'Bag'},
        {'itemName': 'Steel', 'qty': 2, 'unit': 'MT'},
      ],
    }, 'Indent IND-7');
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('outbox queues offline writes, sends them in order, drops rejected ones', () async {
    SharedPreferences.setMockInitialValues({});
    final box = Outbox.instance;
    await box.clear();
    await box.add('POST', '/comm/conversations/1/messages', {'content': 'a'}, label: 'Message', tag: 'chat:1');
    await box.add('POST', '/comm/pings', {'receiverId': 2}, label: 'Ping', tag: 'ping');
    await box.add('POST', '/comm/conversations/1/messages', {'content': 'b'}, label: 'Message', tag: 'chat:1');
    expect(box.withTag('chat:1').map((i) => i.body['content']), ['a', 'b']);

    // still offline → nothing sent, nothing lost
    box.sender = (_) async => throw const OfflineException();
    await box.flush();
    expect(box.items.length, 3);

    final sent = <String>[];
    box.sender = (i) async {
      if (i.tag == 'ping') throw Exception('rejected');
      sent.add('${i.body['content']}');
    };
    await box.flush();
    expect(sent, ['a', 'b']);
    expect(box.items, isEmpty);
  });

  test('themes switch the colours the screens read', () {
    expect(AppThemes.all.length, 4);
    AppColors.palette = AppThemes.midnight;
    expect(AppColors.bg, AppThemes.midnight.bg);
    expect(AppTheme.theme.brightness, Brightness.dark);
    AppColors.palette = AppThemes.classic;
    expect(AppTheme.theme.brightness, Brightness.light);
    expect(AppThemes.byId('nope').id, 'classic');
  });
}
