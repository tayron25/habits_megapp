import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/habits_provider.dart';
import 'package:app/life_areas_provider.dart';
import 'package:app/local_database.dart';
import 'package:app/notes_provider.dart';
import 'package:app/tasks_provider.dart';
import 'package:app/roadmaps_provider.dart';
import 'package:app/roadmap_detail_screen.dart';
import 'package:app/widgets/create_task_modal.dart';
import 'package:app/widgets/create_habit_modal.dart';
import 'package:app/widgets/quick_capture_modal.dart';
import 'package:app/widgets/create_roadmap_modal.dart';

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

void _showSmartDeleteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String type,
  required dynamic id,
  dynamic item,
}) {
  if (type == 'note') {
    _showProcessNoteDialog(context: context, ref: ref, note: item);
    return;
  }

  if (type == 'roadmap') {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: const Text('¿Seguro que deseas eliminar esto?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (type == 'roadmap') ref.read(roadmapsProvider.notifier).deleteRoadmap(id);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  } else if (type == 'task') {
    _showProcessTaskDialog(context: context, ref: ref, taskId: id);
  } else {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('¿Qué pasó con este elemento?', style: TextStyle(color: Colors.white)),
        content: const Text('Puedes marcarlo como completado o borrarlo definitivamente.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              if (type == 'task') ref.read(tasksProvider.notifier).toggleTask(id, true);
              if (type == 'habit') ref.read(habitsProvider.notifier).toggleHabit(id, true);
              Navigator.pop(ctx);
            },
            child: const Text('Ya lo hice', style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () {
              if (type == 'task') ref.read(tasksProvider.notifier).removeTask(id);
              if (type == 'habit') ref.read(habitsProvider.notifier).removeHabit(id);
              Navigator.pop(ctx);
            },
            child: const Text('Borrar definitivamente', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

void _showProcessTaskDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String taskId,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Que paso con esta tarea?', style: TextStyle(color: Colors.white)),
      content: const Text(
        'La quitaremos de la vista activa, pero quedara guardada como historial.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            ref.read(tasksProvider.notifier).processTask(taskId, didComplete: false);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tarea registrada como no hecha')),
            );
          },
          child: const Text('No se hizo', style: TextStyle(color: Colors.orangeAccent)),
        ),
        TextButton(
          onPressed: () {
            ref.read(tasksProvider.notifier).removeTask(taskId);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tarea eliminada definitivamente')),
            );
          },
          child: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.redAccent)),
        ),
        FilledButton(
          onPressed: () {
            ref.read(tasksProvider.notifier).processTask(taskId, didComplete: true);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tarea completada y registrada')),
            );
          },
          child: const Text('Se hizo'),
        ),
      ],
    ),
  );
}

void _showProcessNoteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required dynamic note,
}) {
  final rootContext = context;
  String? selectedLifeAreaId;

  showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (dialogContext, ref, _) {
        final areasAsync = ref.watch(lifeAreasProvider);

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Procesar pensamiento', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Asocialo a un area de vida o descartalo de Ideas. En ambos casos queda registrado.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 16),
                areasAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Text('Error cargando areas: $error', style: const TextStyle(color: Colors.redAccent)),
                  data: (areas) {
                    if (areas.isEmpty) {
                      return const Text('No hay areas de vida todavia.', style: TextStyle(color: Colors.white38));
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: areas.map((area) {
                        final selected = selectedLifeAreaId == area.id;
                        return ChoiceChip(
                          label: Text('${area.icon ?? ''} ${area.name}'.trim()),
                          selected: selected,
                          onSelected: (value) {
                            setState(() => selectedLifeAreaId = value ? area.id : null);
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(notesProvider.notifier).processNote(note.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text('Pensamiento registrado y quitado de Ideas')),
                  );
                },
                child: const Text('Descartar', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () {
                  ref.read(notesProvider.notifier).removeNote(note.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text('Pensamiento eliminado definitivamente')),
                  );
                },
                child: const Text('Eliminar definitivamente', style: TextStyle(color: Colors.redAccent)),
              ),
              FilledButton(
                onPressed: selectedLifeAreaId == null
                    ? null
                    : () {
                        ref.read(notesProvider.notifier).processNote(note.id, lifeAreaId: selectedLifeAreaId);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(content: Text('Pensamiento categorizado')),
                        );
                      },
                child: const Text('Guardar en area'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showOptionsBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String type,
  required dynamic item,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: const Text('Editar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                if (type == 'task') {
                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => CreateTaskModal(existingTask: item));
                } else if (type == 'habit') {
                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => CreateHabitModal(existingHabit: item.habit));
                } else if (type == 'note') {
                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => QuickCaptureModal(existingNote: item));
                } else if (type == 'roadmap') {
                  final roadmapItem = item is RoadmapWithDetails ? item : null;
                  final roadmap = roadmapItem?.roadmap ?? item;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (c) => CreateRoadmapModal(
                      existingRoadmap: roadmap,
                      initialShowOnHome: roadmapItem?.showOnHome ?? true,
                      initialLifeAreaId: roadmapItem?.lifeAreaId,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                (type == 'note' || type == 'task') ? Icons.done_all_rounded : Icons.delete_outline,
                color: (type == 'note' || type == 'task') ? Colors.greenAccent : Colors.redAccent,
              ),
              title: Text(
                (type == 'note' || type == 'task') ? 'Procesar' : 'Eliminar',
                style: TextStyle(color: (type == 'note' || type == 'task') ? Colors.greenAccent : Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSmartDeleteDialog(
                  context: context,
                  ref: ref,
                  type: type,
                  id: type == 'habit' ? item.habit.id : (type == 'roadmap' && item is RoadmapWithDetails ? item.roadmap.id : item.id),
                  item: item,
                );
              },
            ),
          ],
        ),
      );
    },
  );
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
                            final habit = habitWithStatus.habit;
                            final isCompleted = habitWithStatus.isCompletedToday;
                            final isGoalMet = habitWithStatus.isGoalMet;
                            final hasGoal = habit.goalAmount > 1;

                            String periodText = '';
                            switch (habit.goalPeriod) {
                              case 'day': periodText = 'hoy'; break;
                              case 'week': periodText = 'esta semana'; break;
                              case 'month': periodText = 'este mes'; break;
                              case 'year': periodText = 'este año'; break;
                              default: periodText = '';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF171717),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isGoalMet
                                      ? Colors.greenAccent.withOpacity(0.5)
                                      : (isCompleted
                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                          : const Color(0xFF262626)),
                                  width: (isGoalMet || isCompleted) ? 1.5 : 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    _showOptionsBottomSheet(
                                      context: context,
                                      ref: ref,
                                      type: 'habit',
                                      item: habitWithStatus,
                                    );
                                  },
                                  onTap: () {
                                    ref.read(habitsProvider.notifier).toggleHabit(
                                      habit.id,
                                      !isCompleted,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Transform.scale(
                                          scale: 1.1,
                                          child: Checkbox(
                                            value: isCompleted,
                                            onChanged: (value) {
                                              ref.read(habitsProvider.notifier).toggleHabit(
                                                habit.id,
                                                value ?? false,
                                              );
                                            },
                                            activeColor: isGoalMet ? Colors.greenAccent : Theme.of(context).colorScheme.primary,
                                            checkColor: Colors.black,
                                            side: const BorderSide(
                                              color: Color(0xFF4A4A4A),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                habit.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isCompleted ? Colors.white38 : Colors.white,
                                                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              if (hasGoal) ...[
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: LinearProgressIndicator(
                                                          value: (habitWithStatus.currentProgress / habit.goalAmount).clamp(0.0, 1.0),
                                                          backgroundColor: const Color(0xFF2A2A2A),
                                                          color: isGoalMet ? Colors.greenAccent : Theme.of(context).colorScheme.primary,
                                                          minHeight: 4,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${habitWithStatus.currentProgress} / ${habit.goalAmount} $periodText',
                                                      style: TextStyle(
                                                        color: isGoalMet ? Colors.greenAccent : Colors.grey,
                                                        fontSize: 12,
                                                        fontWeight: isGoalMet ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
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
                const SizedBox(height: 12),
                const _NextRoadmapActions(),
              ],
            ),
          ),

          // --- SECCIÓN ROADMAPS ---
          Offstage(
            offstage: true,
            child: Padding(
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

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF171717),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF2A2A2A),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
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
                                  onLongPress: () {
                                    HapticFeedback.heavyImpact();
                                    _showOptionsBottomSheet(
                                      context: context,
                                      ref: ref,
                                      type: 'roadmap',
                                      item: roadmapItem,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
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
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${(progress * 100).toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  roadmapItem.showOnHome ? 'En Hoy' : 'Oculto',
                                                  style: TextStyle(
                                                    color: roadmapItem.showOnHome ? const Color(0xFF8FD8FF) : Colors.white38,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
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
          ),

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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onLongPress: () {
                              HapticFeedback.heavyImpact();
                              _showOptionsBottomSheet(
                                context: context,
                                ref: ref,
                                type: 'note',
                                item: note,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const _RoadmapsSection(),
          // Agregamos un poco de espacio al final para que quede mejor al scrollear
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// --- WIDGET INTERACTIVO DE TAREA (Acordeón) ---
class _RoadmapsSection extends ConsumerWidget {
  const _RoadmapsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapsAsync = ref.watch(roadmapsProvider);

    return Padding(
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
          roadmapsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error: $err', style: const TextStyle(color: Colors.grey)),
            ),
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
                    'Aun no has definido metas a largo plazo.\nCrea tu primer Roadmap.',
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoadmapDetailScreen(roadmapId: roadmap.id),
                            ),
                          );
                        },
                        onLongPress: () {
                          HapticFeedback.heavyImpact();
                          _showOptionsBottomSheet(
                            context: context,
                            ref: ref,
                            type: 'roadmap',
                            item: roadmapItem,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        roadmapItem.showOnHome ? 'En Hoy' : 'Oculto',
                                        style: TextStyle(
                                          color: roadmapItem.showOnHome ? const Color(0xFF8FD8FF) : Colors.white38,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NextRoadmapAction {
  const _NextRoadmapAction({
    required this.roadmap,
    required this.milestone,
    required this.task,
  });

  final Roadmap roadmap;
  final RoadmapMilestone milestone;
  final MilestoneTask task;
}

class _NextRoadmapActions extends ConsumerWidget {
  const _NextRoadmapActions();

  List<_NextRoadmapAction> _buildActions(List<RoadmapWithDetails> roadmaps) {
    final actions = <_NextRoadmapAction>[];

    for (final roadmap in roadmaps) {
      if (!roadmap.showOnHome) continue;

      for (final milestone in roadmap.milestones) {
        final pendingTasks = milestone.tasks.where((task) => !task.isCompleted);
        if (pendingTasks.isNotEmpty) {
          actions.add(
            _NextRoadmapAction(
              roadmap: roadmap.roadmap,
              milestone: milestone.milestone,
              task: pendingTasks.first,
            ),
          );
          break;
        }
      }
    }

    return actions;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapsAsync = ref.watch(roadmapsProvider);

    return roadmapsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (roadmaps) {
        final actions = _buildActions(roadmaps);
        if (actions.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Siguiente de roadmaps',
              style: TextStyle(
                color: Color(0xFF8FD8FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            ...actions.map((action) => _NextRoadmapActionCard(action: action)),
          ],
        );
      },
    );
  }
}

class _NextRoadmapActionCard extends ConsumerWidget {
  const _NextRoadmapActionCard({required this.action});

  final _NextRoadmapAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const accent = Color(0xFF8FD8FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.45), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoadmapDetailScreen(roadmapId: action.roadmap.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Checkbox(
                  value: false,
                  activeColor: accent,
                  checkColor: Colors.black,
                  side: const BorderSide(color: Color(0xFF5C7F90)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (value) {
                    if (value == true) {
                      ref.read(roadmapsProvider.notifier).toggleTaskStatus(action.task.id, true);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${action.roadmap.title} - ${action.milestone.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9BB8C6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          onLongPress: () {
            HapticFeedback.heavyImpact();
            _showOptionsBottomSheet(
              context: context,
              ref: ref,
              type: 'task',
              item: task,
            );
          },
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
