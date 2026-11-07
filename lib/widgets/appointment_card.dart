import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../screens/shared/book_screen.dart';
import '../screens/shared/patient_info_screen.dart';
import '../services/booking_service.dart';
import '../services/repo.dart';
import 'common.dart';

/// Carte de rendez-vous avec les actions autorisées pour le rôle courant.
class AppointmentCard extends StatefulWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.viewer,
    this.showDate = true,
  });

  final Appointment appointment;
  final UserProfile viewer;
  final bool showDate;

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  bool _busy = false;

  Appointment get a => widget.appointment;
  UserRole get role => widget.viewer.role;

  bool get _canPatientManage => role == UserRole.patient && a.isUpcoming;
  bool get _canStaffManage => role.isStaff && a.isScheduled;
  bool get _canCancel => _canPatientManage || _canStaffManage;
  bool get _canReschedule => _canPatientManage || _canStaffManage;
  bool get _canComplete =>
      a.isScheduled && (role.isStaff || (role == UserRole.doctor && widget.viewer.doctorId == a.doctorId));
  bool get _canViewPatient => role != UserRole.patient;

  Future<void> _run(Future<void> Function() action, String successKey) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, context.tr(successKey));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: context.tr('cancel_appointment'),
      message: context.tr('cancel_confirm', {'date': Fmt.dateTime(a.startAt, context.lang)}),
      confirmLabel: context.tr('cancel_appointment'),
      destructive: true,
    );
    if (!ok) return;
    await _run(() => BookingService.cancelAtomically(a), 'cancel_success');
  }

  Future<void> _complete() async {
    final ok = await confirmDialog(
      context,
      title: context.tr('mark_completed'),
      message: context.tr('complete_confirm', {'name': a.patientName}),
      confirmLabel: context.tr('mark_completed'),
    );
    if (!ok) return;
    await _run(() => BookingService.markCompleted(a), 'complete_success');
  }

  Future<void> _reschedule() async {
    setState(() => _busy = true);
    try {
      final doctor = await Repo.getDoctor(a.doctorId);
      if (!mounted) return;
      setState(() => _busy = false);
      if (doctor == null) {
        showMessage(context, context.tr('err_not_found'), error: true);
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BookScreen(
          doctor: doctor,
          patientId: a.patientId,
          viewer: widget.viewer,
          rescheduling: a,
        ),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  void _patientInfo() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PatientInfoScreen(
        patientId: a.patientId,
        viewer: widget.viewer,
        fromAppointment: a,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final isPatientView = role == UserRole.patient;
    final title = isPatientView ? a.doctorName : a.patientName;
    final subtitle = isPatientView
        ? context.tr(Specializations.trKey(a.doctorSpecialization))
        : '${a.doctorName} · ${context.tr(Specializations.trKey(a.doctorSpecialization))}';

    final actions = <Widget>[
      if (_canViewPatient)
        TextButton.icon(
          onPressed: _busy ? null : _patientInfo,
          icon: const Icon(Icons.person_outline_rounded, size: 18),
          label: Text(context.tr('patient_info')),
        ),
      if (_canReschedule)
        TextButton.icon(
          onPressed: _busy ? null : _reschedule,
          icon: const Icon(Icons.event_repeat_rounded, size: 18),
          label: Text(context.tr('reschedule')),
        ),
      if (_canCancel)
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: ClinovaColors.cancelled),
          onPressed: _busy ? null : _cancel,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(context.tr('cancel')),
        ),
      if (_canComplete)
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _complete,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(context.tr('mark_completed')),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: ClinovaColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        Fmt.time(a.startAt),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ClinovaColors.primaryDark),
                      ),
                      Text(
                        Fmt.time(a.endAt),
                        style: const TextStyle(fontSize: 12, color: ClinovaColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: ClinovaColors.muted, fontSize: 13)),
                      if (widget.showDate) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: ClinovaColors.muted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                Fmt.longDate(a.startAt, lang),
                                style: const TextStyle(fontSize: 13, color: ClinovaColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(a.status),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 6),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                Wrap(alignment: WrapAlignment.end, spacing: 4, runSpacing: 0, children: actions),
            ] else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// Liste de rendez-vous groupée par jour.
class AppointmentList extends StatelessWidget {
  const AppointmentList({
    super.key,
    required this.appointments,
    required this.viewer,
    this.emptyKey = 'no_appointments',
    this.header,
  });

  final List<Appointment> appointments;
  final UserProfile viewer;
  final String emptyKey;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (header != null) header!,
          EmptyState(icon: Icons.event_busy_rounded, message: context.tr(emptyKey)),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: appointments.length + (header != null ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (header != null) {
          if (i == 0) return header!;
          i -= 1;
        }
        return AppointmentCard(appointment: appointments[i], viewer: viewer);
      },
    );
  }
}
