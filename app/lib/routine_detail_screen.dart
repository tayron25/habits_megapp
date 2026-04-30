import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/exercise_execution_screen.dart';
import 'package:app/gym_provider.dart';

class RoutineDetailScreen extends ConsumerWidget {
  final String templateId;
  final String templateName;
  final List<String> exercises;

  const RoutineDetailScreen({
    super.key,
    required this.templateId,
    required this.templateName,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySetsAsync = ref.watch(todayWorkoutSetsProvider(templateId));

    return Scaffold(
      appBar: AppBar(
        title: Text(templateName),
        backgroundColor: const Color(0xFF0E0E0E),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          final exName = exercises[index];

          final isCompleted = todaySetsAsync.maybeWhen(
            data: (sets) => sets.any((s) => s.exerciseName == exName),
            orElse: () => false,
          );

          return Card(
            color: isCompleted ? Colors.green.withOpacity(0.05) : const Color(0xFF171717),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isCompleted ? Colors.green.withOpacity(0.3) : const Color(0xFF262626),
                width: isCompleted ? 2 : 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: isCompleted 
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
                    ),
                  ),
              title: Text(
                exName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.white70 : Colors.white,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExerciseExecutionScreen(
                      templateId: templateId,
                      exerciseName: exName,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
