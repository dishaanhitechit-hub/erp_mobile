// ─────────────────────────────────────────────────────────────────────────────
//  MODULE REGISTRY — every screen of the app, grouped exactly like the web
//  frontend's sidebar (erp-frontend/src/config/sidebar.config.js).
//
//  To add a module: add an ErpModule to the right group. To change whether it
//  is view/edit/hidden, edit config/access_control.dart (not here).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'access_control.dart';

/// list/report: generic screens. dpr: Daily Progress Report (photos + AI report).
enum ModuleKind { list, report, dpr }

class ErpModule {
  /// Unique key — same as the web frontend's permissionKey.
  final String key;

  /// Web permissionKey when it differs from [key] (e.g. Service Order uses
  /// the shared "order" permission). Used by AccessControl's real flow.
  final String? permissionKey;
  final String title;
  final IconData icon;

  /// List endpoint (or report endpoint). null → not available on mobile yet.
  final String? endpoint;

  /// Detail endpoint prefix; the record id is appended (`$detail/$id`).
  final String? detail;

  /// Record field holding the id (defaults to `id`).
  final String idKey;

  final Map<String, String>? params;

  /// Whether the current projectCode is sent as a query parameter.
  final bool projectScoped;

  final ModuleKind kind;

  /// Optional field hints for list cards. Left null, they are auto-detected.
  final String? titleKey;
  final String? subtitleKey;

  const ErpModule({
    required this.key,
    this.permissionKey,
    required this.title,
    required this.icon,
    this.endpoint,
    this.detail,
    this.idKey = 'id',
    this.params,
    this.projectScoped = true,
    this.kind = ModuleKind.list,
    this.titleKey,
    this.subtitleKey,
  });

  bool get available => endpoint != null;
  /// Navbar section this module sits in (settings, master, resources…).
  String? get section => _sectionOf[key];

  AccessLevel get access =>
      AccessControl.levelFor(key, permissionKey: permissionKey, section: section);
  bool get canView => access != AccessLevel.hidden;
  bool get canEdit => access == AccessLevel.edit;
  bool get canApprove => AccessControl.canApprove(permissionKey ?? key);
}

class ModuleGroup {
  final String title;
  final List<ErpModule> modules;
  const ModuleGroup(this.title, this.modules);
}

class ModuleSection {
  final String key;
  final String title;
  final String shortTitle;
  final IconData icon;
  final List<ModuleGroup> groups;
  const ModuleSection({
    required this.key,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.groups,
  });

  List<ErpModule> get modules => [for (final g in groups) ...g.modules];
  List<ErpModule> get visibleModules => modules.where((m) => m.canView).toList();
}

// ── Sections ─────────────────────────────────────────────────────────────────

const _settings = ModuleSection(
  key: 'settings', title: 'Settings', shortTitle: 'Settings', icon: Icons.settings_rounded,
  groups: [
    ModuleGroup('Settings', [
      ErpModule(key: 'user_id_password', title: 'Users', icon: Icons.manage_accounts_rounded,
          endpoint: '/setting/users', detail: '/setting/user', projectScoped: false,
          titleKey: 'username'),
      ErpModule(key: 'project_code', title: 'Project Code', icon: Icons.business_center_rounded,
          endpoint: '/setting/project-list', detail: '/setting/project', projectScoped: false,
          titleKey: 'projectName', subtitleKey: 'clientName'),
      ErpModule(key: 'company_details', title: 'Company Details', icon: Icons.apartment_rounded,
          endpoint: '/compny/my-companies', projectScoped: false),
      ErpModule(key: 'roles_and_user_assignment', title: 'Roles & Users', icon: Icons.badge_rounded),
    ]),
  ],
);

const _master = ModuleSection(
  key: 'master', title: 'Master', shortTitle: 'Master', icon: Icons.storage_rounded,
  groups: [
    ModuleGroup('Codes', [
      ErpModule(key: 'ledger_code', title: 'Vendor Code', icon: Icons.storefront_rounded,
          endpoint: '/master/ledger/list', detail: '/master/ledger', projectScoped: false),
      ErpModule(key: 'item_code', title: 'Item Code', icon: Icons.inventory_2_rounded,
          endpoint: '/master/item/list', detail: '/master/item', projectScoped: false),
      ErpModule(key: 'asset_code', title: 'Asset Code', icon: Icons.precision_manufacturing_rounded,
          endpoint: '/master/asset/list', detail: '/master/asset', projectScoped: false),
      ErpModule(key: 'unit', title: 'Unit', icon: Icons.straighten_rounded,
          endpoint: '/master/unit/list', detail: '/master/unit', projectScoped: false),
      ErpModule(key: 'cost_center_code', title: 'Cost Center', icon: Icons.account_tree_rounded,
          endpoint: '/master/cc-code/list', detail: '/master/cc-code', projectScoped: false),
      ErpModule(key: 'category_group', title: 'Category & Group', icon: Icons.category_rounded,
          endpoint: '/master/category/list', projectScoped: false),
      ErpModule(key: 'terms_condition', title: 'Terms & Conditions', icon: Icons.gavel_rounded,
          endpoint: '/master/term/list', detail: '/master/term', projectScoped: false),
      ErpModule(key: 'bank_cash', title: 'Bank & Cash', icon: Icons.account_balance_rounded,
          endpoint: '/master/bank-cash/list', detail: '/master/bank-cash', projectScoped: false),
      ErpModule(key: 'supplier', title: 'Supplier', icon: Icons.local_shipping_rounded,
          endpoint: '/master/supplier/list', detail: '/master/supplier', projectScoped: false),
      ErpModule(key: 'traceability_workbench', title: 'Traceability', icon: Icons.route_rounded),
    ]),
    ModuleGroup('Contact Diary', [
      ErpModule(key: 'master_contact_dairy_materials', title: 'Materials', icon: Icons.contacts_rounded),
      ErpModule(key: 'master_contact_dairy_work_force', title: 'Work Force', icon: Icons.groups_rounded),
      ErpModule(key: 'master_contact_dairy_plant_machinery', title: 'Plant & Machinery', icon: Icons.agriculture_rounded),
    ]),
  ],
);

const _resources = ModuleSection(
  key: 'resources', title: 'Resources Management', shortTitle: 'Resources', icon: Icons.inventory_rounded,
  groups: [
    ModuleGroup('Procurement', [
      ErpModule(key: 'indent', title: 'Indent', icon: Icons.list_alt_rounded,
          endpoint: '/resource/indent/list', detail: '/resource/indent'),
      ErpModule(key: 'enquiry', title: 'Enquiry', icon: Icons.help_center_rounded,
          endpoint: '/resource/enquiry/list'),
      ErpModule(key: 'order', title: 'Material Order', icon: Icons.shopping_cart_rounded,
          endpoint: '/resource/order/list', detail: '/resource/order/details'),
      ErpModule(key: 'service_order', permissionKey: 'order', title: 'Service Order', icon: Icons.handyman_rounded,
          endpoint: '/resource/pw-order/list', detail: '/resource/pw-order/details'),
    ]),
    ModuleGroup('Materials', [
      ErpModule(key: 'goods_received_note', title: 'GRN', icon: Icons.move_to_inbox_rounded,
          endpoint: '/resource/grn/list', detail: '/resource/grn/details'),
      ErpModule(key: 'goods_issue_note', title: 'GIN', icon: Icons.outbox_rounded,
          endpoint: '/resource/gin/list', detail: '/resource/gin/details'),
      ErpModule(key: 'stock_report', title: 'Inventory', icon: Icons.warehouse_rounded,
          endpoint: '/resource/stock/list'),
    ]),
    ModuleGroup('Services', [
      ErpModule(key: 'dlr', title: 'DLR', icon: Icons.assignment_ind_rounded,
          endpoint: '/resource/dlr/list', detail: '/resource/dlr/details'),
      ErpModule(key: 'labour_id', title: 'Labour ID', icon: Icons.badge_rounded,
          endpoint: '/resource/manpower/list', detail: '/resource/manpower'),
      ErpModule(key: 'pm_inventory', title: 'P&M Inventory', icon: Icons.construction_rounded,
          endpoint: '/resource/machinery/pm-id/list', detail: '/resource/machinery/pm-id'),
      ErpModule(key: 'log_sheet', title: 'Log Sheet', icon: Icons.menu_book_rounded,
          endpoint: '/resource/machinery/log-book/list', detail: '/resource/machinery/log-book/details'),
      ErpModule(key: 'batching_plant', title: 'Batching Plant', icon: Icons.factory_rounded,
          endpoint: '/resource/batching/list', detail: '/resource/batching/details'),
      ErpModule(key: 'service_received_note', title: 'SRN', icon: Icons.task_alt_rounded,
          endpoint: '/resource/srn/list', detail: '/resource/srn/details'),
    ]),
    ModuleGroup('Sub Contractor Billing', [
      ErpModule(key: 'bill_receive_register', title: 'Bill Receive Register', icon: Icons.receipt_long_rounded,
          endpoint: '/billing/brr/list', detail: '/billing/brr/details'),
      ErpModule(key: 'payment_request', title: 'Payment Request', icon: Icons.request_quote_rounded,
          endpoint: '/billing/brb/list', detail: '/billing/brb/details'),
    ]),
    ModuleGroup('Contact Diary', [
      ErpModule(key: 'contact_dairy_materials', title: 'Materials', icon: Icons.contacts_rounded),
      ErpModule(key: 'contact_dairy_work_force', title: 'Work Force', icon: Icons.groups_rounded),
      ErpModule(key: 'contact_dairy_plant_machinery', title: 'Plant & Machinery', icon: Icons.agriculture_rounded),
    ]),
  ],
);

const _project = ModuleSection(
  key: 'project', title: 'Project Management', shortTitle: 'Projects', icon: Icons.work_rounded,
  groups: [
    ModuleGroup('Contracts', [
      ErpModule(key: 'sale_order', title: 'Sale Order', icon: Icons.description_rounded,
          endpoint: '/project-mgmt/og-sale-order/list', detail: '/project-mgmt/og-sale-order'),
      ErpModule(key: 'budget_master', title: 'Budget Master', icon: Icons.savings_rounded,
          endpoint: '/project-mgmt/contract/budget/list', detail: '/project-mgmt/contract/budget'),
      ErpModule(key: 'extra_work', title: 'Extra Work', icon: Icons.add_task_rounded),
    ]),
    ModuleGroup('Planning', [
      ErpModule(key: 'l1_schedule', title: 'L1 Schedule', icon: Icons.calendar_month_rounded),
      ErpModule(key: 'monthly_planning', title: 'Monthly Planning', icon: Icons.event_note_rounded),
      ErpModule(key: 'micro_planning', title: 'Micro Planning', icon: Icons.view_timeline_rounded),
      ErpModule(key: 'promise_schedule', title: 'Promise Schedule', icon: Icons.handshake_rounded),
    ]),
    ModuleGroup('Progress', [
      ErpModule(key: 'daily_progress_report', title: 'Daily Progress', icon: Icons.photo_camera_rounded,
          endpoint: '/project-mgmt/dpr/list', kind: ModuleKind.dpr),
      ErpModule(key: 'job_achievement', title: 'Job Achievement', icon: Icons.emoji_events_rounded),
    ]),
    ModuleGroup('Register', [
      ErpModule(key: 'drawing_register', title: 'Drawing Register', icon: Icons.architecture_rounded,
          endpoint: '/project-mgmt/register/drawing-register/list', detail: '/project-mgmt/register/drawing-register/details'),
      ErpModule(key: 'bbs_register', title: 'BBS Register', icon: Icons.grid_on_rounded,
          endpoint: '/project-mgmt/register/bbs-register/list', detail: '/project-mgmt/register/bbs-register/details'),
      ErpModule(key: 'concrete_register', title: 'Concrete Register', icon: Icons.foundation_rounded,
          endpoint: '/project-mgmt/register/concrete-registry/list'),
      ErpModule(key: 'hindrance_register', title: 'Hindrance Register', icon: Icons.report_problem_rounded,
          endpoint: '/project-mgmt/register/hindrance-register/list', detail: '/project-mgmt/register/hindrance-register/details'),
    ]),
    ModuleGroup('Customer Billing', [
      ErpModule(key: 'sale_claim_bill', title: 'Sale Bill - Claim', icon: Icons.receipt_rounded,
          endpoint: '/project-mgmt/billing/list', params: {'mode': 'sale_order_bill'}, detail: '/project-mgmt/billing'),
      ErpModule(key: 'sale_certified_bill', title: 'Sale Bill - Certified', icon: Icons.verified_rounded,
          endpoint: '/project-mgmt/billing/list', params: {'mode': 'certified_bill'}, detail: '/project-mgmt/billing'),
      ErpModule(key: 'uncertified_statement', title: 'Uncertified Statement', icon: Icons.pending_actions_rounded,
          endpoint: '/project-mgmt/uncertain-allocation/list', detail: '/project-mgmt/uncertain-allocation'),
    ]),
  ],
);

const _asset = ModuleSection(
  key: 'asset', title: 'Asset Management', shortTitle: 'Assets', icon: Icons.widgets_rounded,
  groups: [
    ModuleGroup('Asset Management', [
      ErpModule(key: 'am_asset_register', title: 'Asset Register', icon: Icons.inventory_rounded),
      ErpModule(key: 'am_site_allocation', title: 'Site Allocation', icon: Icons.place_rounded),
      ErpModule(key: 'am_maintenance_repair', title: 'Maintenance', icon: Icons.build_rounded),
      ErpModule(key: 'am_rental_utilization', title: 'Rental & Utilization', icon: Icons.timelapse_rounded),
      ErpModule(key: 'am_depreciation_disposal', title: 'Depreciation', icon: Icons.trending_down_rounded),
      ErpModule(key: 'am_daily_issue_return', title: 'Daily Issue & Return', icon: Icons.sync_alt_rounded),
    ]),
  ],
);

const _logistics = ModuleSection(
  key: 'logistics', title: 'Logistics', shortTitle: 'Logistics', icon: Icons.local_shipping_rounded,
  groups: [
    ModuleGroup('Logistics', [
      ErpModule(key: 'transit_request', title: 'Transit Request', icon: Icons.alt_route_rounded),
      ErpModule(key: 'delivery_challan', title: 'Delivery Challan', icon: Icons.local_shipping_rounded,
          endpoint: '/resource/dc/list', detail: '/resource/dc/detail'),
      ErpModule(key: 'logistics_bill_register', title: 'Bill Register', icon: Icons.receipt_long_rounded),
    ]),
  ],
);

const _finance = ModuleSection(
  key: 'finance', title: 'Finance Management', shortTitle: 'Finance', icon: Icons.account_balance_wallet_rounded,
  groups: [
    ModuleGroup('Accounts', [
      ErpModule(key: 'sale', title: 'Sale', icon: Icons.point_of_sale_rounded,
          endpoint: '/finance/sale-bill/list', detail: '/finance/sale-bill'),
      ErpModule(key: 'purchases', title: 'Purchases', icon: Icons.shopping_bag_rounded,
          endpoint: '/finance/purchase-bill/list', detail: '/finance/purchase-bill'),
      ErpModule(key: 'purchase_voucher', permissionKey: 'purchases', title: 'Purchase Voucher', icon: Icons.confirmation_number_rounded,
          endpoint: '/finance/purchase-voucher/list', detail: '/finance/purchase-voucher'),
      ErpModule(key: 'receipt', title: 'Receipt', icon: Icons.call_received_rounded,
          endpoint: '/finance/sale-receipt/list', detail: '/finance/sale-receipt'),
      ErpModule(key: 'payment', title: 'Payment', icon: Icons.call_made_rounded,
          endpoint: '/finance/payment-voucher/list', detail: '/finance/payment-voucher'),
      ErpModule(key: 'bill_payment', permissionKey: 'payment', title: 'Bill Payment', icon: Icons.payments_rounded,
          endpoint: '/finance/bill-payment/list', detail: '/finance/bill-payment'),
      ErpModule(key: 'contra', title: 'Contra', icon: Icons.swap_horiz_rounded,
          endpoint: '/finance/contra-entry/list', detail: '/finance/contra-entry'),
      ErpModule(key: 'debit_note', title: 'Debit Note', icon: Icons.remove_circle_outline_rounded,
          endpoint: '/finance/debit-note/list', detail: '/finance/debit-note'),
      ErpModule(key: 'credit_note', title: 'Credit Note', icon: Icons.add_card_rounded,
          endpoint: '/finance/credit-note/list', detail: '/finance/credit-note'),
      ErpModule(key: 'journal', title: 'Journal', icon: Icons.auto_stories_rounded,
          endpoint: '/finance/journal-entry/list', detail: '/finance/journal-entry'),
      ErpModule(key: 'petty_cash', title: 'Petty Cash', icon: Icons.wallet_rounded,
          endpoint: '/finance/petty-cash/docket-voucher/list', detail: '/finance/petty-cash/docket-voucher'),
      ErpModule(key: 'ledger_view', title: 'My Ledger', icon: Icons.menu_book_rounded,
          endpoint: '/finance/my-ledger', kind: ModuleKind.report),
    ]),
    ModuleGroup('Reports', [
      ErpModule(key: 'profit_loss', title: 'Profit & Loss', icon: Icons.insights_rounded,
          endpoint: '/finance/profit-loss', kind: ModuleKind.report),
      ErpModule(key: 'balance_sheet', title: 'Balance Sheet', icon: Icons.balance_rounded,
          endpoint: '/finance/balance-sheet', kind: ModuleKind.report),
      ErpModule(key: 'cash_flow', title: 'Cash Flow', icon: Icons.water_rounded),
      ErpModule(key: 'gst_reconciliation', title: 'GST Reconciliation', icon: Icons.percent_rounded),
      ErpModule(key: 'vendor_liability', title: 'Vendor Liability', icon: Icons.assignment_late_rounded),
    ]),
  ],
);

const _hr = ModuleSection(
  key: 'hr', title: 'HRMS', shortTitle: 'HRMS', icon: Icons.groups_rounded,
  groups: [
    ModuleGroup('Employee Management', [
      ErpModule(key: 'recruitment', title: 'Recruitment', icon: Icons.person_search_rounded,
          endpoint: '/hr/recruitment/candidates', projectScoped: false),
      ErpModule(key: 'offer_letter', title: 'Job Openings', icon: Icons.work_outline_rounded,
          endpoint: '/hr/recruitment/jobs', projectScoped: false),
      ErpModule(key: 'appointment_letter', title: 'Interviews', icon: Icons.record_voice_over_rounded,
          endpoint: '/hr/recruitment/interviews', projectScoped: false),
      ErpModule(key: 'onboarding', title: 'Onboarding', icon: Icons.how_to_reg_rounded,
          endpoint: '/hr/onboarding', projectScoped: false),
      ErpModule(key: 'employee_management', title: 'Employee Master', icon: Icons.badge_rounded,
          endpoint: '/hr/employee', detail: '/hr/employee', projectScoped: false),
      ErpModule(key: 'employee_fnf', title: 'Employee F&F', icon: Icons.logout_rounded),
    ]),
    ModuleGroup('Administration', [
      ErpModule(key: 'hr_attendance', title: 'Attendance', icon: Icons.fact_check_rounded),
      ErpModule(key: 'leave', title: 'Leave', icon: Icons.beach_access_rounded),
      ErpModule(key: 'payroll', title: 'Payroll', icon: Icons.currency_rupee_rounded,
          endpoint: '/hr/payroll', projectScoped: false),
      ErpModule(key: 'statutory_compliance', title: 'Statutory', icon: Icons.policy_rounded),
    ]),
    ModuleGroup('Reports & Others', [
      ErpModule(key: 'performance_appraisal', title: 'Performance', icon: Icons.star_rate_rounded,
          endpoint: '/hr/performance/reviews', projectScoped: false),
      ErpModule(key: 'discipline', permissionKey: 'performance_appraisal', title: 'Discipline', icon: Icons.rule_rounded,
          endpoint: '/hr/performance/discipline', projectScoped: false),
      ErpModule(key: 'hr_gang_tracker', title: 'Gang Tracker', icon: Icons.engineering_rounded,
          endpoint: '/hr/gang-tracker', projectScoped: false),
      ErpModule(key: 'it_office_asset', title: 'IT & Office Asset', icon: Icons.computer_rounded),
      ErpModule(key: 'travel_expense', title: 'Travel & Expense', icon: Icons.flight_takeoff_rounded),
      ErpModule(key: 'org_structure', title: 'Org Structure', icon: Icons.account_tree_rounded),
      ErpModule(key: 'circular', title: 'Circular', icon: Icons.campaign_rounded),
      ErpModule(key: 'notice', title: 'Notice', icon: Icons.notifications_active_rounded),
    ]),
  ],
);

const _mis = ModuleSection(
  key: 'mis', title: 'MIS', shortTitle: 'MIS', icon: Icons.checklist_rounded,
  groups: [
    ModuleGroup('Task Management', [
      ErpModule(key: 'task_tracker', title: 'Task Tracker', icon: Icons.track_changes_rounded),
      ErpModule(key: 'to_do_list', title: 'To-do List', icon: Icons.checklist_rounded),
      ErpModule(key: 'schedule_compliance', title: 'Schedule Compliance', icon: Icons.schedule_rounded),
    ]),
  ],
);

/// Order matches the web sidebar.
const List<ModuleSection> allSections = [
  _settings, _master, _resources, _project, _asset, _logistics, _finance, _hr, _mis,
];

final Map<String, String> _sectionOf = {
  for (final s in allSections)
    for (final m in s.modules) m.key: s.key,
};

List<ModuleSection> get visibleSections =>
    allSections.where((s) => s.visibleModules.isNotEmpty).toList();
