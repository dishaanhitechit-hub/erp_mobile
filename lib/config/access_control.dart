// ─────────────────────────────────────────────────────────────────────────────
//  ACCESS CONTROL — the one place that decides what a user sees and can do.
//
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │  useRbac   = true   →  each user sees ONLY the modules their role    │
//  │                        and project permissions allow (like the web). │
//  │             false   →  everyone sees every module.                   │
//  │                                                                      │
//  │  allowEdit = false  →  every visible module is VIEW-ONLY (for now).  │
//  │             true    →  modules with EDIT permission become editable. │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  RBAC rules (mirror erp-frontend AppSidebar.jsx, getPageAccess.js,
//  getMasterAccess.js and routeAccess.js):
//
//    Role "super_admin" → Settings: edit · Master: view · everything else hidden
//    Role "admin"       → Master: edit  · everything else hidden
//    Role "user"        → Settings hidden · Master: view
//                         every other module is looked up in the permissions
//                         returned by POST /project/enter/{code}:
//                           "<key>.EDIT"     → edit
//                           "<key>.VIEW"     → view
//                           "<key>.APPROVER" → view (+ canApprove)
//                           none of them     → hidden
//                         No project selected → no permissions → only Master.
//
//  `overrides` always wins — use it to force one module, e.g.
//        'indent': AccessLevel.edit,
//        'payroll': AccessLevel.hidden,
// ─────────────────────────────────────────────────────────────────────────────

enum AccessLevel { hidden, view, edit }

class AccessControl {
  AccessControl._();

  // ── Switches ─────────────────────────────────────────────────────────────

  /// Role/permission based visibility. On: users only see what they're allowed.
  static const bool useRbac = true;

  /// Editing on mobile. Off: everything the user can see is view-only.
  /// Turn on once the add/edit forms exist in the app.
  static const bool allowEdit = false;

  /// Modules whose add/edit screens already exist in the app. These keep the
  /// user's real EDIT permission even while [allowEdit] is off.
  static const Set<String> editableOnMobile = {'daily_progress_report'};

  /// Level for every module when [useRbac] is off.
  static const AccessLevel defaultLevel = AccessLevel.view;

  /// Per-module overrides, keyed by module key. Always wins.
  static const Map<String, AccessLevel> overrides = {
    // 'indent': AccessLevel.edit,
  };

  // ── Session state (filled by ApiService) ────────────────────────────────

  /// Role from /auth/login: "super_admin", "admin" or "user".
  static String role = '';

  /// Permissions from /project/enter, e.g. {"indent.VIEW": true, ...}.
  static Map<String, dynamic> get serverPermissions => _perms;
  static set serverPermissions(Map<String, dynamic> p) {
    _perms = p;
    _upper = {for (final e in p.entries) e.key.toUpperCase(): e.value};
  }

  static Map<String, dynamic> _perms = {};
  static Map<String, dynamic> _upper = {};

  // ── Lookups ──────────────────────────────────────────────────────────────

  /// [key] is the module's unique key; [permissionKey] is the web
  /// permissionKey (usually the same); [section] is the navbar section key.
  static AccessLevel levelFor(String key, {String? permissionKey, String? section}) {
    final forced = overrides[key];
    if (forced != null) return forced;
    final level = useRbac ? realLevel(permissionKey ?? key, section) : defaultLevel;
    if (!allowEdit && level == AccessLevel.edit && !editableOnMobile.contains(key)) return AccessLevel.view;
    return level;
  }

  /// Approver rights ("<key>.APPROVER").
  static bool canApprove(String permissionKey) =>
      useRbac && _has('$permissionKey.APPROVER');

  /// Short label for the profile screen.
  static String get modeLabel => [
        useRbac ? 'Role based' : 'All modules',
        allowEdit ? 'edit as permitted' : 'view only',
      ].join(' • ');

  /// The web frontend's rule for one module (used when the switch is on).
  static AccessLevel realLevel(String permissionKey, String? section) {
    switch (role) {
      case Roles.superAdmin:
        if (section == 'settings') return AccessLevel.edit;
        if (section == 'master') return AccessLevel.view;
        return AccessLevel.hidden;
      case Roles.admin:
        return section == 'master' ? AccessLevel.edit : AccessLevel.hidden;
      default: // general user
        if (section == 'settings') return AccessLevel.hidden;
        if (section == 'master') return AccessLevel.view;
        if (_has('$permissionKey.EDIT')) return AccessLevel.edit;
        if (_has('$permissionKey.VIEW') || _has('$permissionKey.APPROVER')) return AccessLevel.view;
        return AccessLevel.hidden;
    }
  }

  static bool _has(String k) {
    final v = _upper[k.toUpperCase()];
    return v == true || v == 1 || v == 'true';
  }
}

/// Role values as returned by the backend (same as erp-frontend role.config.js).
class Roles {
  static const superAdmin = 'super_admin';
  static const admin = 'admin';
  static const user = 'user';

  static String label(String role) => switch (role) {
        superAdmin => 'Super Admin',
        admin => 'Admin',
        user => 'General User',
        _ => role.replaceAll('_', ' '),
      };
}
