import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/common.dart';
import '../staff/patient_form_screen.dart';
import 'doctor_picker_screen.dart';

/// UC14 — Informations patient.
/// * Médecin : uniquement les informations minimales issues de SES rendez-vous
///   (aucun accès à la collection patients : voir firestore.rules).
/// * Réceptionniste / Administrateur : dossier complet + historique.
class PatientInfoScreen extends StatelessWidget {
  const PatientInfoScreen({
    super.key,
    required this.patientId,
    required this.viewer,
    this.fromAppointment,
  });

  final String patientId;
  final UserProfile viewer;
  final Appointment? fromAppointment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('patient_info')), actions: const [LangToggle()]),
      body: ResponsiveBody(
        child: viewer.role == UserRole.doctor ? _doctorView(context) : _staffView(context),
      ),
    );
  }

  Widget _infoCard(BuildContext context, {
    required String name,
    String? phone,
    String? email,
    String? dob,
    bool hasAccount = false,
    Widget? trailing,
  }) {
    Widget row(IconData icon, String label, String? value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: ClinovaColors.muted),
              const SizedBox(width: 10),
              SizedBox(width: 120, child: Text(label, style: const TextStyle(color: ClinovaColors.muted))),
              Expanded(child: Text(value == null || value.isEmpty ? '—' : value)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            row(Icons.phone_rounded, context.tr('phone'), phone),
            if (email != null || viewer.role != UserRole.doctor) row(Icons.mail_outline_rounded, context.tr('email'), email),
            row(Icons.cake_outlined, context.tr('date_of_birth'), dob),
            if (viewer.role != UserRole.doctor)
              row(Icons.verified_user_outlined, context.tr('online_account'), context.tr(hasAccount ? 'yes' : 'no')),
          ],
        ),
      ),
    );
  }

  static String? _formatDob(String? iso) {
    if (iso == null) return null;
    final d = DateTime.tryParse(iso);
    return d == null ? iso : Fmt.simpleDate(d);
  }

  Widget _doctorView(BuildContext context) {
    final doctorId = viewer.doctorId ?? '';
    return StreamBuilder<List<Appointment>>(
      stream: Repo.appointmentsForDoctor(doctorId),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (!snap.hasData) return const LoadingView();
        final history = snap.data!.where((a) => a.patientId == patientId).toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
        if (history.isEmpty) {
          // Patient sans lien avec ce médecin : accès refusé.
          return EmptyState(icon: Icons.lock_outline_rounded, message: context.tr('err_patient_privacy'));
        }
        final latest = fromAppointment ?? history.first;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _infoCard(
              context,
              name: latest.patientName,
              phone: latest.patientPhone,
              dob: _formatDob(latest.patientDateOfBirth),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(context.tr('doctor_privacy_note'),
                  style: const TextStyle(fontSize: 12, color: ClinovaColors.muted)),
            ),
            SectionTitle(context.tr('history_with_you')),
            for (final a in history) ...[
              AppointmentCard(appointment: a, viewer: viewer),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _staffView(BuildContext context) {
    return StreamBuilder<Patient?>(
      stream: Repo.patientStream(patientId),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return const LoadingView();
        final p = snap.data;
        if (p == null) return EmptyState(icon: Icons.person_off_outlined, message: context.tr('err_not_found'));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _infoCard(
              context,
              name: p.fullName,
              phone: p.phone,
              email: p.email,
              dob: _formatDob(p.dateOfBirth),
              hasAccount: p.hasAccount,
              trailing: IconButton(
                tooltip: context.tr('edit'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PatientFormScreen(viewer: viewer, patient: p),
                )),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => DoctorPickerScreen(viewer: viewer, patientId: p.patientId),
              )),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('book_for_patient')),
            ),
            SectionTitle(context.tr('appointment_history')),
            StreamBuilder<List<Appointment>>(
              stream: Repo.appointmentsForPatientId(p.patientId),
              builder: (context, aSnap) {
                if (aSnap.hasError) return ErrorView(error: aSnap.error);
                if (!aSnap.hasData) return const LoadingView();
                final list = aSnap.data!;
                if (list.isEmpty) {
                  return EmptyState(icon: Icons.event_note_rounded, message: context.tr('no_appointments'));
                }
                return Column(
                  children: [
                    for (final a in list) ...[
                      AppointmentCard(appointment: a, viewer: viewer),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
