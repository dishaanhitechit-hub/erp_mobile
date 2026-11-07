import 'package:erp_mobile/config/access_control.dart';
import 'package:erp_mobile/config/module_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AccessControl.role = '';
    AccessControl.serverPermissions = {};
  });

  test('rbac on, edit off: nothing is editable', () {
    expect(AccessControl.useRbac, isTrue);
    expect(AccessControl.allowEdit, isFalse);
    AccessControl.role = Roles.user;
    AccessControl.serverPermissions = {'indent.EDIT': true, 'grn.VIEW': true};
    final all = {for (final s in allSections) for (final m in s.modules) m.key: m};
    expect(all.values.any((m) => m.canEdit), isFalse);
    expect(all['indent']!.canView, isTrue);
    expect(all['payroll']!.canView, isFalse);
    expect(all['user_id_password']!.canView, isFalse);
  });

  test('user without project sees only Master', () {
    AccessControl.role = Roles.user;
    final sections = visibleSections.map((s) => s.key).toList();
    expect(sections, ['master']);
  });

  test('permission keys match case-insensitively', () {
    AccessControl.role = Roles.user;
    AccessControl.serverPermissions = {'indent.view': true};
    expect(AccessControl.realLevel('indent', 'resources'), AccessLevel.view);
  });

  test('general user follows project permissions', () {
    AccessControl.role = Roles.user;
    AccessControl.serverPermissions = {
      'indent.EDIT': true,
      'grn.VIEW': true,
      'payment.APPROVER': true,
    };
    expect(AccessControl.realLevel('indent', 'resources'), AccessLevel.edit);
    expect(AccessControl.realLevel('grn', 'resources'), AccessLevel.view);
    expect(AccessControl.realLevel('payment', 'finance'), AccessLevel.view);
    expect(AccessControl.realLevel('payroll', 'hr'), AccessLevel.hidden);
    expect(AccessControl.realLevel('user_id_password', 'settings'), AccessLevel.hidden);
    expect(AccessControl.realLevel('ledger_code', 'master'), AccessLevel.view);
  });

  test('admin edits master only; super admin edits settings only', () {
    AccessControl.role = Roles.admin;
    expect(AccessControl.realLevel('ledger_code', 'master'), AccessLevel.edit);
    expect(AccessControl.realLevel('indent', 'resources'), AccessLevel.hidden);
    AccessControl.role = Roles.superAdmin;
    expect(AccessControl.realLevel('company_details', 'settings'), AccessLevel.edit);
    expect(AccessControl.realLevel('ledger_code', 'master'), AccessLevel.view);
    expect(AccessControl.realLevel('indent', 'resources'), AccessLevel.hidden);
  });

  test('every module knows its section; shared keys map to web keys', () {
    final all = [for (final s in allSections) ...s.modules];
    expect(all.every((m) => m.section != null), isTrue);
    final so = all.firstWhere((m) => m.key == 'service_order');
    expect(so.permissionKey, 'order');
  });
}
