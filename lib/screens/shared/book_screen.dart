import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/clinic_time.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/booking_service.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';

/// UC4 + UC5 + UC8 : choisir une date et un créneau de 30 minutes,
/// puis réserver (ou reporter) de façon atomique.
class BookScreen extends StatefulWidget {
  const BookScreen({
    super.key,
    required this.doctor,
    required this.patientId,
    required this.viewer,
    this.rescheduling,
  });

  final Doctor doctor;
  final String patientId;
  final UserProfile viewer;
  final Appointment? rescheduling;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  static const int _daysAhead = 30;

  late final List<DateTime> _days;
  late DateTime _selectedDay;
  Patient? _patient;
  List<Slot>? _slots;
  Slot? _selected;
  Object? _loadError;
  bool _booking = false;
  int _requestId = 0;

  bool get _isReschedule => widget.rescheduling != null;

  @override
  void initState() {
    super.initState();
    final today = ClinicTime.wallDate(ClinicTime.nowWall());
    _days = List.generate(_daysAhead, (i) => today.add(Duration(days: i)));
    _selectedDay = _days.firstWhere((d) => !ClinicTime.isClosedDay(d), orElse: () => _days.first);
    _loadPatient();
    _loadSlots();
  }

  Future<void> _loadPatient() async {
    try {
      final p = await Repo.getPatient(widget.patientId);
      if (mounted) setState(() => _patient = p);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _loadSlots() async {
    final id = ++_requestId;
    setState(() {
      _slots = null;
      _selected = null;
    });
    try {
      final slots = await BookingService.availableSlots(
        doctorId: widget.doctor.doctorId,
        wallDay: _selectedDay,
        ignoreReservationId: null,
      );
      if (!mounted || id != _requestId) return;
      setState(() => _slots = slots);
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _slots = [];
        _loadError = e;
      });
    }
  }

  void _selectDay(DateTime day) {
    if (ClinicTime.isClosedDay(day)) {
      showMessage(context, context.tr('friday_closed'));
      return;
    }
    setState(() => _selectedDay = day);
    _loadSlots();
  }

  Future<void> _confirm() async {
    final slot = _selected;
    final patient = _patient;
    if (slot == null || patient == null) return;
    final lang = context.lang;
    final ok = await confirmDialog(
      context,
      title: context.tr(_isReschedule ? 'confirm_reschedule' : 'confirm_booking'),
      message: context.tr('booking_summary', {
        'patient': patient.fullName,
        'doctor': widget.doctor.fullName,
        'date': Fmt.longDate(slot.start, lang),
        'time': '${Fmt.time(slot.start)} – ${Fmt.time(slot.end)}',
      }),
      confirmLabel: context.tr('confirm'),
    );
    if (!ok || !mounted) return;

    setState(() => _booking = true);
    try {
      if (_isReschedule) {
        await BookingService.rescheduleAtomically(
          appointment: widget.rescheduling!,
          doctor: widget.doctor,
          newSlot: slot,
        );
      } else {
        await BookingService.bookAtomically(patient: patient, doctor: widget.doctor, slot: slot);
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: ClinovaColors.completed, size: 48),
          title: Text(ctx.tr(_isReschedule ? 'reschedule_success' : 'booking_success')),
          content: Text(
            '${widget.doctor.fullName}\n${Fmt.longDate(slot.start, lang)} · ${Fmt.time(slot.start)}',
            textAlign: TextAlign.center,
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(ctx.tr('ok')))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      showError(context, e);
      _loadSlots(); // rafraîchit les créneaux (l'un d'eux vient peut-être d'être pris)
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final d = widget.doctor;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_isReschedule ? 'reschedule' : 'book_appointment')),
        actions: const [LangToggle()],
      ),
      body: ResponsiveBody(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: InitialsAvatar(d.fullName),
                      title: Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(context.tr(Specializations.trKey(d.specialization))),
                    ),
                  ),
                  if (_patient != null && widget.viewer.role != UserRole.patient) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_rounded),
                        title: Text(_patient!.fullName),
                        subtitle: Text(context.tr('booking_for_patient')),
                      ),
                    ),
                  ],
                  if (_isReschedule) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: const Color(0xFFFFF6E8),
                      child: ListTile(
                        leading: const Icon(Icons.history_rounded, color: ClinovaColors.sand),
                        title: Text(context.tr('current_appointment')),
                        subtitle: Text(Fmt.dateTime(widget.rescheduling!.startAt, lang)),
                      ),
                    ),
                  ],
                  SectionTitle(context.tr('choose_date')),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _days.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _DayChip(
                        day: _days[i],
                        selected: ClinicTime.sameWallDay(_days[i], _selectedDay),
                        onTap: () => _selectDay(_days[i]),
                      ),
                    ),
                  ),
                  SectionTitle(
                    context.tr('available_slots'),
                    trailing: Text(
                      Fmt.longWallDate(_selectedDay, lang),
                      style: const TextStyle(fontSize: 12, color: ClinovaColors.muted),
                    ),
                  ),
                  _buildSlots(context),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('slot_info', {'tz': ClinicTime.timeZoneName}),
                    style: const TextStyle(fontSize: 12, color: ClinovaColors.muted),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: BusyButton(
                    label: _selected == null
                        ? context.tr('select_slot')
                        : '${context.tr(_isReschedule ? 'confirm_reschedule' : 'confirm_booking')} · ${Fmt.time(_selected!.start)}',
                    icon: Icons.event_available_rounded,
                    busy: _booking,
                    onPressed: _selected == null || _patient == null ? null : _confirm,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlots(BuildContext context) {
    if (_patient == null && _loadError != null) return ErrorView(error: _loadError);
    final slots = _slots;
    if (slots == null) return const LoadingView();
    if (ClinicTime.isClosedDay(_selectedDay)) {
      return EmptyState(icon: Icons.storefront_rounded, message: context.tr('friday_closed'));
    }
    final free = slots.where((s) => !s.reserved).toList();
    if (free.isEmpty) {
      return EmptyState(icon: Icons.event_busy_rounded, message: context.tr('no_slots'));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in slots)
          ChoiceChip(
            label: Text(
              Fmt.time(s.start),
              style: TextStyle(
                decoration: s.reserved ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: _selected?.start == s.start,
            onSelected: s.reserved ? null : (_) => setState(() => _selected = s),
            tooltip: s.reserved ? context.tr('slot_taken') : null,
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.onTap});
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final closed = ClinicTime.isClosedDay(day);
    final lang = context.lang;
    final fg = selected ? Colors.white : (closed ? ClinovaColors.muted.withValues(alpha: 0.6) : ClinovaColors.ink);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 62,
        decoration: BoxDecoration(
          color: selected ? ClinovaColors.primary : (closed ? const Color(0xFFEDEAE3) : ClinovaColors.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? ClinovaColors.primary : ClinovaColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(Fmt.shortWeekday(day.weekday, lang), style: TextStyle(fontSize: 12, color: fg)),
            const SizedBox(height: 2),
            Text('${day.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
            Text(
              closed ? context.tr('closed_short') : Fmt.shortMonth(day.month, lang),
              style: TextStyle(fontSize: 11, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
