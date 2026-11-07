import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/clinic_time.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/demo_service.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';

/// Profil, langue, informations de la clinique, réglages démo (admin) et déconnexion.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _demoBusy = false;

  Future<void> _edit() async {
    final name = TextEditingController(text: widget.viewer.fullName);
    final phone = TextEditingController(text: widget.viewer.phone);
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('edit_profile')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: InputDecoration(labelText: ctx.tr('full_name')),
                validator: Validators.notEmpty(ctx),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                decoration: InputDecoration(labelText: ctx.tr('phone')),
                validator: Validators.phone(ctx),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.of(ctx).pop(true);
            },
            child: Text(ctx.tr('save')),
          ),
        ],
      ),
    );
    final newName = name.text;
    final newPhone = phone.text;
    if (ok != true || !mounted) return;
    try {
      await AuthService.updateOwnProfile(uid: widget.viewer.uid, fullName: newName, phone: newPhone);
      if (mounted) showMessage(context, context.tr('saved'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('change_password')),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration: InputDecoration(labelText: ctx.tr('current_password')),
                  validator: Validators.notEmpty(ctx),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: InputDecoration(labelText: ctx.tr('new_password')),
                  validator: Validators.password(ctx),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration: InputDecoration(labelText: ctx.tr('confirm_password')),
                  validator: (v) => v != next.text ? ctx.tr('v_password_match') : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.of(ctx).pop(true);
            },
            child: Text(ctx.tr('save')),
          ),
        ],
      ),
    );
    final currentPwd = current.text;
    final newPwd = next.text;
    if (ok != true || !mounted) return;
    try {
      await AuthService.changePassword(current: currentPwd, next: newPwd);
      if (mounted) showMessage(context, context.tr('password_changed'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _recreateDemo() async {
    setState(() => _demoBusy = true);
    try {
      await DemoService.ensureDemoAccounts();
      if (mounted) showMessage(context, context.tr('demo_recreated'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _demoBusy = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await confirmDialog(context, title: context.tr('logout'), message: context.tr('logout_confirm'));
    if (!ok || !mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.viewer;
    final isAdmin = u.role == UserRole.administrator;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                InitialsAvatar(u.fullName, radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(u.email, style: const TextStyle(color: ClinovaColors.muted)),
                      Text(u.phone, style: const TextStyle(color: ClinovaColors.muted)),
                      const SizedBox(height: 6),
                      RoleChip(u.role),
                    ],
                  ),
                ),
                IconButton(tooltip: context.tr('edit'), onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
              ],
            ),
          ),
        ),
        SectionTitle(context.tr('security')),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_reset_rounded),
            title: Text(context.tr('change_password')),
            subtitle: Text(context.tr('change_password_desc')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _changePassword,
          ),
        ),
        SectionTitle(context.tr('language')),
        Card(
          child: ListTile(
            leading: const Icon(Icons.translate_rounded),
            title: Text(context.tr('language_desc')),
            trailing: const LangToggle(),
          ),
        ),
        SectionTitle(context.tr('clinic_info')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.local_hospital_outlined),
                title: const Text('Clinova'),
                subtitle: Text(context.tr('hero_hours')),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(context.tr('friday_closed')),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.public_rounded),
                title: Text(context.tr('time_zone')),
                subtitle: const Text(ClinicTime.timeZoneName),
              ),
            ],
          ),
        ),
        if (kIsWeb) ...[
          SectionTitle(context.tr('install_app')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(context.tr('install_iphone_title')),
              subtitle: Text(context.tr('install_iphone_steps')),
            ),
          ),
        ],
        if (isAdmin) ...[
          SectionTitle(context.tr('demo_settings')),
          Card(
            child: Column(
              children: [
                StreamBuilder(
                  stream: Repo.bootstrapDoc.snapshots(),
                  builder: (context, snap) {
                    final show = snap.data?.data()?['showDemoLogins'] != false;
                    return SwitchListTile(
                      secondary: const Icon(Icons.play_circle_outline_rounded),
                      title: Text(context.tr('show_demo_logins')),
                      subtitle: Text(context.tr('show_demo_logins_desc')),
                      value: show,
                      onChanged: (v) async {
                        try {
                          await Repo.bootstrapDoc.update({'showDemoLogins': v});
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: _demoBusy
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  title: Text(context.tr('recreate_demo')),
                  subtitle: Text(context.tr('recreate_demo_desc')),
                  onTap: _demoBusy ? null : _recreateDemo,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: ClinovaColors.cancelled),
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(context.tr('logout')),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text('Clinova v1.0.0', style: TextStyle(color: ClinovaColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}
