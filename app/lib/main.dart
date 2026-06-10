import 'package:app/widgets/quick_capture_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/widgets/create_habit_modal.dart';
import 'package:app/widgets/create_task_modal.dart';
import 'package:app/widgets/create_roadmap_modal.dart';
import 'package:app/home_tab.dart';
import 'package:app/sync_provider.dart';
import 'package:app/services/sync_service.dart';
import 'package:app/notes_provider.dart';
import 'package:app/auth_screen.dart';
import 'dart:async';

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
      title: 'Life OS',
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
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeTab(),
  ];

  final List<String> _titles = const [
    'Hoy',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final syncService = SyncService(
        supabaseClient: ref.read(supabaseClientProvider),
        database: ref.read(appDatabaseProvider),
      );
      syncService.syncDown();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Iniciamos el servicio de sincronización push en segundo plano
    ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        elevation: 0,
        backgroundColor: const Color(0xFF0E0E0E),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {

          // Si estamos en "Hoy", mostramos el menú principal de creación
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF1A1A1A),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Qué quieres registrar?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt, color: Colors.purpleAccent),
                    ),
                    title: const Text('Nota Rápida', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Pensamientos fugaces, ideas, recuerdos', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const QuickCaptureModal(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_box_outlined, color: Colors.blueAccent),
                    ),
                    title: const Text('Tarea Pendiente', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Algo que debes hacer una sola vez', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateTaskModal(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.loop, color: Colors.greenAccent),
                    ),
                    title: const Text('Hábito', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Construir consistencia a lo largo del tiempo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateHabitModal(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.map_outlined, color: Colors.orangeAccent),
                    ),
                    title: const Text('Roadmap (Meta Larga)', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Un proyecto macro dividido en fases', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateRoadmapModal(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
