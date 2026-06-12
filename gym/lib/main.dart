import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym/auth_screen.dart';
import 'package:gym/widgets/today_live_workout_screen.dart';
import 'package:gym/gym_calendar_tab.dart';
import 'package:gym/sync_provider.dart';
import 'package:gym/gym_provider.dart';

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
  bool _showTopTabs = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final syncRepo = ref.read(syncRepositoryProvider);
      await syncRepo.syncDown();
      
      // Auto-desplazar calendario si hay entrenos pendientes pasados
      await ref.read(gymRepositoryProvider).autoShiftPlannedWorkouts();
      
      syncRepo.synchronizeAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Iniciamos el servicio de sincronización push en segundo plano
    ref.watch(syncProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            _CollapsibleTopTabs(visible: _showTopTabs),
            Expanded(
              child: TabBarView(
                children: [
                  TodayLiveWorkoutScreen(
                    onChromeVisibilityChanged: (visible) {
                      if (_showTopTabs == visible || !mounted) return;
                      setState(() => _showTopTabs = visible);
                    },
                  ),
                  const GymCalendarTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleTopTabs extends StatelessWidget {
  const _CollapsibleTopTabs({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    const tabHeight = 64.0;

    final fullHeight = topPadding + tabHeight;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? fullHeight : 0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, height, child) {
        return SizedBox(
          height: height,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: fullHeight,
              maxHeight: fullHeight,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        height: fullHeight,
        color: const Color(0xFF0E0E0E),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: tabHeight,
            child: const TabBar(
              tabs: [
                Tab(text: 'ENTRENAR', icon: Icon(Icons.fitness_center)),
                Tab(text: 'CALENDARIO', icon: Icon(Icons.calendar_month)),
              ],
              indicatorColor: Colors.greenAccent,
              labelColor: Colors.greenAccent,
              unselectedLabelColor: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
