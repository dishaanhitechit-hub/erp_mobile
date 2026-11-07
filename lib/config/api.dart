class ApiConfig {
  // Same backend as erp-frontend (src/config/api.config.js)
  static const String baseUrl = 'https://132.154.156.82/api';

  static const String login        = '/auth/login';
  static const String projectList  = '/setting/project-list';
  static const String enterProject = '/project/enter'; // + /{projectCode}
  static const String me           = '/auth/me';
  static const String userFile     = '/auth/user-file'; // + /{userId}/profile
}
