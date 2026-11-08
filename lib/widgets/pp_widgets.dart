// PhonePe-style reusable widgets: section cards with icon grids, module tiles,
// headers and the project chip.
import 'package:flutter/material.dart';
import '../services/offline_store.dart';
import '../config/module_registry.dart';
import '../screens/common/module_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

Color colorFor(int i) => AppColors.moduleColors[i % AppColors.moduleColors.length];

/// One icon + label, PhonePe "Transfer Money" style.
class ModuleTile extends StatelessWidget {
  final ErpModule module;
  final Color color;
  const ModuleTile({super.key, required this.module, required this.color});

  @override
  Widget build(BuildContext context) {
    final dim = !module.available;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openModule(context, module),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: dim ? AppColors.inputFill : color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(module.icon, color: dim ? AppColors.textMuted : Colors.white, size: 24),
                ),
                if (dim)
                  Positioned(
                    right: -6, top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.accent4, borderRadius: BorderRadius.circular(6)),
                      child: const Text('SOON', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              module.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dim ? AppColors.textMuted : AppColors.textPrimary,
                fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4-column grid of module tiles.
class ModuleGrid extends StatelessWidget {
  final List<ErpModule> modules;
  final int colorOffset;
  const ModuleGrid({super.key, required this.modules, this.colorOffset = 0});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 4, mainAxisExtent: 96,
      ),
      itemBuilder: (_, i) => ModuleTile(module: modules[i], color: colorFor(i + colorOffset)),
    );
  }
}

/// White rounded card with a title row and optional "View all" action.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry margin;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: AppTheme.sectionCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              if (actionLabel != null)
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(actionLabel!, style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accent),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Brown app bar used by inner screens (PhonePe style solid header).
class PPAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PPAppBar({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.headerGradient),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              if (Navigator.canPop(context))
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              else
                const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                  ],
                ),
              ),
              ...actions,
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}


/// Round avatar for the logged-in user: their profile photo when they have
/// one, otherwise the first letter of their name.
class UserAvatar extends StatelessWidget {
  final double radius;
  const UserAvatar({super.key, this.radius = 21});

  @override
  Widget build(BuildContext context) {
    final api = ApiService.instance;
    final name = api.userName;
    final initial = Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: radius * 0.85),
    );
    final url = api.profilePhotoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.palette.isDark ? AppColors.inputFill : Colors.white,
      child: url == null
          ? initial
          : ClipOval(
              child: Image.network(
                url,
                headers: api.imageHeaders,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => initial,
              ),
            ),
    );
  }
}



/// "Offline copy • saved 2 h ago" line under a header.
class SavedCopyNote extends StatelessWidget {
  final DateTime savedAt;
  const SavedCopyNote({super.key, required this.savedAt});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.offline_pin_rounded, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text('Offline copy • saved ${savedAgo(savedAt)}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      );
}
