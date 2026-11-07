import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'screens/homes.dart';
import 'services/auth_service.dart';
import 'services/demo_service.dart';
import 'widgets/common.dart';

class ClinovaApp extends StatelessWidget {
  const ClinovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LangScope(
      state: appState,
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => MaterialApp(
          title: 'Clinova',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: appState.locale,
          supportedLocales: const [Locale('fr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const InitGate(),
        ),
      ),
    );
  }
}

/// Vérifie si Clinova a déjà été initialisée sur ce projet Firebase.
class InitGate extends StatefulWidget {
  const InitGate({super.key});

  @override
  State<InitGate> createState() => _InitGateState();
}

class _InitGateState extends State<InitGate> {
  late Future<bool> _initialized = DemoService.isInitialized();

  void _retry() => setState(() => _initialized = DemoService.isInitialized());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initialized,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: EmptyState(
              icon: Icons.cloud_off_rounded,
              message: context.tr('err_firebase_connection'),
              action: FilledButton(onPressed: _retry, child: Text(context.tr('retry'))),
            ),
          );
        }
        if (!snap.hasData) return const _Splash();
        if (snap.data == false) return SetupScreen(onDone: _retry);
        return const AuthGate();
      },
    );
  }
}

/// Redirige selon l'état de connexion et le rôle (UC2 — écran adapté au rôle).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final Stream<User?> _authStream = AuthService.authChanges();
  String? _streamUid;
  Stream<UserProfile?>? _profileStream;
  String? _langAppliedFor;

  Stream<UserProfile?> _profileFor(String uid) {
    if (_streamUid != uid || _profileStream == null) {
      _streamUid = uid;
      _profileStream = AuthService.profileStream(uid);
    }
    return _profileStream!;
  }

  void _applyLanguageOnce(UserProfile p) {
    if (_langAppliedFor == p.uid) return;
    _langAppliedFor = p.uid;
    final lang = p.language;
    if (lang != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => appState.setLang(lang));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) return const _Splash();
        final user = authSnap.data;
        if (user == null) {
          _langAppliedFor = null;
          return const LoginScreen();
        }
        return StreamBuilder<UserProfile?>(
          stream: _profileFor(user.uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return _MessageScreen(icon: Icons.error_outline_rounded, messageKey: 'err_profile_load');
            }
            if (!snap.hasData) {
              if (snap.connectionState == ConnectionState.active) {
                // Profil pas encore créé (inscription en cours) ou introuvable.
                return const _MessageScreen(icon: Icons.hourglass_top_rounded, messageKey: 'profile_preparing');
              }
              return const _Splash();
            }
            final profile = snap.data!;
            if (!profile.isActive) {
              return const _MessageScreen(icon: Icons.block_rounded, messageKey: 'err_account_disabled');
            }
            _applyLanguageOnce(profile);
            return switch (profile.role) {
              UserRole.patient => PatientHome(key: ValueKey('p-${profile.uid}'), viewer: profile),
              UserRole.doctor => DoctorHome(key: ValueKey('d-${profile.uid}'), viewer: profile),
              UserRole.receptionist => ReceptionistHome(key: ValueKey('r-${profile.uid}'), viewer: profile),
              UserRole.administrator => AdminHome(key: ValueKey('a-${profile.uid}'), viewer: profile),
            };
          },
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClinovaLogo(size: 44),
            SizedBox(height: 24),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6)),
          ],
        ),
      ),
    );
  }
}

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({required this.icon, required this.messageKey});
  final IconData icon;
  final String messageKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const ClinovaLogo(), actions: const [LangToggle()]),
      body: EmptyState(
        icon: icon,
        message: context.tr(messageKey),
        action: OutlinedButton.icon(
          onPressed: () => AuthService.signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: Text(context.tr('logout')),
        ),
      ),
    );
  }
}
