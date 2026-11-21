import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/groups/groups_screen.dart';
import 'features/profile/profile_screen.dart';
import 'data/repo.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const QasamtahaApp());
}

class QasamtahaApp extends StatelessWidget {
  const QasamtahaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'قسمتها',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar', 'EG'),
    supportedLocales: const [Locale('ar', 'EG')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const LoginScreen() : const _ProfileGate();
      },
    ),
  );
}


class _ProfileGate extends StatelessWidget {
  const _ProfileGate();
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: Repo.instance.myProfile(),
    builder: (_, snap) {
      if (snap.hasError) return const Scaffold(body: Center(child: Text('حصلت مشكلة في الاتصال')));
      if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return snap.data!.exists ? const GroupsScreen() : const ProfileScreen();
    },
  );
}