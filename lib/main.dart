import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:correctv1/auth/auth_gate.dart';
import 'package:correctv1/home/home_page.dart';
import 'package:correctv1/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ulphnmkitdedjpvcmhkm.supabase.co',
  );
  final supabaseAnonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_qwmO0yArdX1mls7P-yaRxA_2yEBfA0Z',
  );
  final isSupabaseConfigured =
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  if (isSupabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  runApp(MyApp(isSupabaseConfigured: isSupabaseConfigured));
}

class MyApp extends StatelessWidget {
  final bool isSupabaseConfigured;

  const MyApp({super.key, required this.isSupabaseConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'align',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: isSupabaseConfigured
          ? const AuthGate()
          : const _SupabaseConfigMissingPage(),
    );
  }
}

class _SupabaseConfigMissingPage extends StatelessWidget {
  const _SupabaseConfigMissingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 52),
                const SizedBox(height: 16),
                const Text(
                  'Supabase is not configured',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Run the app with SUPABASE_URL and SUPABASE_ANON_KEY using --dart-define.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => const HomePage()),
                    );
                  },
                  child: const Text('Continue without login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
