import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final VoidCallback? onTap;
  final List<Color>? gradient;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.onTap,
    this.gradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: AppTheme.glassCard(radius: radius, color: color, gradient: gradient),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusBadge(this.label, {super.key, this.color});

  static Color _colorForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'active': return AppColors.accent2;
      case 'inactive': case 'closed': return AppColors.accent3;
      case 'pending': case 'draft': return AppColors.accent4;
      case 'approved': case 'completed': return AppColors.palette.isDark ? const Color(0xFF8FB3D9) : const Color(0xFF4A6378);
      case 'bank': return const Color(0xFF4A6378);
      case 'cash': return AppColors.accent2;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? _colorForLabel(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }
}

class ShimmerLoader extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const ShimmerLoader({super.key, this.height = 60, this.width, this.radius = 12});

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: [AppColors.shimmerBase, AppColors.shimmerHighlight, AppColors.shimmerBase],
          ),
        ),
      ),
    );
  }
}
