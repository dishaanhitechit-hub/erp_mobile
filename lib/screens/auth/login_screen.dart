import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animCtrl, curve: const Interval(0.2, 1, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.instance.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      if (data['token'] != null || data['access_token'] != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() { _error = data['message'] ?? data['msg'] ?? 'Invalid credentials'; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.bgGradient,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Logo
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      const _FloatingLogo(),
                      const SizedBox(height: 16),
                      Text('PRAX ERP', style: GoogleFonts.playfairDisplay(color: AppColors.textPrimary, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Text('CONSTRUCTION MANAGEMENT SYSTEM', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 2.2)),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Login Card
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: GlassCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back', style: GoogleFonts.playfairDisplay(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Sign in to continue', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          const SizedBox(height: 28),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.accent3.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.accent3.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: AppColors.accent3, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_error!, style: TextStyle(color: AppColors.accent3, fontSize: 13))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildField(
                            controller: _emailCtrl,
                            hint: 'Username or Mobile No.',
                            icon: Icons.person_outline_rounded,
                            type: TextInputType.text,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _passCtrl,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _GlossyButton(
                            onTap: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFFF4E6)))
                                : const Text('Sign In', style: TextStyle(color: Color(0xFFFFF4E6), fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text('Dishaan Hi-tech (India) Pvt. Ltd.', style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.3)),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffix,
      ),
      onSubmitted: (_) => _login(),
    );
  }
}

class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo();
  @override State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
  late final Animation<double> _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, child) {
        final t = _t.value;
        return Column(
          children: [
            Transform.translate(offset: Offset(0, -10 * t), child: child),
            const SizedBox(height: 6),
            Container(
              width: 60 * (1 - 0.25 * t),
              height: 10,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.elliptical(60, 10)),
                gradient: RadialGradient(colors: [
                  AppColors.accentDark.withValues(alpha: 0.32 - 0.14 * t),
                  AppColors.accentDark.withValues(alpha: 0),
                ]),
              ),
            ),
          ],
        );
      },
      child: SizedBox(
        width: 88, height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: AppTheme.glossyBrown(shape: BoxShape.circle).copyWith(
                boxShadow: [BoxShadow(color: AppColors.accentDark.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
              ),
            ),
            Positioned(
              top: 5,
              child: Container(
                width: 60, height: 34,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(60, 34)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Icon(Icons.business_rounded, color: const Color(0xFFFFF4E6), size: 40,
              shadows: [Shadow(color: AppColors.accentDark.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))]),
          ],
        ),
      ),
    );
  }
}

class _GlossyButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _GlossyButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    const radius = 14.0;
    return Opacity(
      opacity: onTap == null ? 0.75 : 1,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: AppTheme.glossyBrown(radius: radius).copyWith(
          boxShadow: [BoxShadow(color: AppColors.accentDark.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 1, left: 1, right: 1, height: 26,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(radius - 1)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.02)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius),
                  onTap: onTap,
                  child: Center(child: child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
