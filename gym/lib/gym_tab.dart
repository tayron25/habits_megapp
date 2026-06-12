import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym_provider.dart';
import 'package:gym/routine_detail_screen.dart';
import 'package:gym/widgets/create_template_modal.dart';

class GymTab extends ConsumerStatefulWidget {
  const GymTab({super.key});

  @override
  ConsumerState<GymTab> createState() => _GymTabState();
}

class _GymTabState extends ConsumerState<GymTab> {
  bool _forceShowTemplates = false;

  void _showEditTemplateModal(WorkoutTemplateWithExercises item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(child: CreateTemplateModal(template: item)),
    );
  }

  Future<void> _confirmDeleteTemplate(WorkoutTemplateWithExercises item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Eliminar rutina', style: TextStyle(color: Colors.white)),
        content: Text(
          'Se eliminara "${item.template.name}" y sus planes futuros del calendario.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    ref.read(gymTemplatesProvider.notifier).deleteTemplate(item.template.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rutina "${item.template.name}" eliminada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(gymTemplatesProvider);
    final todayLogAsync = ref.watch(todayWorkoutLogProvider);

    return todayLogAsync.when(
      data: (log) {
        if (log != null && log.templateId != null && !_forceShowTemplates) {
          return templatesAsync.when(
            data: (templatesList) {
              WorkoutTemplateWithExercises? matched;
              try {
                matched = templatesList.firstWhere((t) => t.template.id == log.templateId);
              } catch (_) {}

              if (matched != null) {
                // REDIRECCIÓN DIRECTA
                return RoutineDetailScreen(
                  templateId: matched.template.id,
                  templateName: matched.template.name,
                  exercises: matched.exercises,
                  onBack: () {
                    setState(() {
                      _forceShowTemplates = true;
                    });
                  },
                );
              }
              return _buildTemplatesGrid(context, templatesAsync, true);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildTemplatesGrid(context, templatesAsync, false),
          );
        }
        return _buildTemplatesGrid(context, templatesAsync, log != null);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildTemplatesGrid(context, templatesAsync, false),
    );
  }

  Widget _buildTemplatesGrid(BuildContext context, AsyncValue<List<WorkoutTemplateWithExercises>> templatesAsync, bool hasActiveLog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasActiveLog && _forceShowTemplates)
           Padding(
             padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
             child: InkWell(
               onTap: () {
                 setState(() {
                   _forceShowTemplates = false;
                 });
               },
               borderRadius: BorderRadius.circular(16),
               child: Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), width: 1.5),
                 ),
                 child: Column(
                   children: [
                     Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary, size: 40),
                     const SizedBox(height: 12),
                     Text('Continuar Entrenamiento Actual', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                   ],
                 ),
               ),
             ),
           ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Tus Rutinas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
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
                    'Aún no tienes rutinas.\nCrea una con el botón +.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: templatesList.length,
                itemBuilder: (context, index) {
                  final item = templatesList[index];
                  final muscleGroups = item.exercises.map((e) => e.muscleGroup).toSet().toList();

                  return Card(
                    color: const Color(0xFF1A1A1A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Color(0xFF2A2A2A),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.template.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                color: const Color(0xFF242424),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditTemplateModal(item);
                                  } else if (value == 'delete') {
                                    _confirmDeleteTemplate(item);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.white70, size: 18),
                                        SizedBox(width: 8),
                                        Text('Editar', style: TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        SizedBox(width: 8),
                                        Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: muscleGroups.take(2).map((mg) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(mg, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                            )).toList(),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RoutineDetailScreen(
                                      templateId: item.template.id,
                                      templateName: item.template.name,
                                      exercises: item.exercises,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: const Text(
                                'Entrenar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                                foregroundColor:
                                    Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
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
