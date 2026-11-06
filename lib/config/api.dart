class ApiConfig {
  // Change this to your deployed backend URL
  static const String baseUrl = 'https://132.154.156.82/api';

  static const String login       = '/auth/login';
  static const String me          = '/auth/me';

  // Master
  static const String vendorList  = '/master/ledger/list';
  static const String vendorById  = '/master/ledger';     // + /{id}
  static const String itemList    = '/master/item/list';
  static const String itemById    = '/master/item';
  static const String assetList   = '/master/asset/list';
  static const String assetById   = '/master/asset';
  static const String ccCodeList  = '/master/cc-code/list';
  static const String unitList    = '/master/unit/list';
  static const String categoryList= '/master/category/list';
  static const String termList    = '/master/term/list';
  static const String bankCashList= '/master/bank-cash/list';
  static const String bankCashById= '/master/bank-cash';
  static const String supplierList= '/master/supplier/list';
  static const String supplierById= '/master/supplier';

  // Settings / Projects
  static const String projectList = '/setting/project-list';
  static const String projectById = '/setting/project';
  static const String userList    = '/setting/user-list';

  // Resources
  static const String machineryList  = '/resources/machinery/list';
  static const String machineryById  = '/resources/machinery';
  static const String manpowerList   = '/resources/manpower/list';
  static const String manpowerById   = '/resources/manpower';

  // Project Mgmt
  static const String concreteList  = '/project-mgmt/concrete-registry/list';
  static const String drawingList   = '/project-mgmt/drawing-register/list';

  // Finance
  static const String purchaseBillList = '/finance/purchase-bill/list';
  static const String creditNoteList   = '/finance/credit-note/list';
  static const String debitNoteList    = '/finance/debit-note/list';
  static const String contraList       = '/finance/contra/list';
  static const String ginList          = '/finance/gin/list';
  static const String indentList       = '/finance/indent/list';
}
