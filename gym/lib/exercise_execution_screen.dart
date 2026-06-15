import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym_provider.dart';
import 'package:gym/local_database.dart';

class ExerciseSetDraft {
  String? id; // null si no se ha guardado
  double weight;
  int reps;
  String? note; // NUEVO: Nota opcional
  bool isCompleted;

  ExerciseSetDraft({
    this.id,
    required this.weight,
    required this.reps,
    this.note,
    this.isCompleted = false,
  });
}

class ExerciseExecutionScreen extends ConsumerStatefulWidget {
  final String templateId;
  final List<TemplateExercise> exercises;
  final ValueChanged<bool>? onChromeVisibilityChanged;

  const ExerciseExecutionScreen({
    super.key,
    required this.templateId,
    required this.exercises,
    this.onChromeVisibilityChanged,
  });

  @override
  ConsumerState<ExerciseExecutionScreen> createState() =>
      _ExerciseExecutionScreenState();
}

class _ExerciseExecutionScreenState extends ConsumerState<ExerciseExecutionScreen> {
  bool _isLoading = true;
  String? _workoutLogId;
  late List<TemplateExercise> _activeExercises; // Independiente de la plantilla base
  final Map<String, List<ExerciseSetDraft>> _sets = {};
  final ScrollController _scrollController = ScrollController();
  bool _chromeVisible = true;
  bool _isReorderMode = false;

  // Cronómetro (Cuenta regresiva)
  int _seconds = 90; // Default 1:30
  Timer? _timer;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    // Clonamos los ejercicios para permitir adiciones/borrados en vivo
    _activeExercises = List.from(widget.exercises);
    _scrollController.addListener(_handleScroll);
    _loadData();
  }

  @override
  void dispose() {
    widget.onChromeVisibilityChanged?.call(true);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _setChromeVisible(bool visible) {
    if (_chromeVisible == visible) return;
    if (mounted) {
      setState(() => _chromeVisible = visible);
    } else {
      _chromeVisible = visible;
    }
    widget.onChromeVisibilityChanged?.call(visible);
  }

  void _handleScroll() {
    if (_isReorderMode) return;
    if (!_scrollController.hasClients) return;
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse && _scrollController.offset > 24) {
      _setChromeVisible(false);
    } else if (direction == ScrollDirection.forward) {
      _setChromeVisible(true);
    }
  }

  Future<void> _loadData() async {
    final repo = ref.read(gymRepositoryProvider);

    try {
      _workoutLogId = (await repo.getTodayWorkoutLogForTemplate(widget.templateId))?.id;

      for (var ex in _activeExercises) {
        await _initExerciseData(ex.exerciseName);
      }
    } catch (e) {
      print('Error cargando ejercicio: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initExerciseData(String exName) async {
    final repo = ref.read(gymRepositoryProvider);
    final todaySets = _workoutLogId == null
        ? <WorkoutSet>[]
        : await repo.getSetsForLogAndExercise(_workoutLogId!, exName);

    final lastSets = await repo.getLastWorkoutSets(exName, excludeLogId: _workoutLogId);
    final List<ExerciseSetDraft> drafts = [];

    // 1. Cargar sets ya completados hoy desde la base de datos
    for (var s in todaySets) {
      drafts.add(ExerciseSetDraft(
        id: s.id,
        weight: s.weight,
        reps: s.reps,
        note: s.note,
        isCompleted: true,
      ));
    }

    // 2. Autocompletar (pre-cargar) el resto de los sets basados en la sesión anterior
    final targetSetCount = lastSets.isNotEmpty ? lastSets.length : 1;
    for (int i = drafts.length; i < targetSetCount; i++) {
      final suggested = await repo.getSuggestedNextSet(
        exName,
        i,
        currentLogId: _workoutLogId,
        templateId: widget.templateId,
      );
      if (suggested != null) {
        drafts.add(ExerciseSetDraft(weight: suggested.weight, reps: suggested.reps));
      } else {
        drafts.add(ExerciseSetDraft(weight: 0, reps: 0));
      }
    }

    if (drafts.isEmpty) {
      drafts.add(ExerciseSetDraft(weight: 0, reps: 0));
    }

    _sets[exName] = drafts;
  }

  // --- Helpers para edición rápida ---
  void _editValueDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required void Function(String) onSaved,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
          ),
          onSubmitted: (val) {
            onSaved(val);
            Navigator.pop(context);
          },
        ),
        actions: _chromeVisible ? [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              onSaved(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ] : null,
      ),
    );
  }

  void _editTimer(BuildContext context) {
    _editValueDialog(
      context: context,
      title: 'Segundos de Descanso',
      initialValue: _seconds.toString(),
      onSaved: (val) {
        final parsed = int.tryParse(val) ?? _seconds;
        setState(() => _seconds = parsed);
      },
    );
  }

  void _editWeight(BuildContext context, String exName, int index) {
    final s = _sets[exName]![index];
    if (s.isCompleted) return;
    _editValueDialog(
      context: context,
      title: 'Kilos',
      initialValue: s.weight.toStringAsFixed(1).replaceAll('.0', ''),
      onSaved: (val) {
        final parsed = double.tryParse(val.replaceAll(',', '.')) ?? s.weight;
        setState(() => s.weight = parsed);
      },
    );
  }

  void _editReps(BuildContext context, String exName, int index) {
    final s = _sets[exName]![index];
    if (s.isCompleted) return;
    _editValueDialog(
      context: context,
      title: 'Repeticiones',
      initialValue: s.reps.toString(),
      onSaved: (val) {
        final parsed = int.tryParse(val) ?? s.reps;
        setState(() => s.reps = parsed);
      },
    );
  }

  void _editNote(BuildContext context, String exName, int index) {
    final s = _sets[exName]![index];
    final controller = TextEditingController(text: s.note ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nota de Serie', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
            hintText: 'Ej: Molestia en el hombro, o sentí el peso muy ligero...',
            hintStyle: TextStyle(color: Color(0xFF5A5A5A)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              final newNote = controller.text.trim().isEmpty ? null : controller.text.trim();
              setState(() {
                s.note = newNote;
              });
              if (s.isCompleted && s.id != null) {
                ref.read(gymRepositoryProvider).updateWorkoutSet(s.id!, s.weight, s.reps, note: newNote);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // --- Cronómetro (Cuenta Regresiva) ---
  void _toggleTimer() {
    if (_isTimerRunning) {
      _timer?.cancel();
    } else {
      if (_seconds <= 0) _seconds = 90; // Reset si ya había terminado
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_seconds > 0) {
              _seconds--;
            } else {
              _timer?.cancel();
              _isTimerRunning = false;
              HapticFeedback.heavyImpact(); // Vibración
              SystemSound.play(SystemSoundType.click); // Sonido
            }
          });
        }
      });
    }
    setState(() => _isTimerRunning = !_isTimerRunning);
  }

  void _adjustTimer(int delta) {
    setState(() {
      _seconds = (_seconds + delta).clamp(0, 3600);
    });
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- Series ---
  void _addSet(String exName) async {
    final repo = ref.read(gymRepositoryProvider);
    final currentSetCount = _sets[exName]?.length ?? 0;
    
    double nextWeight = 0;
    int nextReps = 0;

    // AUTOCOMPLETADO INTELIGENTE: Predice el siguiente set basado en la última sesión
    final suggested = await repo.getSuggestedNextSet(
      exName,
      currentSetCount,
      currentLogId: _workoutLogId,
      templateId: widget.templateId,
    );
    if (suggested != null) {
      nextWeight = suggested.weight;
      nextReps = suggested.reps;
    } else if (currentSetCount > 0) {
      // Fallback a copiar el set anterior
      nextWeight = _sets[exName]!.last.weight;
      nextReps = _sets[exName]!.last.reps;
    }

    setState(() {
      _sets[exName]!.add(ExerciseSetDraft(weight: nextWeight, reps: nextReps));
    });
  }

  void _removeSet(String exName, int index) async {
    final s = _sets[exName]![index];
    if (s.id != null) {
      await ref.read(gymRepositoryProvider).deleteWorkoutSet(s.id!);
    }
    setState(() {
      _sets[exName]!.removeAt(index);
    });
  }

  Future<void> _toggleSetCompletion(String exName, int index) async {
    final s = _sets[exName]![index];
    final repo = ref.read(gymRepositoryProvider);

    if (!s.isCompleted) {
      _workoutLogId ??= await repo.getOrCreateTodayWorkoutLog(widget.templateId);
      final newId = await repo.addWorkoutSet(
        workoutLogId: _workoutLogId!,
        exerciseName: exName,
        weight: s.weight,
        reps: s.reps,
        note: s.note,
      );
      setState(() {
        s.id = newId;
        s.isCompleted = true;
      });
      if (!_isTimerRunning) {
        _seconds = 90;
        _toggleTimer();
      }
    } else {
      if (s.id != null) {
        await repo.deleteWorkoutSet(s.id!);
      }
      setState(() {
        s.id = null;
        s.isCompleted = false;
      });
    }
  }

  void _updateWeight(String exName, int index, double delta) {
    final s = _sets[exName]![index];
    if (s.isCompleted) return;
    setState(() {
      s.weight = (s.weight + delta).clamp(0.0, 999.0);
    });
  }

  void _updateReps(String exName, int index, int delta) {
    final s = _sets[exName]![index];
    if (s.isCompleted) return;
    setState(() {
      s.reps = (s.reps + delta).clamp(0, 999);
    });
  }

  // --- Ad-Hoc Flexibilidad ---
  void _removeExercise(String exName) {
    setState(() {
      _activeExercises.removeWhere((e) => e.exerciseName == exName);
    });
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    if (oldIndex >= _activeExercises.length) return;
    if (newIndex > _activeExercises.length) {
      newIndex = _activeExercises.length;
    }
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final exercise = _activeExercises.removeAt(oldIndex);
      _activeExercises.insert(newIndex, exercise);
    });
  }

  void _setReorderMode(bool enabled) {
    if (_isReorderMode == enabled) return;
    setState(() {
      _isReorderMode = enabled;
    });
    if (enabled) {
      _setChromeVisible(true);
    }
  }

  void _showAddExerciseDialog() async {
    final repo = ref.read(gymRepositoryProvider);
    final catalog = await repo.getExerciseCatalog();
    
    // Ignorando la complejidad de un modal completo por ahora, mostraremos una lista rápida
    final allExercises = catalog.values.expand((e) => e).toList()..sort();
    
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Añadir Ejercicio (Ad-Hoc)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allExercises.length,
                itemBuilder: (context, idx) {
                  final ex = allExercises[idx];
                  return ListTile(
                    title: Text(ex, style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.pop(context);
                      // Añadir al estado local de la sesión (sin modificar la plantilla base)
                      setState(() {
                        if (!_activeExercises.any((e) => e.exerciseName == ex)) {
                           _activeExercises.add(TemplateExercise(
                             id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                             templateId: widget.templateId,
                             muscleGroup: 'General',
                             exerciseName: ex,
                             createdAt: DateTime.now(),
                             isSynced: false,
                           ));
                        }
                      });
                      await _initExerciseData(ex);
                      setState(() {}); // Refrescar UI
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final title = _activeExercises.length > 2 
        ? 'Circuito (${_activeExercises.length} ejercicios)'
        : _activeExercises.map((e) => e.exerciseName).join(' + ');

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: _chromeVisible ? kToolbarHeight : 0,
        title: _chromeVisible
            ? Text(title, style: const TextStyle(fontSize: 16))
            : const SizedBox.shrink(),
        backgroundColor: const Color(0xFF0E0E0E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: _showAddExerciseDialog,
            tooltip: 'Añadir Ejercicio extra',
          )
        ],
      ),
      body: Column(
        children: [
          // Cronómetro centralizado
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text('Descanso', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _adjustTimer(-30),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFF262626), shape: BoxShape.circle),
                          child: const Icon(Icons.remove, size: 14, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _editTimer(context),
                        child: Text(
                          _formatTime(_seconds),
                          style: TextStyle(
                            color: _seconds == 0 
                                ? Colors.redAccent 
                                : (_isTimerRunning ? Colors.greenAccent : Colors.white),
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _adjustTimer(30),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFF262626), shape: BoxShape.circle),
                          child: const Icon(Icons.add, size: 14, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      onPressed: _toggleTimer,
                      icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow, size: 20),
                      color: _isTimerRunning ? Colors.orangeAccent : Colors.greenAccent,
                      style: IconButton.styleFrom(
                        backgroundColor: _isTimerRunning 
                            ? Colors.orangeAccent.withOpacity(0.15) 
                            : Colors.greenAccent.withOpacity(0.15),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isReorderMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swap_vert, color: Colors.greenAccent),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ordenar ejercicios',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _setReorderMode(false),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
            ),

          // Lista de Ejercicios
          Expanded(
            child: ReorderableListView.builder(
              scrollController: _scrollController,
              buildDefaultDragHandles: false,
              onReorder: _reorderExercises,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _activeExercises.length + 1, // +1 para el botón final
              itemBuilder: (context, index) {
                if (index == _activeExercises.length) {
                  if (_isReorderMode) {
                    return const SizedBox.shrink(key: ValueKey('add_exercise_button'));
                  }
                  return Padding(
                    key: const ValueKey('add_exercise_button'),
                    padding: const EdgeInsets.only(bottom: 40, top: 20),
                    child: OutlinedButton.icon(
                      onPressed: _showAddExerciseDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir Ejercicio Ad-Hoc'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF333333)),
                      ),
                    ),
                  );
                }
                
                final exName = _activeExercises[index].exerciseName;
                return _buildExerciseBlock(exName, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseBlock(String exName, int exerciseIndex) {
    final sets = _sets[exName] ?? [];
    final repo = ref.read(gymRepositoryProvider);

    if (_isReorderMode) {
      return Container(
        key: ValueKey('exercise_$exName'),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: exerciseIndex,
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.drag_indicator, color: Colors.greenAccent),
              ),
            ),
            Expanded(
              child: Text(
                exName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${sets.length} series',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      key: ValueKey('exercise_$exName'),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título del Ejercicio, PR Reactivo y Opciones
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setReorderMode(true),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(0, 8, 12, 8),
                  child: Icon(Icons.drag_indicator, color: Colors.grey),
                ),
              ),
              Expanded(
                child: Text(
                  exName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  // STREAM BUILDER PARA RECORD PERSONAL EN TIEMPO REAL
                  StreamBuilder<WorkoutSet?>(
                    stream: repo.watchPersonalRecord(exName),
                    builder: (context, snapshot) {
                      final pr = snapshot.data;
                      return Text(
                        pr != null 
                            ? '${pr.weight.toStringAsFixed(1).replaceAll('.0', '')} kg x ${pr.reps}'
                            : 'Sin PR',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                      );
                    }
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    color: const Color(0xFF1A1A1A),
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (val) {
                      if (val == 'remove') {
                        _removeExercise(exName);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Quitar Ejercicio', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Series del ejercicio
          ...sets.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            return _buildSpaciousSetRow(context, exName, idx, s);
          }),

          // Añadir Serie
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: FilledButton.icon(
              onPressed: () => _addSet(exName),
              icon: const Icon(Icons.add),
              label: const Text('Añadir Serie', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF262626)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaciousSetRow(BuildContext context, String exName, int index, ExerciseSetDraft s) {
    final isDone = s.isCompleted;
    final hasNote = s.note != null && s.note!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.1) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.4) : const Color(0xFF2A2A2A),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Index y botón borrar
                GestureDetector(
                  onLongPress: () => _removeSet(exName, index),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: isDone ? Colors.green : const Color(0xFF333333),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Peso
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('kg', style: TextStyle(color: Colors.grey, fontSize: 12, height: 0.8)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _AdjustButton(
                          icon: Icons.remove,
                          size: 28,
                          onPressed: isDone ? null : () => _updateWeight(exName, index, -2.5),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: isDone ? null : () => _editWeight(context, exName, index),
                          child: SizedBox(
                            width: 48,
                            child: Text(
                              s.weight.toStringAsFixed(1).replaceAll('.0', ''),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDone ? Colors.greenAccent : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _AdjustButton(
                          icon: Icons.add,
                          size: 28,
                          onPressed: isDone ? null : () => _updateWeight(exName, index, 2.5),
                        ),
                      ],
                    ),
                  ],
                ),

                // Reps
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('reps', style: TextStyle(color: Colors.grey, fontSize: 12, height: 0.8)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _AdjustButton(
                          icon: Icons.remove,
                          size: 28,
                          onPressed: isDone ? null : () => _updateReps(exName, index, -1),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: isDone ? null : () => _editReps(context, exName, index),
                          child: SizedBox(
                            width: 32,
                            child: Text(
                              '${s.reps}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDone ? Colors.greenAccent : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _AdjustButton(
                          icon: Icons.add,
                          size: 28,
                          onPressed: isDone ? null : () => _updateReps(exName, index, 1),
                        ),
                      ],
                    ),
                  ],
                ),

                // Check
                GestureDetector(
                  onTap: () => _toggleSetCompletion(exName, index),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDone ? Colors.green.withOpacity(0.2) : const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isDone ? Icons.check : Icons.check_circle_outline,
                      color: isDone ? Colors.greenAccent : Colors.grey,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Fila de opciones secundarias (Nota)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF262626))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _editNote(context, exName, index),
                  child: Row(
                    children: [
                      Icon(
                        hasNote ? Icons.sticky_note_2 : Icons.note_add_outlined,
                        size: 16,
                        color: hasNote ? Colors.amberAccent : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasNote ? 'Nota guardada' : 'Añadir nota',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasNote ? Colors.amberAccent : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasNote) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${s.note}"',
                      style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onPressed;

  const _AdjustButton({required this.icon, required this.size, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onPressed == null ? Colors.transparent : const Color(0xFF262626),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: size - 10,
          color: onPressed == null ? Colors.grey.withOpacity(0.3) : Colors.white,
        ),
      ),
    );
  }
}
