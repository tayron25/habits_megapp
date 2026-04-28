import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/gym_provider.dart';
import 'package:app/local_database.dart';

class ExerciseSetDraft {
  String? id; // null si no se ha guardado
  double weight;
  int reps;
  bool isCompleted;

  ExerciseSetDraft({
    this.id,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
  });
}

class ExerciseExecutionScreen extends ConsumerStatefulWidget {
  final String templateId;
  final String exerciseName;

  const ExerciseExecutionScreen({
    super.key,
    required this.templateId,
    required this.exerciseName,
  });

  @override
  ConsumerState<ExerciseExecutionScreen> createState() =>
      _ExerciseExecutionScreenState();
}

class _ExerciseExecutionScreenState
    extends ConsumerState<ExerciseExecutionScreen> {
  bool _isLoading = true;
  String? _workoutLogId;
  double _historicalMax = 0;
  List<ExerciseSetDraft> _sets = [];

  // Cronómetro
  int _seconds = 0;
  Timer? _timer;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final repo = ref.read(gymRepositoryProvider);

    try {
      // 1. Obtener Log de hoy
      _workoutLogId = await repo.getOrCreateTodayWorkoutLog(widget.templateId);

      // 2. Obtener Récord Histórico
      _historicalMax = await repo.getHistoricalMaxWeight(widget.exerciseName);

      // 3. Autocompletado (última sesión)
      final lastSets = await repo.getLastWorkoutSets(widget.exerciseName);

      if (lastSets.isNotEmpty) {
        _sets = lastSets
            .map((s) => ExerciseSetDraft(weight: s.weight, reps: s.reps))
            .toList();
      } else {
        // Por defecto una serie vacía
        _sets = [ExerciseSetDraft(weight: 0, reps: 0)];
      }
    } catch (e) {
      print('Error cargando ejercicio: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Cronómetro ---
  void _toggleTimer() {
    if (_isTimerRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _seconds++);
      });
    }
    setState(() => _isTimerRunning = !_isTimerRunning);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 0;
      _isTimerRunning = false;
    });
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- Series ---
  void _addSet() {
    // Copiar la anterior si existe
    double lastWeight = 0;
    int lastReps = 0;
    if (_sets.isNotEmpty) {
      lastWeight = _sets.last.weight;
      lastReps = _sets.last.reps;
    }
    setState(() {
      _sets.add(ExerciseSetDraft(weight: lastWeight, reps: lastReps));
    });
  }

  void _removeSet(int index) async {
    final s = _sets[index];
    if (s.id != null) {
      await ref.read(gymRepositoryProvider).deleteWorkoutSet(s.id!);
    }
    setState(() {
      _sets.removeAt(index);
    });
  }

  Future<void> _toggleSetCompletion(int index) async {
    final s = _sets[index];
    final repo = ref.read(gymRepositoryProvider);

    if (!s.isCompleted) {
      // Marcar como completado -> Guardar en BD
      final newId = await repo.addWorkoutSet(
        workoutLogId: _workoutLogId!,
        exerciseName: widget.exerciseName,
        weight: s.weight,
        reps: s.reps,
      );
      setState(() {
        s.id = newId;
        s.isCompleted = true;
      });
    } else {
      // Desmarcar -> Eliminar de BD
      if (s.id != null) {
        await repo.deleteWorkoutSet(s.id!);
      }
      setState(() {
        s.id = null;
        s.isCompleted = false;
      });
    }
  }

  void _updateWeight(int index, double delta) async {
    final s = _sets[index];
    if (s.isCompleted)
      return; // No editar si está completado (opcional, o desmarcar)
    setState(() {
      s.weight = (s.weight + delta).clamp(0.0, 999.0);
    });
  }

  void _updateReps(int index, int delta) {
    final s = _sets[index];
    if (s.isCompleted) return;
    setState(() {
      s.reps = (s.reps + delta).clamp(0, 999);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        backgroundColor: const Color(0xFF0E0E0E),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header: Récord y Cronómetro
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF171717),
              border: Border(bottom: BorderSide(color: Color(0xFF262626))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Récord Histórico
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Récord Histórico',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_historicalMax.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Cronómetro
                Row(
                  children: [
                    Text(
                      _formatTime(_seconds),
                      style: TextStyle(
                        color: _isTimerRunning
                            ? Colors.greenAccent
                            : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _isTimerRunning ? Icons.pause : Icons.play_arrow,
                      ),
                      color: _isTimerRunning
                          ? Colors.greenAccent
                          : Colors.white,
                      onPressed: _toggleTimer,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF262626),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      color: Colors.grey,
                      onPressed: _resetTimer,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF262626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Series
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sets.length + 1, // +1 para el botón añadir
              itemBuilder: (context, index) {
                if (index == _sets.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextButton.icon(
                      onPressed: _addSet,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir Serie'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                }

                final s = _sets[index];
                return _buildSetRow(index, s);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int index, ExerciseSetDraft s) {
    final isDone = s.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withOpacity(0.15)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? Colors.green.withOpacity(0.5)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(
        children: [
          // Header de la serie
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDone
                      ? Colors.green
                      : const Color(0xFF333333),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (!isDone)
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _removeSet(index),
                  ),
              ],
            ),
          ),

          // Controles + / - (solo si no está done, o si permitimos editar igual)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Control Kilos
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Kilos',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AdjustButton(
                            icon: Icons.remove,
                            onPressed: isDone
                                ? null
                                : () => _updateWeight(index, -2.5),
                          ),
                          Expanded(
                            child: Text(
                              '${s.weight.toStringAsFixed(1)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDone
                                    ? Colors.greenAccent
                                    : Colors.white,
                              ),
                            ),
                          ),
                          _AdjustButton(
                            icon: Icons.add,
                            onPressed: isDone
                                ? null
                                : () => _updateWeight(index, 2.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFF333333),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),

                // Control Reps
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Reps',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _AdjustButton(
                            icon: Icons.remove,
                            onPressed: isDone
                                ? null
                                : () => _updateReps(index, -1),
                          ),
                          Expanded(
                            child: Text(
                              '${s.reps}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDone
                                    ? Colors.greenAccent
                                    : Colors.white,
                              ),
                            ),
                          ),
                          _AdjustButton(
                            icon: Icons.add,
                            onPressed: isDone
                                ? null
                                : () => _updateReps(index, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón Completar
          InkWell(
            onTap: () => _toggleSetCompletion(index),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDone
                    ? Colors.green.withOpacity(0.2)
                    : const Color(0xFF262626),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Icon(
                isDone ? Icons.check : Icons.check_circle_outline,
                color: isDone ? Colors.greenAccent : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _AdjustButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: onPressed == null
              ? Colors.transparent
              : const Color(0xFF262626),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: onPressed == null
              ? Colors.grey.withOpacity(0.3)
              : Colors.white,
        ),
      ),
    );
  }
}
