import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';

/// UC9 — Enregistrer / modifier un patient (Réceptionniste, Administrateur).
class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, required this.viewer, this.patient});
  final UserProfile viewer;
  final Patient? patient;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _dob;
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;

  bool get _isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _name = TextEditingController(text: p?.fullName ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _dob = TextEditingController(text: p?.dateOfBirth ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _dob.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final initial = DateTime.tryParse(_dob.text) ?? DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob.text = Fmt.isoDate(picked));
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim().toLowerCase();
    final dob = _dob.text.trim().isEmpty ? null : _dob.text.trim();
    try {
      if (_isEdit) {
        final p = widget.patient!;
        final batch = Repo.db.batch();
        batch.update(Repo.patients.doc(p.patientId), {
          'fullName': name,
          'phone': phone,
          if (!p.hasAccount) 'email': email.isEmpty ? null : email,
          'dateOfBirth': dob,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (p.userUid != null) {
          batch.update(Repo.users.doc(p.userUid), {
            'fullName': name,
            'phone': phone,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } else if (_createAccount) {
        final uid = await AccountService.createAuthAccount(email: email, password: _password.text);
        await AuthService.writePatientAccountDocs(
          uid: uid,
          fullName: name,
          email: email,
          phone: phone,
          dateOfBirth: dob,
          createdByUid: widget.viewer.uid,
        );
      } else {
        final ref = Repo.patients.doc();
        await ref.set({
          'patientId': ref.id,
          'userUid': null,
          'fullName': name,
          'phone': phone,
          'email': email.isEmpty ? null : email,
          'dateOfBirth': dob,
          'createdByUid': widget.viewer.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
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
    final hasAccount = widget.patient?.hasAccount ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_isEdit ? 'edit_patient' : 'register_patient')),
        actions: const [LangToggle()],
      ),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: context.tr('full_name')),
                validator: Validators.notEmpty(context),
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
                controller: _email,
                enabled: !hasAccount,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr(_createAccount ? 'email' : 'email_optional'),
                  helperText: hasAccount ? context.tr('email_locked') : null,
                ),
                validator: hasAccount ? null : Validators.email(context, optional: !_createAccount),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dob,
                decoration: InputDecoration(
                  labelText: context.tr('date_of_birth_optional'),
                  hintText: 'AAAA-MM-JJ / YYYY-MM-DD',
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_month_rounded), onPressed: _pickDob),
                ),
                validator: Validators.date(context),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _createAccount,
                  onChanged: (v) => setState(() => _createAccount = v),
                  title: Text(context.tr('create_online_account')),
                  subtitle: Text(context.tr('create_online_account_hint'),
                      style: const TextStyle(color: ClinovaColors.muted, fontSize: 12)),
                ),
                if (_createAccount)
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: context.tr('initial_password')),
                    validator: Validators.password(context),
                  ),
              ],
              const SizedBox(height: 24),
              BusyButton(label: context.tr('save'), icon: Icons.save_rounded, busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
