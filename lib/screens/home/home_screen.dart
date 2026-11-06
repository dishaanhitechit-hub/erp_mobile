import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/module.dart';
import '../common/list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _sections = allSections;

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final section = sections[_tab];
    final user = ApiService.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: AppTheme.bgGradient,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(user),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _ModuleCard(
                            module: section.modules[i],
                            colorIndex: i,
                            onTap: () => Navigator.push(ctx, MaterialPageRoute(
                              builder: (_) => ListScreen(module: section.modules[i]),
                            )),
                          ),
                          childCount: section.modules.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(sections),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? user) {
    final name = user?['name'] ?? user?['username'] ?? 'User';
    final role = user?['role'] ?? 'Staff';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF1A6FD4)]),
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 12)],
            ),
            child: Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(role.toString().toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.8)),
              ],
            ),
          ),
          _buildIconBtn(Icons.notifications_outlined, () {}),
          const SizedBox(width: 8),
          _buildIconBtn(Icons.logout_rounded, () async {
            await ApiService.instance.logout();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          }),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: AppTheme.glassCard(radius: 12),
      child: Icon(icon, color: AppColors.textSecondary, size: 20),
    ),
  );

  Widget _buildBottomNav(List<ModuleSection> sections) {
    final icons = [
      Icons.dashboard_rounded,
      Icons.business_center_rounded,
      Icons.engineering_rounded,
      Icons.receipt_rounded,
      Icons.settings_rounded,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: List.generate(sections.length, (i) => BottomNavigationBarItem(
          icon: Icon(icons[i], size: 22),
          label: sections[i].title,
        )),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final ErpModule module;
  final int colorIndex;
  final VoidCallback onTap;

  const _ModuleCard({required this.module, required this.colorIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.moduleColors[colorIndex % AppColors.moduleColors.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.glassCard(radius: 18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.3), width: 1),
                ),
                child: Icon(module.icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                module.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
