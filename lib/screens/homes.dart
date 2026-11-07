import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/clinic_time.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repo.dart';
import '../widgets/appointment_card.dart';
import '../widgets/common.dart';
import 'admin/users_screen.dart';
import 'shared/doctor_picker_screen.dart';
import 'shared/notifications_screen.dart';
import 'shared/profile_tab.dart';
import 'staff/staff_tabs.dart';

/// Onglet d'un espace utilisateur.
class ShellTab {
  const ShellTab({required this.icon, required this.selectedIcon, required this.labelKey, required this.child});
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;
  final Widget child;
}

/// Structure commune : barre de navigation en bas (mobile) ou rail latéral (web large).
class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.viewer, required this.tabs});
  final UserProfile viewer;
  final List<ShellTab> tabs;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final tabs = widget.tabs;
    if (_index >= tabs.length) _index = 0;
    final body = IndexedStack(
      index: _index,
      children: [for (final t in tabs) ResponsiveBody(child: t.child)],
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: wide ? 24 : 16,
        title: Row(
          children: [
            const ClinovaLogo(size: 26, showName: false),
            const SizedBox(width: 10),
            Flexible(child: Text(context.tr(tabs[_index].labelKey), overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '${widget.viewer.fullName} · ${context.tr(widget.viewer.role.trKey)}',
                  style: const TextStyle(color: ClinovaColors.muted, fontSize: 13),
                ),
              ),
            ),
          if (widget.viewer.role == UserRole.patient || widget.viewer.role == UserRole.doctor)
            NotificationBell(viewer: widget.viewer),
          const LangToggle(),
          const SizedBox(width: 4),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final t in tabs)
                      NavigationRailDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selectedIcon),
                        label: Text(context.tr(t.labelKey)),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: context.tr(t.labelKey),
                  ),
              ],
            ),
    );
  }
}

// =============================================================================
// Espace PATIENT
// =============================================================================
class PatientHome extends StatelessWidget {
  const PatientHome({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      viewer: viewer,
      tabs: [
        ShellTab(
          icon: Icons.medical_services_outlined,
          selectedIcon: Icons.medical_services_rounded,
          labelKey: 'tab_doctors',
          child: DoctorsBrowser(viewer: viewer, patientId: viewer.patientId ?? viewer.uid),
        ),
        ShellTab(
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note_rounded,
          labelKey: 'tab_my_appointments',
          child: _PatientAppointments(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          labelKey: 'tab_profile',
          child: ProfileTab(viewer: viewer),
        ),
      ],
    );
  }
}

class _PatientAppointments extends StatefulWidget {
  const _PatientAppointments({required this.viewer});
  final UserProfile viewer;

  @override
  State<_PatientAppointments> createState() => _PatientAppointmentsState();
}

class _PatientAppointmentsState extends State<_PatientAppointments> {
  late final Stream<List<Appointment>> _stream = Repo.appointmentsForPatientUid(widget.viewer.uid);
  bool _showPast = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (!snap.hasData) return const LoadingView();
        final now = DateTime.now().toUtc();
        final upcoming = snap.data!.where((a) => a.isScheduled && a.startAt.isAfter(now)).toList();
        final past = snap.data!.where((a) => !(a.isScheduled && a.startAt.isAfter(now))).toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
        final list = _showPast ? past : upcoming;
        return AppointmentList(
          appointments: list,
          viewer: widget.viewer,
          emptyKey: _showPast ? 'no_past_appointments' : 'no_upcoming_appointments',
          header: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text('${context.tr('upcoming')} (${upcoming.length})')),
                ButtonSegment(value: true, label: Text('${context.tr('history')} (${past.length})')),
              ],
              selected: {_showPast},
              onSelectionChanged: (s) => setState(() => _showPast = s.first),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Espace MÉDECIN
// =============================================================================
class DoctorHome extends StatelessWidget {
  const DoctorHome({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  Widget build(BuildContext context) {
    final doctorId = viewer.doctorId;
    if (doctorId == null) {
      return Scaffold(
        appBar: AppBar(title: const ClinovaLogo(), actions: const [LangToggle()]),
        body: ProfileTab(viewer: viewer),
      );
    }
    return RoleShell(
      viewer: viewer,
      tabs: [
        ShellTab(
          icon: Icons.today_outlined,
          selectedIcon: Icons.today_rounded,
          labelKey: 'tab_today',
          child: _DoctorAppointments(viewer: viewer, doctorId: doctorId, todayOnly: true),
        ),
        ShellTab(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          labelKey: 'tab_my_schedule',
          child: _DoctorAppointments(viewer: viewer, doctorId: doctorId, todayOnly: false),
        ),
        ShellTab(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          labelKey: 'tab_profile',
          child: ProfileTab(viewer: viewer),
        ),
      ],
    );
  }
}

class _DoctorAppointments extends StatefulWidget {
  const _DoctorAppointments({required this.viewer, required this.doctorId, required this.todayOnly});
  final UserProfile viewer;
  final String doctorId;
  final bool todayOnly;

  @override
  State<_DoctorAppointments> createState() => _DoctorAppointmentsState();
}

class _DoctorAppointmentsState extends State<_DoctorAppointments> {
  late final Stream<List<Appointment>> _stream = Repo.appointmentsForDoctor(widget.doctorId);
  bool _showPast = false;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return StreamBuilder<List<Appointment>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (!snap.hasData) return const LoadingView();
        final all = snap.data!;
        final todayWall = ClinicTime.nowWall();

        if (widget.todayOnly) {
          final today = all.where((a) => ClinicTime.sameWallDay(ClinicTime.toWall(a.startAt), todayWall)).toList();
          final remaining = today.where((a) => a.isScheduled).length;
          return AppointmentList(
            appointments: today,
            viewer: widget.viewer,
            emptyKey: 'no_appointments_today',
            header: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Card(
                color: ClinovaColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Fmt.longWallDate(todayWall, lang),
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('today_summary', {'n': '${today.length}', 'r': '$remaining'}),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.medical_services_rounded, color: Colors.white54, size: 36),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final now = DateTime.now().toUtc();
        final upcoming = all.where((a) => a.startAt.isAfter(now) && a.isScheduled).toList();
        final past = all.where((a) => !(a.startAt.isAfter(now) && a.isScheduled)).toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
        return AppointmentList(
          appointments: _showPast ? past : upcoming,
          viewer: widget.viewer,
          emptyKey: _showPast ? 'no_past_appointments' : 'no_upcoming_appointments',
          header: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text('${context.tr('upcoming')} (${upcoming.length})')),
                ButtonSegment(value: true, label: Text('${context.tr('history')} (${past.length})')),
              ],
              selected: {_showPast},
              onSelectionChanged: (s) => setState(() => _showPast = s.first),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Espace RÉCEPTIONNISTE
// =============================================================================
class ReceptionistHome extends StatelessWidget {
  const ReceptionistHome({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      viewer: viewer,
      tabs: [
        ShellTab(
          icon: Icons.today_outlined,
          selectedIcon: Icons.today_rounded,
          labelKey: 'tab_today',
          child: DayAppointmentsTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.manage_search_outlined,
          selectedIcon: Icons.manage_search_rounded,
          labelKey: 'tab_search',
          child: SearchAppointmentsTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          labelKey: 'tab_patients',
          child: PatientsTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.medical_services_outlined,
          selectedIcon: Icons.medical_services_rounded,
          labelKey: 'tab_doctors',
          child: DoctorsManageTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          labelKey: 'tab_profile',
          child: ProfileTab(viewer: viewer),
        ),
      ],
    );
  }
}

// =============================================================================
// Espace ADMINISTRATEUR
// =============================================================================
class AdminHome extends StatelessWidget {
  const AdminHome({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      viewer: viewer,
      tabs: [
        ShellTab(
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts_rounded,
          labelKey: 'tab_users',
          child: UsersTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.medical_services_outlined,
          selectedIcon: Icons.medical_services_rounded,
          labelKey: 'tab_doctors_schedules',
          child: DoctorsManageTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          labelKey: 'tab_patients',
          child: PatientsTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          labelKey: 'tab_agenda',
          child: DayAppointmentsTab(viewer: viewer),
        ),
        ShellTab(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          labelKey: 'tab_profile',
          child: ProfileTab(viewer: viewer),
        ),
      ],
    );
  }
}
