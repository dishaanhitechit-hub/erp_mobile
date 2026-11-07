import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../modules/modules_screen.dart';
import '../profile/profile_screen.dart';
import '../project/project_picker.dart';
import '../search/search_screen.dart';
import '../comm/comm_screen.dart';
import '../../services/comm_notifier.dart';

/// Bottom-nav shell (PhonePe layout: 4 tabs + raised centre action).
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // First launch after login: ask for the working project.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ApiService.instance.projectCode == null && mounted) {
        showProjectPicker(context);
      }
    });
    // Unread badges + phone notifications for pings/messages from web or other phones
    CommNotifier.instance.start();
    CommNotifier.instance.openComm.addListener(_openComm);
  }

  @override
  void dispose() {
    CommNotifier.instance.openComm.removeListener(_openComm);
    super.dispose();
  }

  void _openComm() {
    if (mounted) setState(() => _tab = 2);
  }

  void _openSearch() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const Scaffold(body: SearchScreen())),
      );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onSearch: _openSearch),
      const ModulesScreen(),
      const CommScreen(),
      const ProfileScreen(),
    ];
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(index: _tab, children: pages),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: SizedBox(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            elevation: 4,
            shape: const CircleBorder(),
            backgroundColor: AppColors.accent,
            onPressed: () => showProjectPicker(context),
            child: const Icon(Icons.swap_horiz_rounded,
                color: Colors.white, size: 28),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: AppColors.bgCard,
          elevation: 12,
          shadowColor: AppColors.accentDark.withValues(alpha: 0.3),
          shape: const CircularNotchedRectangle(),
          notchMargin: 7,
          padding: EdgeInsets.zero,
          height: 66,
          child: Row(
            children: [
              _item(0, Icons.home_rounded, 'Home'),
              _item(1, Icons.grid_view_rounded, 'Modules'),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 34),
                  child: Text('Project',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: CommNotifier.instance,
                  builder: (_, __) => _itemBody(2, Icons.forum_rounded, 'Chats',
                      badge: CommNotifier.instance.total),
                ),
              ),
              _item(3, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, IconData icon, String label) =>
      Expanded(child: _itemBody(i, icon, label));

  Widget _itemBody(int i, IconData icon, String label, {int badge = 0}) {
    final sel = _tab == i;
    final c = sel ? AppColors.accent : AppColors.textMuted;
    return InkWell(
      onTap: () {
        setState(() => _tab = i);
        // Pick up a profile photo added/changed elsewhere (e.g. on the web).
        if (i == 0 || i == 3) ApiService.instance.refreshMe();
        if (i == 2) CommNotifier.instance.check();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              child: Icon(icon, color: c, size: 23),
            ),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: c,
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
