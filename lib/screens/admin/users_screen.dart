import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';

/// UC15 — Gérer les utilisateurs (Administrateur).
/// Créer des comptes du personnel, activer / désactiver, changer un rôle
/// (Réceptionniste <-> Administrateur). Impossible de modifier son propre rôle.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  UserRole? _filter;
  String _query = '';
  final Stream<List<UserProfile>> _stream = Repo.usersStream();

  Future<void> _setActive(UserProfile u, bool active) async {
    try {
      await Repo.users.doc(u.uid).update({'isActive': active, 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) showMessage(context, context.tr(active ? 'user_activated' : 'user_deactivated'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _changeRole(UserProfile u, UserRole role) async {
    final ok = await confirmDialog(
      context,
      title: context.tr('change_role'),
      message: context.tr('change_role_confirm', {'name': u.fullName, 'role': context.tr(role.trKey)}),
    );
    if (!ok) return;
    try {
      await Repo.users.doc(u.uid).update({'role': role.value, 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) showMessage(context, context.tr('saved'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-staff',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const StaffFormScreen(),
        )),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(context.tr('create_staff')),
      ),
      body: StreamBuilder<List<UserProfile>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          final q = _query.trim().toLowerCase();
          final list = snap.data!.where((u) {
            if (_filter != null && u.role != _filter) return false;
            return q.isEmpty || u.fullName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
          }).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: context.tr('search_user'),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(context.tr('all')),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    for (final r in UserRole.values) ...[
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text(context.tr(r.trKey)),
                        selected: _filter == r,
                        onSelected: (_) => setState(() => _filter = r),
                      ),
                    ],
                  ],
                ),
              ),
              SectionTitle(context.tr('users_count', {'n': '${list.length}'})),
              for (final u in list) ...[
                _userCard(context, u),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _userCard(BuildContext context, UserProfile u) {
    final isMe = u.uid == widget.viewer.uid;
    final canSwitchRole = !isMe && u.role.isStaff;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            InitialsAvatar(u.fullName, color: u.isActive ? ClinovaColors.primary : ClinovaColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          u.fullName + (isMe ? ' (${context.tr('you')})' : ''),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RoleChip(u.role),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(u.email, style: const TextStyle(color: ClinovaColors.muted, fontSize: 13)),
                  if (!u.isActive)
                    Text(context.tr('inactive'),
                        style: const TextStyle(color: ClinovaColors.cancelled, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (!isMe)
              Tooltip(
                message: context.tr(u.isActive ? 'deactivate' : 'activate'),
                child: Switch(value: u.isActive, onChanged: (v) => _setActive(u, v)),
              ),
            if (canSwitchRole)
              PopupMenuButton<UserRole>(
                tooltip: context.tr('change_role'),
                onSelected: (r) => _changeRole(u, r),
                itemBuilder: (_) => [
                  for (final r in [UserRole.receptionist, UserRole.administrator])
                    if (r != u.role)
                      PopupMenuItem(value: r, child: Text('${context.tr('make')} ${context.tr(r.trKey)}')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Création d'un compte du personnel (Réceptionniste ou Administrateur).
class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key});

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.receptionist;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final lang = context.lang;
    try {
      final email = _email.text.trim().toLowerCase();
      final uid = await AccountService.createAuthAccount(email: email, password: _password.text);
      await Repo.users.doc(uid).set({
        'uid': uid,
        'fullName': _name.text.trim(),
        'email': email,
        'phone': _phone.text.trim(),
        'role': _role.value,
        'isActive': true,
        'language': lang,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      showMessage(context, context.tr('saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('create_staff')), actions: const [LangToggle()]),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<UserRole>(
                segments: [
                  ButtonSegment(
                    value: UserRole.receptionist,
                    label: Text(context.tr(UserRole.receptionist.trKey)),
                    icon: const Icon(Icons.support_agent_rounded),
                  ),
                  ButtonSegment(
                    value: UserRole.administrator,
                    label: Text(context.tr(UserRole.administrator.trKey)),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 8),
              Text(context.tr('doctor_accounts_note'),
                  style: const TextStyle(fontSize: 12, color: ClinovaColors.muted)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: context.tr('full_name')),
                validator: Validators.notEmpty(context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: context.tr('email')),
                validator: Validators.email(context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: context.tr('phone')),
                validator: Validators.phone(context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: context.tr('initial_password')),
                validator: Validators.password(context),
              ),
              const SizedBox(height: 24),
              BusyButton(label: context.tr('create_account'), icon: Icons.check_rounded, busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
