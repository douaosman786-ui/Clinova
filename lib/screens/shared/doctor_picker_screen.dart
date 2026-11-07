import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repo.dart';
import '../../widgets/common.dart';
import 'book_screen.dart';

/// UC3 — Liste des médecins et spécialités (filtrable), puis réservation.
class DoctorsBrowser extends StatefulWidget {
  const DoctorsBrowser({super.key, required this.viewer, required this.patientId});
  final UserProfile viewer;
  final String patientId;

  @override
  State<DoctorsBrowser> createState() => _DoctorsBrowserState();
}

class _DoctorsBrowserState extends State<DoctorsBrowser> {
  String? _spec;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Doctor>>(
      stream: Repo.doctorsStream(activeOnly: true),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error);
        if (!snap.hasData) return const LoadingView();
        final all = snap.data!;
        final specs = all.map((d) => d.specialization).toSet().toList()..sort();
        final q = _query.trim().toLowerCase();
        final list = all.where((d) {
          if (_spec != null && d.specialization != _spec) return false;
          if (q.isEmpty) return true;
          return d.fullName.toLowerCase().contains(q) ||
              context.tr(Specializations.trKey(d.specialization)).toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('search_doctor'),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(context.tr('all')),
                    selected: _spec == null,
                    onSelected: (_) => setState(() => _spec = null),
                  ),
                  for (final s in specs) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(context.tr(Specializations.trKey(s))),
                      selected: _spec == s,
                      onSelected: (_) => setState(() => _spec = s),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (all.isEmpty)
              EmptyState(icon: Icons.medical_services_outlined, message: context.tr('no_doctors'))
            else if (list.isEmpty)
              EmptyState(icon: Icons.search_off_rounded, message: context.tr('no_results'))
            else
              for (final d in list) ...[
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: InitialsAvatar(d.fullName, radius: 24),
                    title: Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(context.tr(Specializations.trKey(d.specialization))),
                    trailing: const Icon(Icons.chevron_right_rounded, color: ClinovaColors.muted),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => BookScreen(
                        doctor: d,
                        patientId: widget.patientId,
                        viewer: widget.viewer,
                      ),
                    )),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

/// Écran plein pour le personnel : choisir un médecin pour un patient donné.
class DoctorPickerScreen extends StatelessWidget {
  const DoctorPickerScreen({super.key, required this.viewer, required this.patientId});
  final UserProfile viewer;
  final String patientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('choose_doctor')), actions: const [LangToggle()]),
      body: ResponsiveBody(child: DoctorsBrowser(viewer: viewer, patientId: patientId)),
    );
  }
}
