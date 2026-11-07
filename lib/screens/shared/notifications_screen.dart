import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';

/// Texte traduit d'une notification, adapté au rôle du lecteur.
String notificationText(BuildContext context, AppNotification n, UserRole role) {
  final lang = context.lang;
  final suffix = role == UserRole.doctor ? 'd' : 'p';
  return context.tr('notif_${n.type}_$suffix', {
    'doctor': n.doctorName,
    'patient': n.patientName,
    'date': Fmt.dateTime(n.startAt, lang),
    'old': n.oldStartAt == null ? '—' : Fmt.dateTime(n.oldStartAt!, lang),
  });
}

IconData _icon(String type) => switch (type) {
      'booked' => Icons.event_available_rounded,
      'rescheduled' => Icons.event_repeat_rounded,
      'cancelled' => Icons.event_busy_rounded,
      'completed' => Icons.task_alt_rounded,
      _ => Icons.notifications_rounded,
    };

Color _color(String type) => switch (type) {
      'booked' => ClinovaColors.scheduled,
      'rescheduled' => ClinovaColors.sand,
      'cancelled' => ClinovaColors.cancelled,
      'completed' => ClinovaColors.completed,
      _ => ClinovaColors.primary,
    };

/// Cloche avec compteur de non-lus. Affiche aussi un message quand une
/// nouvelle notification arrive pendant que l'application est ouverte.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.viewer});
  final UserProfile viewer;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final Stream<List<AppNotification>> _stream = Repo.notificationsFor(widget.viewer.uid);
  Set<String>? _known;

  void _announceNew(List<AppNotification> items) {
    final ids = items.map((n) => n.id).toSet();
    final known = _known;
    _known = ids;
    if (known == null) return; // premier chargement : pas d'annonce
    final fresh = items.where((n) => !n.read && !known.contains(n.id)).toList();
    if (fresh.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(
        content: Text(notificationText(context, fresh.first, widget.viewer.role)),
        action: SnackBarAction(label: context.tr('open'), onPressed: _open),
      ));
    });
  }

  void _open() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NotificationsScreen(viewer: widget.viewer),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snap) {
        final items = snap.data ?? const <AppNotification>[];
        if (snap.hasData) _announceNew(items);
        final unread = items.where((n) => !n.read).length;
        return IconButton(
          tooltip: context.tr('notifications'),
          onPressed: _open,
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        );
      },
    );
  }
}

/// Centre de notifications : rappels (RDV dans les 24 h) + historique.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.viewer});
  final UserProfile viewer;

  Stream<List<Appointment>> _appointments() {
    if (viewer.role == UserRole.doctor && viewer.doctorId != null) {
      return Repo.appointmentsForDoctor(viewer.doctorId!);
    }
    return Repo.appointmentsForPatientUid(viewer.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('notifications')),
        actions: const [LangToggle()],
      ),
      body: ResponsiveBody(
        maxWidth: 720,
        child: StreamBuilder<List<AppNotification>>(
          stream: Repo.notificationsFor(viewer.uid),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error);
            if (!snap.hasData) return const LoadingView();
            final items = snap.data!;
            final hasUnread = items.any((n) => !n.read);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Reminders(viewer: viewer, stream: _appointments()),
                SectionTitle(
                  context.tr('notifications'),
                  trailing: hasUnread
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await Repo.markAllNotificationsRead(items);
                            } catch (e) {
                              if (context.mounted) showError(context, e);
                            }
                          },
                          child: Text(context.tr('mark_all_read')),
                        )
                      : null,
                ),
                if (items.isEmpty)
                  EmptyState(icon: Icons.notifications_off_outlined, message: context.tr('no_notifications'))
                else
                  for (final n in items) ...[
                    Card(
                      color: n.read ? ClinovaColors.surface : const Color(0xFFEAF4F3),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _color(n.type).withValues(alpha: 0.14),
                          child: Icon(_icon(n.type), color: _color(n.type)),
                        ),
                        title: Text(
                          context.tr('notif_title_${n.type}'),
                          style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(notificationText(context, n, viewer.role)),
                        ),
                        trailing: IconButton(
                          tooltip: context.tr('delete'),
                          icon: const Icon(Icons.close_rounded, size: 18, color: ClinovaColors.muted),
                          onPressed: () => Repo.deleteNotification(n.id).catchError((Object e) {
                            if (context.mounted) showError(context, e);
                          }),
                        ),
                        onTap: n.read ? null : () => Repo.markNotificationRead(n.id).catchError((Object e) {}),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 8),
                Text(context.tr('notif_tap_hint'),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: ClinovaColors.muted)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Rappels : rendez-vous programmés dans les prochaines 24 heures.
class _Reminders extends StatelessWidget {
  const _Reminders({required this.viewer, required this.stream});
  final UserProfile viewer;
  final Stream<List<Appointment>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Appointment>>(
      stream: stream,
      builder: (context, snap) {
        final now = DateTime.now().toUtc();
        final limit = now.add(const Duration(hours: 24));
        final soon = (snap.data ?? const <Appointment>[])
            .where((a) => a.isScheduled && a.startAt.isAfter(now) && a.startAt.isBefore(limit))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        if (soon.isEmpty) return const SizedBox.shrink();
        final lang = context.lang;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(context.tr('reminders')),
            for (final a in soon) ...[
              Card(
                color: const Color(0xFFFFF6E8),
                child: ListTile(
                  leading: const Icon(Icons.alarm_rounded, color: ClinovaColors.sand),
                  title: Text(
                    viewer.role == UserRole.doctor ? a.patientName : a.doctorName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(Fmt.dateTime(a.startAt, lang)),
                  trailing: Text(
                    context.tr('reminder_in', {'h': '${a.startAt.difference(now).inHours}'}),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: ClinovaColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
