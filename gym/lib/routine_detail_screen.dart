import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/exercise_execution_screen.dart';
import 'package:gym/gym_provider.dart';
import 'package:gym/local_database.dart';

class RoutineDetailScreen extends ConsumerWidget {
  final String templateId;
  final String templateName;
  final List<TemplateExercise> exercises;
  final VoidCallback? onBack;

  const RoutineDetailScreen({
    super.key,
    required this.templateId,
    required this.templateName,
    required this.exercises,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySetsAsync = ref.watch(todayWorkoutSetsProvider(templateId));

    final List<List<TemplateExercise>> groupedExercises = [];
    for (var ex in exercises) {
      if (ex.supersetId != null) {
        if (groupedExercises.isNotEmpty && 
            groupedExercises.last.first.supersetId == ex.supersetId) {
          groupedExercises.last.add(ex);
        } else {
          groupedExercises.add([ex]);
        }
      } else {
        groupedExercises.add([ex]);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              )
            : null,
        title: Text(templateName),
        backgroundColor: const Color(0xFF0E0E0E),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedExercises.length,
        itemBuilder: (context, index) {
          final group = groupedExercises[index];
          final isSuperset = group.length > 1;
          
          final title = group.map((e) => e.exerciseName).join(' + ');

          // Para saber si TODO el grupo está completado
          final isCompleted = todaySetsAsync.maybeWhen(
            data: (sets) {
              return group.every((ex) => sets.any((s) => s.exerciseName == ex.exerciseName));
            },
            orElse: () => false,
          );

          return Card(
            color: isCompleted ? Colors.green.withOpacity(0.05) : const Color(0xFF171717),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isCompleted ? Colors.green.withOpacity(0.3) : (isSuperset ? Colors.purpleAccent.withOpacity(0.5) : const Color(0xFF262626)),
                width: isSuperset || isCompleted ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExerciseExecutionScreen(
                      templateId: templateId,
                      exercises: group,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSuperset)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Text(
                        group.length > 2 ? 'Circuito' : 'Superserie',
                        style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        isCompleted 
                          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                          : Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
                              ),
                            ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? Colors.white70 : Colors.white,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
