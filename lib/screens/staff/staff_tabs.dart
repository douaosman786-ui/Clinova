import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/clinic_time.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/common.dart';
import '../admin/schedule_screen.dart';
import '../shared/patient_info_screen.dart';
import 'doctor_form_screen.dart';
import 'patient_form_screen.dart';

// =============================================================================
// UC12 — Rendez-vous du jour (personnel) avec navigation par date
// =============================================================================
class DayAppointmentsTab extends StatefulWidget {
  const DayAppointmentsTab({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  State<DayAppointmentsTab> createState() => _DayAppointmentsTabState();
}

class _DayAppointmentsTabState extends State<DayAppointmentsTab> {
  late DateTime _day = ClinicTime.wallDate(ClinicTime.nowWall());
  late Stream<List<Appointment>> _stream = Repo.appointmentsForDay(_day);
  String? _doctorId;
  bool _hideCancelled = false;

  void _shift(int days) {
    setState(() {
      _day = _day.add(Duration(days: days));
      _stream = Repo.appointmentsForDay(_day);
    });
  }

  void _today() {
    setState(() {
      _day = ClinicTime.wallDate(ClinicTime.nowWall());
      _stream = Repo.appointmentsForDay(_day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final isToday = ClinicTime.sameWallDay(_day, ClinicTime.nowWall());
    return StreamBuilder<List<Appointment>>(
      stream: _stream,
      builder: (context, snap) {
        final all = snap.data ?? const <Appointment>[];
        final doctorIds = <String, String>{for (final a in all) a.doctorId: a.doctorName};
        final list = all.where((a) {
          if (_doctorId != null && a.doctorId != _doctorId) return false;
          if (_hideCancelled && a.status == AppointmentStatus.cancelled) return false;
          return true;
        }).toList();

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            isToday ? context.tr('today') : Fmt.weekdayCap(_day.weekday, lang),
                            style: const TextStyle(fontSize: 12, color: ClinovaColors.muted),
                          ),
                          Text(
                            Fmt.longWallDate(_day, lang),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (!isToday)
                      TextButton(onPressed: _today, child: Text(context.tr('today'))),
                    IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
                  ],
                ),
              ),
            ),
            if (ClinicTime.isClosedDay(_day))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(context.tr('friday_closed'), style: const TextStyle(color: ClinovaColors.cancelled)),
              ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('${context.tr('all_doctors')} (${all.length})'),
                    selected: _doctorId == null,
                    onSelected: (_) => setState(() => _doctorId = null),
                  ),
                  for (final e in doctorIds.entries) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _doctorId == e.key,
                      onSelected: (_) => setState(() => _doctorId = e.key),
                    ),
                  ],
                  const SizedBox(width: 12),
                  FilterChip(
                    label: Text(context.tr('hide_cancelled')),
                    selected: _hideCancelled,
                    onSelected: (v) => setState(() => _hideCancelled = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        );

        if (snap.hasError) return ListView(padding: const EdgeInsets.all(16), children: [header, ErrorView(error: snap.error)]);
        if (!snap.hasData) return ListView(padding: const EdgeInsets.all(16), children: [header, const LoadingView()]);
        return AppointmentList(
          appointments: list,
          viewer: widget.viewer,
          header: header,
          emptyKey: 'no_appointments_day',
        );
      },
    );
  }
}

// =============================================================================
// UC11 — Recherche de rendez-vous (patient, médecin, date)
// =============================================================================
class SearchAppointmentsTab extends StatefulWidget {
  const SearchAppointmentsTab({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  State<SearchAppointmentsTab> createState() => _SearchAppointmentsTabState();
}

class _SearchAppointmentsTabState extends State<SearchAppointmentsTab> {
  final _patientCtrl = TextEditingController();
  String? _doctorId;
  DateTime? _wallDay;
  AppointmentStatus? _status;
  bool _busy = false;
  List<Appointment>? _results;

  @override
  void dispose() {
    _patientCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ClinicTime.nowWall();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _wallDay = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _search() async {
    setState(() => _busy = true);
    try {
      List<Appointment> list;
      if (_wallDay != null) {
        list = await Repo.appointmentsBetween(
          ClinicTime.dayStartInstant(_wallDay!),
          ClinicTime.dayEndInstant(_wallDay!),
        );
      } else if (_doctorId != null) {
        list = await Repo.appointmentsByField('doctorId', _doctorId!);
      } else {
        list = await Repo.recentAppointments();
      }
      final q = _patientCtrl.text.trim().toLowerCase();
      list = list.where((a) {
        if (_doctorId != null && a.doctorId != _doctorId) return false;
        if (_status != null && a.status != _status) return false;
        if (q.isNotEmpty &&
            !a.patientName.toLowerCase().contains(q) &&
            !(a.patientPhone ?? '').toLowerCase().contains(q)) {
          return false;
        }
        return true;
      }).toList();
      if (mounted) setState(() => _results = list);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _patientCtrl.clear();
      _doctorId = null;
      _wallDay = null;
      _status = null;
      _results = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final filters = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _patientCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_search_rounded),
                labelText: context.tr('patient_name_or_phone'),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Doctor>>(
              stream: Repo.doctorsStream(),
              builder: (context, snap) {
                final doctors = snap.data ?? const <Doctor>[];
                final value = doctors.any((d) => d.doctorId == _doctorId) ? _doctorId : null;
                return DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: value,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr('doctor')),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(context.tr('all_doctors'))),
                    for (final d in doctors)
                      DropdownMenuItem<String?>(value: d.doctorId, child: Text(d.fullName)),
                  ],
                  onChanged: (v) => setState(() => _doctorId = v),
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(_wallDay == null ? context.tr('any_date') : Fmt.longWallDate(_wallDay!, lang)),
                  onPressed: _pickDate,
                ),
                if (_wallDay != null)
                  IconButton(
                    tooltip: context.tr('clear'),
                    onPressed: () => setState(() => _wallDay = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                for (final s in AppointmentStatus.values)
                  FilterChip(
                    label: Text(context.tr(s.trKey)),
                    selected: _status == s,
                    onSelected: (v) => setState(() => _status = v ? s : null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BusyButton(
                    label: context.tr('search'),
                    icon: Icons.search_rounded,
                    busy: _busy,
                    onPressed: _search,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _reset, child: Text(context.tr('reset'))),
              ],
            ),
          ],
        ),
      ),
    );

    final results = _results;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        filters,
        if (results != null) ...[
          SectionTitle(context.tr('results_count', {'n': '${results.length}'})),
          if (results.isEmpty)
            EmptyState(icon: Icons.search_off_rounded, message: context.tr('no_results'))
          else
            for (final a in results) ...[
              AppointmentCard(appointment: a, viewer: widget.viewer),
              const SizedBox(height: 10),
            ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              context.tr('search_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: ClinovaColors.muted),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// UC9 / UC14 — Liste des patients
// =============================================================================
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  String _query = '';
  final Stream<List<Patient>> _stream = Repo.patientsStream();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-patient',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PatientFormScreen(viewer: widget.viewer),
        )),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(context.tr('register_patient')),
      ),
      body: StreamBuilder<List<Patient>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          final q = _query.trim().toLowerCase();
          final list = snap.data!
              .where((p) =>
                  q.isEmpty ||
                  p.fullName.toLowerCase().contains(q) ||
                  p.phone.toLowerCase().contains(q) ||
                  (p.email ?? '').toLowerCase().contains(q))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: context.tr('search_patient'),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              SectionTitle(context.tr('patients_count', {'n': '${list.length}'})),
              if (list.isEmpty)
                EmptyState(icon: Icons.people_outline_rounded, message: context.tr('no_patients'))
              else
                for (final p in list) ...[
                  Card(
                    child: ListTile(
                      leading: InitialsAvatar(p.fullName),
                      title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([p.phone, if (p.email != null) p.email!].join(' · ')),
                      trailing: p.hasAccount
                          ? Tooltip(
                              message: context.tr('online_account'),
                              child: const Icon(Icons.verified_user_outlined, color: ClinovaColors.primary, size: 20),
                            )
                          : null,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PatientInfoScreen(patientId: p.patientId, viewer: widget.viewer),
                      )),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// UC10 — Gestion des médecins (+ horaires pour l'administrateur)
// =============================================================================
class DoctorsManageTab extends StatelessWidget {
  const DoctorsManageTab({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  Widget build(BuildContext context) {
    final isAdmin = viewer.role == UserRole.administrator;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-doctor',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => DoctorFormScreen(viewer: viewer),
        )),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('register_doctor')),
      ),
      body: StreamBuilder<List<Doctor>>(
        stream: Repo.doctorsStream(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error);
          if (!snap.hasData) return const LoadingView();
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(icon: Icons.medical_services_outlined, message: context.tr('no_doctors'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (!isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(context.tr('schedule_by_admin_note'),
                      style: const TextStyle(fontSize: 12, color: ClinovaColors.muted)),
                ),
              for (final d in list) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                    child: ListTile(
                      leading: InitialsAvatar(d.fullName,
                          color: d.isActive ? ClinovaColors.primary : ClinovaColors.muted),
                      title: Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${context.tr(Specializations.trKey(d.specialization))}'
                        '${d.isActive ? '' : ' · ${context.tr('inactive')}'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin)
                            IconButton(
                              tooltip: context.tr('configure_schedule'),
                              icon: const Icon(Icons.schedule_rounded),
                              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => ScheduleScreen(doctor: d),
                              )),
                            ),
                          IconButton(
                            tooltip: context.tr('edit'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => DoctorFormScreen(viewer: viewer, doctor: d),
                            )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}
