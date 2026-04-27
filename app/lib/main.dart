import 'package:app/habits_provider.dart';
import 'package:app/notes_provider.dart';
import 'package:app/widgets/quick_capture_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/widgets/create_habit_modal.dart';
import 'package:app/widgets/create_template_modal.dart';
import 'package:app/gym_provider.dart';
import 'package:app/workout_session_screen.dart';
import 'package:app/widgets/create_task_modal.dart';
import 'package:app/tasks_provider.dart';
import 'package:app/roadmaps_provider.dart';
import 'package:app/widgets/create_roadmap_modal.dart';
import 'package:app/roadmap_detail_screen.dart';

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
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoy'),
        elevation: 0,
        backgroundColor: const Color(0xFF0E0E0E),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hábitos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 182,
                  child: Consumer(
                    builder: (context, ref, child) {
                      final habitsAsync = ref.watch(habitsProvider);

                      return habitsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        data: (habits) {
                          if (habits.isEmpty) {
                            return const Center(
                              child: Text(
                                'Aún no tienes hábitos.\nCrea uno para empezar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: habits.length,
                            itemBuilder: (context, index) {
                              final habitWithStatus = habits[index];

                              return SizedBox(
                                width: 200,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: index == habits.length - 1 ? 0 : 12,
                                  ),
                                  child: Card(
                                    color: const Color(0xFF171717),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: const BorderSide(
                                        color: Color(0xFF262626),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.topLeft,
                                              child: Text(
                                                habitWithStatus.habit.name,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  color: habitWithStatus.isCompletedToday ? Colors.white38 : Colors.white,
                                                  decoration: habitWithStatus.isCompletedToday ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Hoy',
                                                style: TextStyle(
                                                  color: Color(0xFF9A9A9A),
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Transform.scale(
                                                scale: 1.35,
                                                child: Checkbox(
                                                  value: habitWithStatus
                                                      .isCompletedToday,
                                                  onChanged: (value) {
                                                    ref
                                                        .read(
                                                          habitsProvider
                                                              .notifier,
                                                        )
                                                        .toggleHabit(
                                                          habitWithStatus
                                                              .habit
                                                              .id,
                                                          value ?? false,
                                                        );
                                                  },
                                                  activeColor: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  checkColor: Colors.black,
                                                  side: const BorderSide(
                                                    color: Color(0xFF4A4A4A),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // --- SECCIÓN GIMNASIO ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tus Rutinas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140, // Un poco más bajo que los hábitos
                  child: Consumer(
                    builder: (context, ref, child) {
                      final templatesAsync = ref.watch(gymTemplatesProvider);

                      return templatesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        data: (templatesList) {
                          if (templatesList.isEmpty) {
                            return const Center(
                              child: Text(
                                'Aún no tienes rutinas.\nCrea una desde el botón +.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: templatesList.length,
                            itemBuilder: (context, index) {
                              final item = templatesList[index];

                              return SizedBox(
                                width: 220,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: index == templatesList.length - 1
                                        ? 0
                                        : 12,
                                  ),
                                  child: Card(
                                    color: const Color(0xFF171717),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: const BorderSide(
                                        color: Color(0xFF262626),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.template.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item.exercises.length} ejercicios',
                                            style: const TextStyle(
                                              color: Color(0xFF9A9A9A),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          // Botón para iniciar el entrenamiento
                                          SizedBox(
                                            width: double.infinity,
                                            height: 36,
                                            child: FilledButton.icon(
                                              // En el botón "Entrenar" de la sección Gimnasio en main.dart:
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        WorkoutSessionScreen(
                                                          templateId:
                                                              item.template.id,
                                                          templateName: item
                                                              .template
                                                              .name,
                                                          exercises: item
                                                              .exercises
                                                              .map(
                                                                (e) => e
                                                                    .exerciseName,
                                                              )
                                                              .toList(),
                                                        ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.play_arrow,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Entrenar',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.2),
                                                foregroundColor: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // --- FIN SECCIÓN GIMNASIO ---
          // --- SECCIÓN ROADMAPS (METAS A LARGO PLAZO) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Roadmaps',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, child) {
                    final roadmapsAsync = ref.watch(roadmapsProvider);

                    return roadmapsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.grey))),
                      data: (roadmapsList) {
                        if (roadmapsList.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF171717),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF262626)),
                            ),
                            child: const Text(
                              'Aún no has definido metas a largo plazo.\n¡Crea tu primer Roadmap!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: roadmapsList.length,
                          itemBuilder: (context, index) {
                            final roadmapItem = roadmapsList[index];
                            final roadmap = roadmapItem.roadmap;
                            final progress = roadmapItem.progress;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RoadmapDetailScreen(roadmapId: roadmap.id),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF2A2A2A)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            roadmap.title,
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}%',
                                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: const Color(0xFF2A2A2A),
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // --- FIN SECCIÓN ROADMAPS ---
          // --- SECCIÓN TAREAS PENDIENTES ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tareas Pendientes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, child) {
                    final tasksAsync = ref.watch(tasksProvider);

                    return tasksAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text(
                          'Error: $error',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      data: (tasksList) {
                        // Filtramos para mostrar solo las que NO están completadas
                        final pendingTasks = tasksList
                            .where((t) => !t.isCompleted)
                            .toList();

                        if (pendingTasks.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF171717),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF262626),
                              ),
                            ),
                            child: const Text(
                              '¡Todo al día! 😎\nNo hay tareas pendientes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap:
                              true, // CRÍTICO: Permite que el ListView viva dentro de un SingleChildScrollView
                          physics:
                              const NeverScrollableScrollPhysics(), // Desactiva el scroll interno de esta lista
                          itemCount: pendingTasks.length,
                          itemBuilder: (context, index) {
                            final task = pendingTasks[index];

                            // Asignamos colores según la prioridad
                            Color priorityColor;
                            if (task.priority == 'Alta')
                              priorityColor = Colors.redAccent;
                            else if (task.priority == 'Media')
                              priorityColor = Colors.amber;
                            else
                              priorityColor = Colors.blueAccent;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border(
                                  left: BorderSide(
                                    color: priorityColor,
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: Checkbox(
                                  value: task.isCompleted,
                                  activeColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  onChanged: (bool? value) {
                                    if (value != null) {
                                      // Marcamos la tarea como completada (desaparecerá de esta lista)
                                      ref
                                          .read(tasksProvider.notifier)
                                          .toggleTask(task.id, value);
                                    }
                                  },
                                ),
                                title: Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: task.dueDate != null
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Vence el ${task.dueDate!.day}/${task.dueDate!.month}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white38,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(tasksProvider.notifier)
                                        .removeTask(task.id);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // --- FIN SECCIÓN TAREAS ---
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tu mente está en blanco.\n¡Anota algo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF2A2A2A)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                note.content,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              note.isSynced
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: note.isSynced ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Primero mostramos un menú para elegir qué crear
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
                  ListTile(
                    leading: const Icon(Icons.flash_on, color: Colors.amber),
                    title: const Text('Captura Rápida (Nota)'),
                    onTap: () {
                      Navigator.pop(context); // Cierra el menú
                      showModalBottomSheet(
                        // Abre el modal de nota
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const QuickCaptureModal(),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.repeat,
                      color: Colors.greenAccent,
                    ),
                    title: const Text('Nuevo Hábito'),
                    onTap: () {
                      Navigator.pop(context); // Cierra el menú
                      showModalBottomSheet(
                        // Abre el modal de hábito
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateHabitModal(),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.fitness_center,
                      color: Colors.blueAccent,
                    ),
                    title: const Text('Nueva Rutina de Gym'),
                    onTap: () {
                      Navigator.pop(context); // Cierra el menú
                      showModalBottomSheet(
                        // Abre el modal de la rutina
                        context: context,
                        isScrollControlled:
                            true, // ¡CRÍTICO para que tome el alto que definimos!
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateTemplateModal(),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.purpleAccent,
                    ),
                    title: const Text('Nueva Tarea'),
                    onTap: () {
                      Navigator.pop(context); // Cierra el menú
                      showModalBottomSheet(
                        // Abre el modal de la tarea
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const CreateTaskModal(),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.map,
                      color: Colors.orangeAccent,
                    ),
                    title: const Text('Nuevo Roadmap'),
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
