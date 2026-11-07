import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

/// UC2 — Connexion (tous les rôles) + comptes de démonstration.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await AuthService.signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _demo(DemoAccount a) async {
    _email.text = a.email;
    _password.text = a.password;
    await _signIn();
  }

  Future<void> _forgot() async {
    final ctrl = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('forgot_password')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: ctx.tr('email')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(ctx.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text(ctx.tr('send'))),
        ],
      ),
    );
    if (email == null || email.trim().isEmpty || !mounted) return;
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) showMessage(context, context.tr('reset_sent'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = _buildForm(context);
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  const Expanded(child: _HeroPanel()),
                  Expanded(child: Center(child: SingleChildScrollView(child: form))),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const _HeroPanel(compact: true),
                    form,
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('welcome_back'),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                    ),
                    const LangToggle(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(context.tr('login_subtitle'), style: const TextStyle(color: ClinovaColors.muted)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: context.tr('email'),
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                  validator: Validators.email(context),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: context.tr('password'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.notEmpty(context),
                  onFieldSubmitted: (_) => _signIn(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _forgot, child: Text(context.tr('forgot_password'))),
                ),
                BusyButton(label: context.tr('login'), icon: Icons.login_rounded, busy: _busy, onPressed: _signIn),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen())),
                  child: Text(context.tr('create_patient_account')),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.badge_outlined, size: 16, color: ClinovaColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr('staff_login_hint'),
                        style: const TextStyle(fontSize: 12, color: ClinovaColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _DemoSection(onPick: _busy ? null : _demo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: compact ? null : const BoxConstraints.expand(),
      padding: EdgeInsets.fromLTRB(24, compact ? 28 : 48, 24, compact ? 28 : 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ClinovaColors.primaryDark, ClinovaColors.primary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          const ClinovaLogo(size: 36, light: true),
          SizedBox(height: compact ? 16 : 28),
          Text(
            context.tr('hero_title'),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 22 : 34,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('hero_subtitle'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: compact ? 14 : 16, height: 1.4),
          ),
          if (!compact) ...[
            const SizedBox(height: 28),
            _bullet(Icons.schedule_rounded, context.tr('hero_hours')),
            _bullet(Icons.block_rounded, context.tr('friday_closed')),
            _bullet(Icons.timer_outlined, context.tr('hero_slots')),
          ],
        ],
      ),
    );
  }

  Widget _bullet(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: ClinovaColors.sand, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
          ],
        ),
      );
}

/// Section "Mode démo" : connexion en un clic avec un compte de chaque rôle.
class _DemoSection extends StatelessWidget {
  const _DemoSection({required this.onPick});
  final ValueChanged<DemoAccount>? onPick;

  IconData _icon(String role) => switch (role) {
        'admin' => Icons.admin_panel_settings_outlined,
        'receptionist' => Icons.support_agent_rounded,
        'doctor' => Icons.medical_services_outlined,
        _ => Icons.person_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Repo.bootstrapDoc.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data != null && data['showDemoLogins'] == false) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF2D3A6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, color: ClinovaColors.sand),
                  const SizedBox(width: 8),
                  Text(context.tr('demo_mode'), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              Text(context.tr('demo_hint'), style: const TextStyle(fontSize: 12, color: ClinovaColors.muted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in DemoData.all)
                    ActionChip(
                      avatar: Icon(_icon(a.role), size: 18),
                      label: Text('${context.tr(UserRole.fromValue(a.role).trKey)} · ${a.fullName}'),
                      onPressed: onPick == null ? null : () => onPick!(a),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
