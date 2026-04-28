import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/habits_provider.dart';
import 'package:app/notes_provider.dart';
import 'package:app/tasks_provider.dart';
import 'package:app/roadmaps_provider.dart';
import 'package:app/roadmap_detail_screen.dart';

// Helper functions (moved from main.dart)
String formatTimeRemaining(DateTime? dueDate) {
  if (dueDate == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

  final difference = dueDay.difference(today).inDays;

  if (difference == 0) return 'Vence hoy';
  if (difference == 1) return 'Vence mañana';
  if (difference == -1) return 'Venció ayer';
  if (difference > 1) return 'Vence en $difference días';
  return 'Venció hace ${difference.abs()} días';
}

Color getDueDateColor(DateTime? dueDate) {
  if (dueDate == null) return Colors.grey;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

  final difference = dueDay.difference(today).inDays;

  if (difference < 0) return Colors.redAccent;
  if (difference == 0) return Colors.amber;
  return Colors.grey;
}

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Column(
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
                                                color: habitWithStatus
                                                        .isCompletedToday
                                                    ? Colors.white38
                                                    : Colors.white,
                                                decoration: habitWithStatus
                                                        .isCompletedToday
                                                    ? TextDecoration.lineThrough
                                                    : null,
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
                                                      .read(habitsProvider
                                                          .notifier)
                                                      .toggleHabit(
                                                        habitWithStatus
                                                            .habit.id,
                                                        value ?? false,
                                                      );
                                                },
                                                activeColor: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                checkColor: Colors.black,
                                                side: const BorderSide(
                                                  color: Color(0xFF4A4A4A),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
        
        // --- SECCIÓN ROADMAPS ---
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    data: (roadmapsList) {
                      if (roadmapsList.isEmpty) {
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
                            'Aún no has definido metas a largo plazo.\n¡Crea tu primer Roadmap!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                            ),
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
                                  builder: (context) => RoadmapDetailScreen(
                                    roadmapId: roadmap.id,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF2A2A2A),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          roadmap.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: const Color(0xFF2A2A2A),
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                      final pendingTasks =
                          tasksList.where((t) => !t.isCompleted).toList();

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
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pendingTasks.length,
                        itemBuilder: (context, index) {
                          final task = pendingTasks[index];

                          Color priorityColor;
                          if (task.priority == 'Alta') {
                            priorityColor = Colors.redAccent;
                          } else if (task.priority == 'Media') {
                            priorityColor = Colors.amber;
                          } else {
                            priorityColor = Colors.blueAccent;
                          }

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
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (bool? value) {
                                  if (value != null) {
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
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            formatTimeRemaining(task.dueDate),
                                            style: TextStyle(
                                              color: getDueDateColor(
                                                  task.dueDate),
                                              fontSize: 12,
                                              fontWeight:
                                                  getDueDateColor(task.dueDate) !=
                                                          Colors.grey
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
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
        
        // --- SECCIÓN NOTAS ---
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
    );
  }
}
