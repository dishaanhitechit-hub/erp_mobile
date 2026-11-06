import 'package:flutter/material.dart';
import '../config/api.dart';

class ErpModule {
  final String title;
  final IconData icon;
  final String endpoint;
  final Map<String, String>? params;
  final List<ColumnDef> columns;
  final String? detailEndpoint;
  final String? idKey;

  const ErpModule({
    required this.title,
    required this.icon,
    required this.endpoint,
    required this.columns,
    this.params,
    this.detailEndpoint,
    this.idKey,
  });
}

class ColumnDef {
  final String key;
  final String label;
  final bool isTitle;
  final bool isSubtitle;
  final bool isBadge;
  const ColumnDef(this.key, this.label, {this.isTitle = false, this.isSubtitle = false, this.isBadge = false});
}

// ── Module registry ──────────────────────────────────────────────────────────

class ModuleSection {
  final String title;
  final List<ErpModule> modules;
  const ModuleSection(this.title, this.modules);
}

final masterModules = [
  ErpModule(
    title: 'Sundry Creditor', icon: Icons.account_balance_wallet_rounded,
    endpoint: ApiConfig.vendorList, params: {'type': 'creditor'},
    detailEndpoint: ApiConfig.vendorById, idKey: 'ledgerId',
    columns: [
      ColumnDef('ledgerCode', 'Code'),
      ColumnDef('ledgerName', 'Party Name', isTitle: true),
      ColumnDef('categoryName', 'Category', isSubtitle: true),
      ColumnDef('whatsappNumber', 'Mobile'),
    ],
  ),
  ErpModule(
    title: 'Sundry Debtor', icon: Icons.person_outline_rounded,
    endpoint: ApiConfig.vendorList, params: {'type': 'debtor'},
    detailEndpoint: ApiConfig.vendorById, idKey: 'ledgerId',
    columns: [
      ColumnDef('ledgerCode', 'Code'),
      ColumnDef('ledgerName', 'Name', isTitle: true),
      ColumnDef('whatsappNumber', 'Mobile', isSubtitle: true),
    ],
  ),
  ErpModule(
    title: 'Supplier', icon: Icons.local_shipping_rounded,
    endpoint: ApiConfig.supplierList,
    detailEndpoint: ApiConfig.supplierById, idKey: 'supplierId',
    columns: [
      ColumnDef('supplierCode', 'Code'),
      ColumnDef('supplierName', 'Name', isTitle: true),
      ColumnDef('mobileNumber', 'Mobile', isSubtitle: true),
    ],
  ),
  ErpModule(
    title: 'Item Code', icon: Icons.inventory_2_rounded,
    endpoint: ApiConfig.itemList,
    detailEndpoint: ApiConfig.itemById, idKey: 'itemId',
    columns: [
      ColumnDef('itemCode', 'Code'),
      ColumnDef('itemName', 'Item Name', isTitle: true),
      ColumnDef('categoryName', 'Category', isSubtitle: true),
      ColumnDef('unit', 'Unit'),
    ],
  ),
  ErpModule(
    title: 'Asset Code', icon: Icons.precision_manufacturing_rounded,
    endpoint: ApiConfig.assetList,
    detailEndpoint: ApiConfig.assetById, idKey: 'assetId',
    columns: [
      ColumnDef('assetCode', 'Code'),
      ColumnDef('assetName', 'Asset Name', isTitle: true),
      ColumnDef('assetType', 'Type', isSubtitle: true),
    ],
  ),
  ErpModule(
    title: 'Bank & Cash', icon: Icons.account_balance_rounded,
    endpoint: ApiConfig.bankCashList,
    detailEndpoint: ApiConfig.bankCashById, idKey: 'id',
    columns: [
      ColumnDef('code', 'Code'),
      ColumnDef('name', 'Account Name', isTitle: true),
      ColumnDef('type', 'Type', isSubtitle: true, isBadge: true),
      ColumnDef('bankName', 'Bank'),
    ],
  ),
  ErpModule(
    title: 'Cost Center', icon: Icons.account_tree_rounded,
    endpoint: ApiConfig.ccCodeList,
    columns: [
      ColumnDef('ccCode', 'CC Code'),
      ColumnDef('ccName', 'CC Name', isTitle: true),
      ColumnDef('projectCode', 'Project', isSubtitle: true),
    ],
  ),
  ErpModule(
    title: 'Category', icon: Icons.category_rounded,
    endpoint: ApiConfig.categoryList,
    columns: [
      ColumnDef('fixedCode', 'Code'),
      ColumnDef('categoryName', 'Category', isTitle: true),
      ColumnDef('categoryHead', 'Head', isSubtitle: true),
    ],
  ),
  ErpModule(
    title: 'Unit', icon: Icons.straighten_rounded,
    endpoint: ApiConfig.unitList,
    columns: [
      ColumnDef('unitCode', 'Code'),
      ColumnDef('unitName', 'Unit Name', isTitle: true),
      ColumnDef('unitType', 'Type', isSubtitle: true, isBadge: true),
    ],
  ),
  ErpModule(
    title: 'Terms & Conditions', icon: Icons.gavel_rounded,
    endpoint: ApiConfig.termList,
    columns: [
      ColumnDef('termCode', 'Code'),
      ColumnDef('termTitle', 'Title', isTitle: true),
    ],
  ),
];

final projectModules = [
  ErpModule(
    title: 'Projects', icon: Icons.business_center_rounded,
    endpoint: ApiConfig.projectList,
    detailEndpoint: ApiConfig.projectById, idKey: 'id',
    columns: [
      ColumnDef('projectCode', 'Code'),
      ColumnDef('projectName', 'Project Name', isTitle: true),
      ColumnDef('clientName', 'Client', isSubtitle: true),
      ColumnDef('status', 'Status', isBadge: true),
    ],
  ),
  ErpModule(
    title: 'Concrete Registry', icon: Icons.construction_rounded,
    endpoint: ApiConfig.concreteList,
    columns: [
      ColumnDef('registryCode', 'Code'),
      ColumnDef('date', 'Date', isSubtitle: true),
    ],
  ),
  ErpModule(
    title: 'Drawing Register', icon: Icons.architecture_rounded,
    endpoint: ApiConfig.drawingList,
    columns: [
      ColumnDef('drawingNo', 'Drawing No', isTitle: true),
      ColumnDef('revision', 'Rev', isSubtitle: true),
      ColumnDef('status', 'Status', isBadge: true),
    ],
  ),
];

final resourceModules = [
  ErpModule(
    title: 'Machinery', icon: Icons.engineering_rounded,
    endpoint: ApiConfig.machineryList,
    detailEndpoint: ApiConfig.machineryById, idKey: 'id',
    columns: [
      ColumnDef('machineryCode', 'Code'),
      ColumnDef('machineryName', 'Machinery', isTitle: true),
      ColumnDef('type', 'Type', isSubtitle: true),
      ColumnDef('status', 'Status', isBadge: true),
    ],
  ),
  ErpModule(
    title: 'Manpower', icon: Icons.people_rounded,
    endpoint: ApiConfig.manpowerList,
    detailEndpoint: ApiConfig.manpowerById, idKey: 'id',
    columns: [
      ColumnDef('employeeCode', 'Code'),
      ColumnDef('name', 'Name', isTitle: true),
      ColumnDef('designation', 'Designation', isSubtitle: true),
      ColumnDef('status', 'Status', isBadge: true),
    ],
  ),
];

final financeModules = [
  ErpModule(
    title: 'Purchase Bill', icon: Icons.receipt_long_rounded,
    endpoint: ApiConfig.purchaseBillList,
    columns: [
      ColumnDef('billNo', 'Bill No', isTitle: true),
      ColumnDef('vendorName', 'Vendor', isSubtitle: true),
      ColumnDef('amount', 'Amount'),
      ColumnDef('date', 'Date'),
    ],
  ),
  ErpModule(
    title: 'Credit Note', icon: Icons.add_card_rounded,
    endpoint: ApiConfig.creditNoteList,
    columns: [
      ColumnDef('noteNo', 'Note No', isTitle: true),
      ColumnDef('partyName', 'Party', isSubtitle: true),
      ColumnDef('amount', 'Amount'),
    ],
  ),
  ErpModule(
    title: 'Debit Note', icon: Icons.remove_circle_outline_rounded,
    endpoint: ApiConfig.debitNoteList,
    columns: [
      ColumnDef('noteNo', 'Note No', isTitle: true),
      ColumnDef('partyName', 'Party', isSubtitle: true),
      ColumnDef('amount', 'Amount'),
    ],
  ),
  ErpModule(
    title: 'Contra', icon: Icons.swap_horiz_rounded,
    endpoint: ApiConfig.contraList,
    columns: [
      ColumnDef('contraNo', 'Contra No', isTitle: true),
      ColumnDef('amount', 'Amount', isSubtitle: true),
      ColumnDef('date', 'Date'),
    ],
  ),
  ErpModule(
    title: 'GIN', icon: Icons.output_rounded,
    endpoint: ApiConfig.ginList,
    columns: [
      ColumnDef('ginNo', 'GIN No', isTitle: true),
      ColumnDef('projectName', 'Project', isSubtitle: true),
      ColumnDef('date', 'Date'),
    ],
  ),
  ErpModule(
    title: 'Indent', icon: Icons.list_alt_rounded,
    endpoint: ApiConfig.indentList,
    columns: [
      ColumnDef('indentNo', 'Indent No', isTitle: true),
      ColumnDef('projectName', 'Project', isSubtitle: true),
      ColumnDef('status', 'Status', isBadge: true),
    ],
  ),
];

final settingsModules = [
  ErpModule(
    title: 'Users', icon: Icons.manage_accounts_rounded,
    endpoint: ApiConfig.userList,
    columns: [
      ColumnDef('username', 'Username', isTitle: true),
      ColumnDef('email', 'Email', isSubtitle: true),
      ColumnDef('role', 'Role', isBadge: true),
    ],
  ),
];

final allSections = [
  ModuleSection('Master', masterModules),
  ModuleSection('Projects', projectModules),
  ModuleSection('Resources', resourceModules),
  ModuleSection('Finance', financeModules),
  ModuleSection('Settings', settingsModules),
];
