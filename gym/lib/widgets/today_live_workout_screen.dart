import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym_provider.dart';
import 'package:gym/exercise_execution_screen.dart';

class TodayLiveWorkoutScreen extends ConsumerWidget {
  const TodayLiveWorkoutScreen({super.key, this.onChromeVisibilityChanged});

  final ValueChanged<bool>? onChromeVisibilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    
    final plansAsync = ref.watch(plannedWorkoutsProvider(weekStart));

    return plansAsync.when(
      data: (plans) {
        final todayPlans = plans.where((p) => 
            p.plannedDate.year == now.year && 
            p.plannedDate.month == now.month && 
            p.plannedDate.day == now.day).toList();
        
        if (todayPlans.isEmpty) {
          onChromeVisibilityChanged?.call(true);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.self_improvement, size: 80, color: Color(0xFF333333)),
                const SizedBox(height: 16),
                const Text('Día Libre', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('No tienes rutinas planificadas para hoy.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    DefaultTabController.of(context).animateTo(1); // Ir a Calendario
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Planificar en Calendario'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF171717),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                )
              ],
            ),
          );
        }

        final plan = todayPlans.first;
        final templatesAsync = ref.watch(gymTemplatesProvider);
        
        return templatesAsync.when(
          data: (templates) {
            final t = templates.where((t) => t.template.id == plan.templateId).firstOrNull;
            if (t == null) return const Center(child: Text('Rutina no encontrada'));
            
            // Renderizar la vista de ejecución en vivo directamente
            return ExerciseExecutionScreen(
              templateId: plan.templateId!,
              exercises: t.exercises,
              onChromeVisibilityChanged: onChromeVisibilityChanged,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
