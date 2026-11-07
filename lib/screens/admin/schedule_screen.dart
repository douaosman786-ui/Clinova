import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/clinic_time.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';

/// UC16 — Configurer l'horaire d'un médecin (Administrateur uniquement).
/// FR14 : les créneaux proposés sont limités à cet horaire. Vendredi : fermé.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.doctor});
  final Doctor doctor;

  Future<void> _addOrEdit(BuildContext context, List<DoctorSchedule> existing, [DoctorSchedule? block]) async {
    final result = await showDialog<_BlockResult>(
      context: context,
      builder: (_) => _BlockDialog(block: block),
    );
    if (result == null || !context.mounted) return;

    // Validation : début < fin, pas de chevauchement le même jour, pas le vendredi.
    if (ClinicTime.closedWeekdays.contains(result.day)) {
      showMessage(context, context.tr('friday_closed'), error: true);
      return;
    }
    if (result.start >= result.end) {
      showMessage(context, context.tr('err_invalid_range'), error: true);
      return;
    }
    final overlap = existing.any((s) =>
        s.scheduleId != block?.scheduleId &&
        s.dayOfWeek == result.day &&
        result.start < s.endMinutes &&
        s.startMinutes < result.end);
    if (overlap) {
      showMessage(context, context.tr('err_overlap'), error: true);
      return;
    }
    final data = DoctorSchedule.toMap(
      doctorId: doctor.doctorId,
      dayOfWeek: result.day,
      startMinutes: result.start,
      endMinutes: result.end,
      isAvailable: block?.isAvailable ?? true,
    );
    try {
      if (block == null) {
        await Repo.schedules.add(data);
      } else {
        await Repo.schedules.doc(block.scheduleId).set(data);
      }
      if (context.mounted) showMessage(context, context.tr('saved'));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _applyDefault(BuildContext context) async {
    try {
      final batch = Repo.db.batch();
      for (final day in ClinicTime.workWeekOrder) {
        for (final b in DemoData.defaultBlocks) {
          batch.set(
            Repo.schedules.doc(),
            DoctorSchedule.toMap(
              doctorId: doctor.doctorId,
              dayOfWeek: day,
              startMinutes: b[0],
              endMinutes: b[1],
              isAvailable: true,
            ),
          );
        }
      }
      await batch.commit();
      if (context.mounted) showMessage(context, context.tr('saved'));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('configure_schedule')), actions: const [LangToggle()]),
      body: ResponsiveBody(
        maxWidth: 720,
        child: StreamBuilder<List<DoctorSchedule>>(
          stream: Repo.schedulesStream(doctor.doctorId),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error);
            if (!snap.hasData) return const LoadingView();
            final blocks = snap.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Card(
                  child: ListTile(
                    leading: InitialsAvatar(doctor.fullName),
                    title: Text(doctor.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(context.tr(Specializations.trKey(doctor.specialization))),
                  ),
                ),
                const SizedBox(height: 8),
                Text(context.tr('schedule_help'), style: const TextStyle(fontSize: 12, color: ClinovaColors.muted)),
                if (blocks.isEmpty) ...[
                  EmptyState(
                    icon: Icons.schedule_rounded,
                    message: context.tr('no_schedule'),
                    action: OutlinedButton.icon(
                      onPressed: () => _applyDefault(context),
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: Text(context.tr('apply_default_schedule')),
                    ),
                  ),
                ],
                for (final day in [...ClinicTime.workWeekOrder, DateTime.friday]) ...[
                  SectionTitle(Fmt.weekdayCap(day, lang)),
                  if (ClinicTime.closedWeekdays.contains(day))
                    Card(
                      color: const Color(0xFFF1EEE7),
                      child: ListTile(
                        leading: const Icon(Icons.block_rounded, color: ClinovaColors.muted),
                        title: Text(context.tr('clinic_closed')),
                      ),
                    )
                  else if (!blocks.any((b) => b.dayOfWeek == day))
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(context.tr('not_working'), style: const TextStyle(color: ClinovaColors.muted)),
                    )
                  else
                    for (final b in blocks.where((b) => b.dayOfWeek == day)) ...[
                      Card(
                        child: ListTile(
                          leading: Icon(
                            Icons.access_time_rounded,
                            color: b.isAvailable ? ClinovaColors.primary : ClinovaColors.muted,
                          ),
                          title: Text('${b.startTime} – ${b.endTime}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(context.tr(b.isAvailable ? 'available' : 'unavailable')),
                          onTap: () => _addOrEdit(context, blocks, b),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: b.isAvailable,
                                onChanged: (v) async {
                                  try {
                                    await Repo.schedules.doc(b.scheduleId).update({'isAvailable': v});
                                  } catch (e) {
                                    if (context.mounted) showError(context, e);
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: context.tr('delete'),
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () async {
                                  final ok = await confirmDialog(
                                    context,
                                    title: context.tr('delete'),
                                    message: context.tr('delete_block_confirm'),
                                    destructive: true,
                                  );
                                  if (!ok) return;
                                  try {
                                    await Repo.schedules.doc(b.scheduleId).delete();
                                  } catch (e) {
                                    if (context.mounted) showError(context, e);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: StreamBuilder<List<DoctorSchedule>>(
        stream: Repo.schedulesStream(doctor.doctorId),
        builder: (context, snap) => FloatingActionButton.extended(
          heroTag: 'add-block',
          onPressed: snap.hasData ? () => _addOrEdit(context, snap.data!) : null,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.tr('add_time_block')),
        ),
      ),
    );
  }
}

class _BlockResult {
  _BlockResult(this.day, this.start, this.end);
  final int day;
  final int start;
  final int end;
}

class _BlockDialog extends StatefulWidget {
  const _BlockDialog({this.block});
  final DoctorSchedule? block;

  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  late int _day = widget.block?.dayOfWeek ?? DateTime.saturday;
  late int _start = widget.block?.startMinutes ?? 8 * 60;
  late int _end = widget.block?.endMinutes ?? 12 * 60;

  // Heures proposées : 06:00 -> 22:00 par pas de 30 minutes.
  static final List<int> _times = [for (var m = 6 * 60; m <= 22 * 60; m += 30) m];

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    if (!ClinicTime.workWeekOrder.contains(_day)) _day = DateTime.saturday;
    if (!_times.contains(_start)) _start = 8 * 60;
    if (!_times.contains(_end)) _end = 12 * 60;
    return AlertDialog(
      title: Text(context.tr(widget.block == null ? 'add_time_block' : 'edit_time_block')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _day,
              decoration: InputDecoration(labelText: context.tr('day')),
              items: [
                for (final d in ClinicTime.workWeekOrder)
                  DropdownMenuItem(value: d, child: Text(Fmt.weekdayCap(d, lang))),
              ],
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _start,
                    decoration: InputDecoration(labelText: context.tr('start_time')),
                    items: [
                      for (final t in _times)
                        DropdownMenuItem(value: t, child: Text(ClinicTime.minutesToHHmm(t))),
                    ],
                    onChanged: (v) => setState(() => _start = v ?? _start),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _end,
                    decoration: InputDecoration(labelText: context.tr('end_time')),
                    items: [
                      for (final t in _times)
                        DropdownMenuItem(value: t, child: Text(ClinicTime.minutesToHHmm(t))),
                    ],
                    onChanged: (v) => setState(() => _end = v ?? _end),
                  ),
                ),
              ],
            ),
            if (_start >= _end)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.tr('err_invalid_range'), style: const TextStyle(color: ClinovaColors.cancelled)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.tr('cancel'))),
        FilledButton(
          onPressed: _start < _end ? () => Navigator.of(context).pop(_BlockResult(_day, _start, _end)) : null,
          child: Text(context.tr('save')),
        ),
      ],
    );
  }
}
