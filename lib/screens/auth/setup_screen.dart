import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/demo_service.dart';
import '../../widgets/common.dart';

/// Premier lancement : initialise la base Firebase (administrateur +
/// comptes de démonstration + horaires par défaut).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _busy = false;
  String? _step;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await DemoService.initialize(onStep: (s) {
        if (mounted) setState(() => _step = s);
      });
      if (!mounted) return;
      showMessage(context, context.tr('setup_done'));
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = null;
      });
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [ClinovaLogo(size: 34), Spacer(), LangToggle()]),
                  const SizedBox(height: 28),
                  Text(context.tr('setup_title'),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  const SizedBox(height: 8),
                  Text(context.tr('setup_desc'), style: const TextStyle(color: ClinovaColors.muted, height: 1.4)),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final a in DemoData.all)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Text(context.tr('role_${a.role}'),
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  Expanded(
                                    child: Text(a.email, style: const TextStyle(color: ClinovaColors.muted)),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 24),
                          Text(context.tr('setup_schedule'), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: BusyButton(
                      label: context.tr('setup_button'),
                      icon: Icons.rocket_launch_rounded,
                      busy: _busy,
                      onPressed: _run,
                    ),
                  ),
                  if (_step != null) ...[
                    const SizedBox(height: 12),
                    Text(context.tr(_step!), style: const TextStyle(color: ClinovaColors.muted)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
