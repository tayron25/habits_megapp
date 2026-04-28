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

    // --- NUEVO: Envolvemos todo en un SingleChildScrollView ---
    return SingleChildScrollView(
      physics:
          const BouncingScrollPhysics(), // Le da un efecto rebote súper premium
      child: Column(
        children: [
          // --- SECCIÓN HÁBITOS ---
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
                // Eliminamos el SizedBox de altura fija para que crezca verticalmente libremente
                Consumer(
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
                          // Ajustamos el estado vacío para que se parezca al de las tareas
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
                          shrinkWrap:
                              true, // Se encoge a la medida de sus elementos
                          physics:
                              const NeverScrollableScrollPhysics(), // Scroll integrado al resto de la pantalla
                          itemCount: habits.length,
                          itemBuilder: (context, index) {
                            final habitWithStatus = habits[index];
                            final isCompleted =
                                habitWithStatus.isCompletedToday;

                            return Container(
                              margin: const EdgeInsets.only(
                                bottom: 8,
                              ), // Separación vertical
                              decoration: BoxDecoration(
                                color: const Color(0xFF171717),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isCompleted
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.5)
                                      : const Color(0xFF262626),
                                  width: isCompleted ? 1.5 : 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    ref
                                        .read(habitsProvider.notifier)
                                        .toggleHabit(
                                          habitWithStatus.habit.id,
                                          !isCompleted,
                                        );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Transform.scale(
                                          scale: 1.1,
                                          child: Checkbox(
                                            value: isCompleted,
                                            onChanged: (value) {
                                              ref
                                                  .read(habitsProvider.notifier)
                                                  .toggleHabit(
                                                    habitWithStatus.habit.id,
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
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            habitWithStatus.habit.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isCompleted
                                                  ? Colors.white38
                                                  : Colors.white,
                                              decoration: isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
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
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: const Color(0xFF2A2A2A),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                            return _ExpandableTaskCard(
                              task: task,
                              priorityColor: priorityColor,
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

          // --- SECCIÓN NOTAS (IDEAS) ---
          // NUEVO: Quitamos el Expanded de aquí
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Ideas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              // NUEVO: Quitamos el Expanded del "when"
              notesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                data: (notes) {
                  if (notes.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Tu mente está en blanco.\n¡Anota algo!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true, // NUEVO: Para que la lista se encoja
                    physics:
                        const NeverScrollableScrollPhysics(), // NUEVO: Desactiva el scroll interno
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151515),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.7),
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  note.content,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white70,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(notesProvider.notifier)
                                        .removeNote(note.id);
                                  },
                                ),
                                const SizedBox(height: 12),
                                Icon(
                                  note.isSynced
                                      ? Icons.cloud_done
                                      : Icons.cloud_off,
                                  color: note.isSynced
                                      ? Colors.green.withOpacity(0.5)
                                      : Colors.grey.withOpacity(0.5),
                                  size: 14,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          // Agregamos un poco de espacio al final para que quede mejor al scrollear
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// --- WIDGET INTERACTIVO DE TAREA (Acordeón) ---
class _ExpandableTaskCard extends ConsumerStatefulWidget {
  final dynamic
  task; // Usamos dynamic por si la clase Task viene de Drift directo
  final Color priorityColor;

  const _ExpandableTaskCard({required this.task, required this.priorityColor});

  @override
  ConsumerState<_ExpandableTaskCard> createState() =>
      _ExpandableTaskCardState();
}

class _ExpandableTaskCardState extends ConsumerState<_ExpandableTaskCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final hasDescription =
        task.description != null && task.description.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: widget.priorityColor, width: 4)),
      ),
      // Material e InkWell permiten que el toque tenga ese efecto dominó (ripple) visual nativo
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: hasDescription
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null, // Si no hay descripción, no reacciona al toque
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: Checkbox(
                  value: task.isCompleted,
                  activeColor: Theme.of(context).colorScheme.primary,
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
                                color: getDueDateColor(task.dueDate),
                                fontSize: 12,
                                fontWeight:
                                    getDueDateColor(task.dueDate) != Colors.grey
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                  onPressed: () {
                    ref.read(tasksProvider.notifier).removeTask(task.id);
                  },
                ),
              ),
              // --- SECCIÓN DESPLEGABLE ---
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: (_isExpanded && hasDescription)
                    ? Container(
                        width: double.infinity,
                        // Alineamos el texto de la descripción con el título (saltando el ancho del checkbox)
                        padding: const EdgeInsets.fromLTRB(52, 0, 16, 16),
                        child: Text(
                          task.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4, // Interlineado para mejor lectura
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
