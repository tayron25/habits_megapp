import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/roadmaps_provider.dart';

class RoadmapDetailScreen extends ConsumerStatefulWidget {
  final String roadmapId;

  const RoadmapDetailScreen({super.key, required this.roadmapId});

  @override
  ConsumerState<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends ConsumerState<RoadmapDetailScreen> {
  void _showAddMilestoneModal(BuildContext context) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Nuevo Hito', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej. Aprender sintaxis básica',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                ref.read(roadmapsProvider.notifier).addMilestone(
                      widget.roadmapId,
                      titleController.text.trim(),
                    );
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskModal(BuildContext context, String milestoneId) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Nueva Tarea Específica', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej. Leer documentación oficial',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                ref.read(roadmapsProvider.notifier).addTaskToMilestone(
                      milestoneId,
                      titleController.text.trim(),
                    );
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roadmapsAsync = ref.watch(roadmapsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: roadmapsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (roadmapsList) {
          final roadmapWithDetails = roadmapsList.where((r) => r.roadmap.id == widget.roadmapId).firstOrNull;

          if (roadmapWithDetails == null) {
            return const Center(child: Text('Roadmap no encontrado', style: TextStyle(color: Colors.white)));
          }

          final roadmap = roadmapWithDetails.roadmap;
          final milestones = roadmapWithDetails.milestones;
          final progress = roadmapWithDetails.progress;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                roadmap.title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (roadmap.description != null && roadmap.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  roadmap.description!,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 24),

              // Barra de Progreso
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFF2A2A2A),
                      color: Theme.of(context).colorScheme.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hitos del Proyecto',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => _showAddMilestoneModal(context),
                    icon: const Icon(Icons.add_circle, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (milestones.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Agrega tu primer hito para empezar a avanzar hacia tu meta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...milestones.map((mWithTasks) {
                  final milestone = mWithTasks.milestone;
                  final tasks = mWithTasks.tasks;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(16),
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
                                milestone.title,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white38),
                              onPressed: () => ref.read(roadmapsProvider.notifier).deleteMilestone(milestone.id),
                            )
                          ],
                        ),
                        const Divider(color: Color(0xFF2A2A2A)),
                        const SizedBox(height: 8),

                        ...tasks.map((task) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: task.isCompleted,
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref.read(roadmapsProvider.notifier).toggleTaskStatus(task.id, val);
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      color: task.isCompleted ? Colors.grey : Colors.white,
                                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                                  onPressed: () => ref.read(roadmapsProvider.notifier).deleteTask(task.id),
                                )
                              ],
                            ),
                          );
                        }),
                        
                        TextButton.icon(
                          onPressed: () => _showAddTaskModal(context, milestone.id),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar tarea específica'),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
