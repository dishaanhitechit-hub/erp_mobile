class ApiConfig {
  // Same backend as erp-frontend (src/config/api.config.js)
  // Overridable for local testing only: --dart-define=ERP_API=http://10.0.2.2:5099
  static const String baseUrl = String.fromEnvironment('ERP_API', defaultValue: 'https://132.154.156.82/api');

  /// Web ERP (print pages live at $webUrl/print/<doc>/<uuid>).
  static const String webUrl = String.fromEnvironment('ERP_WEB', defaultValue: 'https://132.154.156.82');

  static const String login        = '/auth/login';
  static const String projectList  = '/setting/project-list';
  static const String enterProject = '/project/enter'; // + /{projectCode}
  static const String me           = '/auth/me';
  static const String userFile     = '/auth/user-file'; // + /{userId}/profile
}
