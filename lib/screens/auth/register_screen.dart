import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

/// UC1 — Inscription d'un patient.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _dob, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dob.text) ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob.text = Fmt.isoDate(picked));
  }

  Future<void> _register() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final lang = context.lang;
    final navigator = Navigator.of(context);
    try {
      await AuthService.registerPatient(
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        dateOfBirth: _dob.text.trim().isEmpty ? null : _dob.text.trim(),
        language: lang,
      );
      // Connecté automatiquement : on revient à la racine (espace patient).
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('register')), actions: const [LangToggle()]),
      body: ResponsiveBody(
        maxWidth: 520,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(context.tr('register_subtitle'), style: const TextStyle(color: ClinovaColors.muted)),
              const SizedBox(height: 20),
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
                decoration: InputDecoration(labelText: context.tr('phone'), hintText: '+253 77 …'),
                validator: Validators.phone(context),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: context.tr('password')),
                validator: Validators.password(context),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: context.tr('confirm_password')),
                validator: (v) => v != _password.text ? context.tr('v_password_match') : null,
              ),
              const SizedBox(height: 24),
              BusyButton(label: context.tr('create_account'), icon: Icons.person_add_rounded, busy: _busy, onPressed: _register),
            ],
          ),
        ),
      ),
    );
  }
}
