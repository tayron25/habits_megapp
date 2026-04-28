import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/exercise_execution_screen.dart';

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

          return Card(
            color: const Color(0xFF171717),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF262626)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(
                exName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
