import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym_provider.dart';
import 'package:gym/local_database.dart';

class DailyPreviewSheet extends ConsumerWidget {
  final PlannedWorkout plan;

  const DailyPreviewSheet({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(gymTemplatesProvider).value ?? [];
    final templateWithExercises = templates.firstWhere(
      (t) => t.template.id == plan.templateId,
      orElse: () => WorkoutTemplateWithExercises(
        template: WorkoutTemplate(id: '', name: 'Cargando...', createdAt: DateTime.now(), isSynced: true),
        exercises: [],
      ),
    );

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(templateWithExercises.template.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Previsualización de Cargas (Estimado)', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: templateWithExercises.exercises.length,
              itemBuilder: (context, index) {
                final ex = templateWithExercises.exercises[index];
                return FutureBuilder<WorkoutSet?>(
                  future: ref.read(gymRepositoryProvider).getSuggestedNextSet(ex.exerciseName, 0, templateId: plan.templateId),
                  builder: (context, snapshot) {
                    String sub = 'Esperando datos...';
                    if (snapshot.connectionState == ConnectionState.done) {
                      if (snapshot.hasData && snapshot.data != null) {
                        final s = snapshot.data!;
                        sub = '${s.weight} kg x ${s.reps} reps (aprox)';
                      } else {
                        sub = 'Primera vez (sin datos)';
                      }
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.fitness_center, color: Colors.greenAccent, size: 20),
                      ),
                      title: Text(ex.exerciseName, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(sub, style: const TextStyle(color: Colors.grey)),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          )
        ],
      ),
    );
  }
}
