import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym/auth_screen.dart';
import 'package:gym/widgets/create_template_modal.dart';
import 'package:gym/gym_tab.dart';
import 'package:gym/sync_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tazkviborrgtmaggowmk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRhemt2aWJvcnJndG1hZ2dvd21rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyNDIzNDIsImV4cCI6MjA5MjgxODM0Mn0.VY5lKytV-hLy3BAFKZeyJsZriqQmjFHKqZ0SMuTb83A',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _isAuthenticated = data.session != null;
      });
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E0E),
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    if (_isAuthenticated) {
      return const MainNavigationScreen();
    } else {
      return const AuthScreen();
    }
  }
}

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final syncRepo = ref.read(syncRepositoryProvider);
      await syncRepo.syncDown();
      syncRepo.synchronizeAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Iniciamos el servicio de sincronización push en segundo plano
    ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gimnasio'),
        elevation: 0,
        backgroundColor: const Color(0xFF0E0E0E),
      ),
      body: const GymTab(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1A1A1A),
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => const SafeArea(child: CreateTemplateModal()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
