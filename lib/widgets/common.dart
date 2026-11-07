import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/errors.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

/// Logo Clinova (pictogramme + nom).
class ClinovaLogo extends StatelessWidget {
  const ClinovaLogo({super.key, this.size = 28, this.showName = true, this.light = false});
  final double size;
  final bool showName;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : ClinovaColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light ? Colors.white.withValues(alpha: 0.16) : ClinovaColors.primary,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(Icons.add_rounded, color: light ? Colors.white : Colors.white, size: size * 0.8),
        ),
        if (showName) ...[
          SizedBox(width: size * 0.35),
          Text(
            'Clinova',
            style: TextStyle(
              fontSize: size * 0.78,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bascule de langue FR / EN (traduction instantanée de toute l'interface).
class LangToggle extends StatelessWidget {
  const LangToggle({super.key, this.onChanged});
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final state = LangScope.of(context);
    Widget chip(String code) {
      final selected = state.lang == code;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          state.setLang(code);
          // Mémorise la langue dans le profil de l'utilisateur connecté.
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) AuthService.saveLanguage(user.uid, code);
          onChanged?.call(code);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? ClinovaColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: selected ? Colors.white : ClinovaColors.muted,
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: context.tr('language'),
      child: Container(
        padding: const EdgeInsets.all(3),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ClinovaColors.surface,
          border: Border.all(color: ClinovaColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [chip('fr'), chip('en')]),
      ),
    );
  }
}

/// Centre et limite la largeur du contenu (confortable sur web et tablette).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 920});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: ClinovaColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ClinovaColors.muted, fontSize: 15),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
}

/// Affichage d'erreur d'un flux Firestore.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      message: context.tr(errorKey(error ?? Exception())),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: ClinovaColors.muted,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AppointmentStatus.scheduled => ClinovaColors.scheduled,
      AppointmentStatus.completed => ClinovaColors.completed,
      AppointmentStatus.cancelled => ClinovaColors.cancelled,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.tr(status.trKey),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ClinovaColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        context.tr(role.trKey),
        style: const TextStyle(color: ClinovaColors.primaryDark, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Avatar avec initiales.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.radius = 20, this.color});
  final String name;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    var initials = '';
    if (parts.isNotEmpty) initials += parts.first[0];
    if (parts.length > 1) initials += parts.last[0];
    final c = color ?? ClinovaColors.primary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.withValues(alpha: 0.12),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: radius * 0.75),
      ),
    );
  }
}

/// Petits utilitaires d'interface.
void showMessage(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? ClinovaColors.cancelled : ClinovaColors.ink,
    ));
}

void showError(BuildContext context, Object error) {
  final key = errorKey(error);
  var text = context.tr(key);
  if (key == 'err_generic') {
    // Affiche le code technique pour faciliter le diagnostic.
    final detail = error is FirebaseException ? '${error.plugin}/${error.code}' : '$error';
    text = '$text\n($detail)';
  }
  debugPrint('Clinova error: $error');
  showMessage(context, text, error: true);
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.tr('no'))),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: ClinovaColors.cancelled) : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? ctx.tr('yes')),
        ),
      ],
    ),
  );
  return result == true;
}

/// Bouton principal avec indicateur de chargement.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.busy, required this.onPressed, this.icon});
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
 
            ],
          );
    return FilledButton(onPressed: busy ? null : onPressed, child: child);
  }
}

/// Validateurs de formulaires.
class Validators {
  Validators._();
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phone = RegExp(r'^[+0-9 ().-]{6,20}$');
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String? Function(String?) notEmpty(BuildContext context) =>
      (v) => (v == null || v.trim().isEmpty) ? context.tr('v_required') : null;

  static String? Function(String?) email(BuildContext context, {bool optional = false}) => (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return optional ? null : context.tr('v_required');
        return _email.hasMatch(t) ? null : context.tr('err_invalid_email');
      };

  static String? Function(String?) phone(BuildContext context) => (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return context.tr('v_required');
        return _phone.hasMatch(t) ? null : context.tr('v_phone');
      };

  static String? Function(String?) password(BuildContext context) => (v) {
        final t = v ?? '';
        if (t.length < 6) return context.tr('err_weak_password');
        return null;
      };

  static String? Function(String?) date(BuildContext context) => (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return null;
        if (!_date.hasMatch(t)) return context.tr('v_date');
        final d = DateTime.tryParse(t);
        if (d == null || d.isAfter(DateTime.now())) return context.tr('v_date');
        return null;
      };
}
