class ApiConfig {
  // Same backend as erp-frontend (src/config/api.config.js)
  static const String baseUrl = 'https://132.154.156.82/api';

  /// Web ERP (print pages live at $webUrl/print/<doc>/<uuid>).
  static const String webUrl = 'https://132.154.156.82';

  static const String login        = '/auth/login';
  static const String projectList  = '/setting/project-list';
  static const String enterProject = '/project/enter'; // + /{projectCode}
  static const String me           = '/auth/me';
  static const String userFile     = '/auth/user-file'; // + /{userId}/profile
}
