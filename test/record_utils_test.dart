import 'package:flutter_test/flutter_test.dart';
import 'package:erp_mobile/services/record_utils.dart';
import 'package:erp_mobile/config/module_registry.dart';

void main() {
  test('detects fields on an indent row', () {
    final r = {'id': 1, 'indentNo': 'IND-001', 'projectCode': 'P1', 'indentCategoryName': 'Cement',
      'indentStatus': 'Approved', 'totalAmount': 12500.5, 'indentDate': '2026-10-01'};
    final t = RecordUtils.titleKey(r);
    expect(t, 'indentNo');
    expect(RecordUtils.subtitleKey(r, t), 'indentCategoryName');
    expect(RecordUtils.statusKey(r), 'indentStatus');
    expect(RecordUtils.amountKey(r), 'totalAmount');
    expect(RecordUtils.dateKey(r), 'indentDate');
    expect(RecordUtils.humanize('indentCategoryName'), 'Indent Category Name');
  });

  test('extracts nested lists', () {
    expect(RecordUtils.extractList({'items': [{'a': 1}]}).length, 1);
    expect(RecordUtils.extractList([{'a': 1}, {'b': 2}]).length, 2);
  });

  test('registry keys are unique and nothing is editable', () {
    final mods = [for (final s in allSections) ...s.modules];
    expect(mods.map((m) => m.key).toSet().length, mods.length);
    expect(mods.any((m) => m.canEdit), isFalse);
  });
}
