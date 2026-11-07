import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/clinic_time.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';

/// UC10 — Enregistrer / gérer un médecin (Réceptionniste, Administrateur).
class DoctorFormScreen extends StatefulWidget {
  const DoctorFormScreen({super.key, required this.viewer, this.doctor});
  final UserProfile viewer;
  final Doctor? doctor;

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _password = TextEditingController();
  late String _spec;
  late bool _active;
  bool _createLogin = true;
  bool _defaultSchedule = true;
  bool _busy = false;

  bool get _isEdit => widget.doctor != null;
  bool get _isAdmin => widget.viewer.role == UserRole.administrator;

  @override
  void initState() {
    super.initState();
    final d = widget.doctor;
    _name = TextEditingController(text: d?.fullName ?? '');
    _phone = TextEditingController(text: d?.phone ?? '');
    _email = TextEditingController(text: d?.email ?? '');
    _spec = d?.specialization ?? Specializations.keys.first;
    if (!Specializations.keys.contains(_spec)) _spec = Specializations.keys.first;
    _active = d?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim().toLowerCase();
    final lang = context.lang;
    try {
      if (_isEdit) {
        final d = widget.doctor!;
        final batch = Repo.db.batch();
        batch.update(Repo.doctors.doc(d.doctorId), {
          'fullName': name,
          'specialization': _spec,
          'phone': phone,
          if (d.userUid == null) 'email': email.isEmpty ? null : email,
          'isActive': _active,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (d.userUid != null) {
          batch.update(Repo.users.doc(d.userUid), {
            'fullName': name,
            'phone': phone,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } else {
        final ref = Repo.doctors.doc();
        String? uid;
        if (_createLogin) {
          uid = await AccountService.createAuthAccount(email: email, password: _password.text);
        }
        final batch = Repo.db.batch();
        batch.set(ref, {
          'doctorId': ref.id,
          'fullName': name,
          'specialization': _spec,
          'phone': phone,
          'email': email.isEmpty ? null : email,
          'userUid': uid,
          'isActive': _active,
          'createdByUid': widget.viewer.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (uid != null) {
          batch.set(Repo.users.doc(uid), {
            'uid': uid,
            'fullName': name,
            'email': email,
            'phone': phone,
            'role': UserRole.doctor.value,
            'doctorId': ref.id,
            'isActive': true,
            'language': lang,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        if (_isAdmin && _defaultSchedule) {
          for (final day in ClinicTime.workWeekOrder) {
            for (final block in DemoData.defaultBlocks) {
              batch.set(
                Repo.schedules.doc(),
                DoctorSchedule.toMap(
                  doctorId: ref.id,
                  dayOfWeek: day,
                  startMinutes: block[0],
                  endMinutes: block[1],
                  isAvailable: true,
                ),
              );
            }
          }
        }
        await batch.commit();
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
    final hasLogin = widget.doctor?.userUid != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_isEdit ? 'edit_doctor' : 'register_doctor')),
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
                decoration: InputDecoration(labelText: context.tr('full_name'), hintText: 'Dr …'),
                validator: Validators.notEmpty(context),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _spec,
                decoration: InputDecoration(labelText: context.tr('specialization')),
                items: [
                  for (final s in Specializations.keys)
                    DropdownMenuItem(value: s, child: Text(context.tr(Specializations.trKey(s)))),
                ],
                onChanged: (v) => setState(() => _spec = v ?? _spec),
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
                enabled: !hasLogin,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: context.tr((!_isEdit && _createLogin) ? 'email' : 'email_optional'),
                  helperText: hasLogin ? context.tr('email_locked') : null,
                ),
                validator: hasLogin ? null : Validators.email(context, optional: _isEdit || !_createLogin),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(context.tr('doctor_active')),
                subtitle: Text(context.tr('doctor_active_hint'),
                    style: const TextStyle(color: ClinovaColors.muted, fontSize: 12)),
              ),
              if (!_isEdit) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _createLogin,
                  onChanged: (v) => setState(() => _createLogin = v),
                  title: Text(context.tr('create_doctor_login')),
                ),
                if (_createLogin)
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: context.tr('initial_password')),
                    validator: Validators.password(context),
                  ),
                if (_isAdmin)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _defaultSchedule,
                    onChanged: (v) => setState(() => _defaultSchedule = v ?? true),
                    title: Text(context.tr('apply_default_schedule')),
                    subtitle: Text(context.tr('default_schedule_desc'),
                        style: const TextStyle(color: ClinovaColors.muted, fontSize: 12)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(context.tr('schedule_by_admin_note'),
                        style: const TextStyle(color: ClinovaColors.muted, fontSize: 12)),
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
