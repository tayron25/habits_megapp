import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'active_workout_provider.dart';
import 'gym_provider.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  final String templateId;
  final String templateName;
  final List<String> exercises;

  const WorkoutSessionScreen({
    super.key,
    required this.templateId,
    required this.templateName,
    required this.exercises,
  });

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  @override
  void initState() {
    super.initState();
    // Inicializamos el estado con los ejercicios de la plantilla
    Future.microtask(() => 
      ref.read(activeWorkoutProvider.notifier).init(widget.exercises)
    );
  }

  void _finishWorkout() async {
    final sessionData = ref.read(activeWorkoutProvider);
    final List<Map<String, dynamic>> setsToSave = [];

    sessionData.forEach((exerciseName, sets) {
      for (var s in sets) {
        if (s.reps > 0) { // Solo guardamos series con repeticiones
          setsToSave.add({
            'exercise_name': exerciseName,
            'weight': s.weight,
            'reps': s.reps,
          });
        }
      }
    });

    if (setsToSave.isEmpty) {
      Navigator.pop(context);
      return;
    }

    // Guardamos en la base de datos (Drift + Supabase)
    await ref.read(gymRepositoryProvider).saveWorkoutLog(widget.templateId, setsToSave);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Entrenamiento guardado! 💪')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutState = ref.watch(activeWorkoutProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        title: Text(widget.templateName),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: const Text('TERMINAR', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.exercises.length,
        itemBuilder: (context, index) {
          final exName = widget.exercises[index];
          final sets = workoutState[exName] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
              const SizedBox(height: 10),
              // Tabla de Series
              ...sets.asMap().entries.map((entry) {
                final setIndex = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 12, backgroundColor: Colors.grey[800], 
                        child: Text('${setIndex + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))),
                      const SizedBox(width: 15),
                      // Input Peso
                      Expanded(
                        child: _inputField('kg', (val) => 
                          ref.read(activeWorkoutProvider.notifier).updateSet(exName, setIndex, weight: double.tryParse(val))),
                      ),
                      const SizedBox(width: 10),
                      // Input Reps
                      Expanded(
                        child: _inputField('reps', (val) => 
                          ref.read(activeWorkoutProvider.notifier).updateSet(exName, setIndex, reps: int.tryParse(val))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                        onPressed: () => ref.read(activeWorkoutProvider.notifier).removeSet(exName, setIndex),
                      )
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => ref.read(activeWorkoutProvider.notifier).addSet(exName),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir Serie'),
              ),
              const Divider(color: Colors.white10, height: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _inputField(String label, Function(String) onChanged) {
    return TextField(
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}