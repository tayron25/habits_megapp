import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ExerciseExecutionScreenState extends ConsumerState<ExerciseExecutionScreen> {
  bool _isLoading = true;
  String? _workoutLogId;
  WorkoutSet? _historicalMaxSet;
  List<ExerciseSetDraft> _sets = [];

  // Cronómetro (Cuenta regresiva)
  int _seconds = 90; // Default 1:30
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
      _historicalMaxSet = await repo.getHistoricalMaxWeight(widget.exerciseName);

      // 3. Cargar sets de HOY (Persistencia live)
      final todaySets = await repo.getSetsForLogAndExercise(_workoutLogId!, widget.exerciseName);

      if (todaySets.isNotEmpty) {
        _sets = todaySets
            .map((s) => ExerciseSetDraft(
                  id: s.id,
                  weight: s.weight,
                  reps: s.reps,
                  isCompleted: true,
                ))
            .toList();
      } else {
        // 4. Si no hay nada hoy, cargamos autocompletado (última sesión)
        final lastSets = await repo.getLastWorkoutSets(widget.exerciseName);
        if (lastSets.isNotEmpty) {
          _sets = lastSets
              .map((s) => ExerciseSetDraft(weight: s.weight, reps: s.reps))
              .toList();
        } else {
          _sets = [ExerciseSetDraft(weight: 0, reps: 0)];
        }
      }
    } catch (e) {
      print('Error cargando ejercicio: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        actions: [
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
        ],
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

  void _editWeight(BuildContext context, int index) {
    final s = _sets[index];
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

  void _editReps(BuildContext context, int index) {
    final s = _sets[index];
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
  void _addSet() {
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

  void _updateWeight(int index, double delta) {
    final s = _sets[index];
    if (s.isCompleted) return;
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                // Récord
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Column(
                      children: [
                        const Text('Mejor Marca', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              _historicalMaxSet != null 
                                  ? '${_historicalMaxSet!.weight.toStringAsFixed(1).replaceAll('.0', '')} kg x ${_historicalMaxSet!.reps}'
                                  : '0 kg',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Timer
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Column(
                      children: [
                        const Text('Descanso', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _adjustTimer(-30),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFF262626), shape: BoxShape.circle),
                                child: const Icon(Icons.remove, size: 16, color: Colors.white70),
                              ),
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () => _editTimer(context), // Abrir edición al tocar el timer
                              child: Text(
                                _formatTime(_seconds),
                                style: TextStyle(
                                  color: _seconds == 0 
                                      ? Colors.redAccent 
                                      : (_isTimerRunning ? Colors.greenAccent : Colors.white),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            GestureDetector(
                              onTap: () => _adjustTimer(30),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFF262626), shape: BoxShape.circle),
                                child: const Icon(Icons.add, size: 16, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Series (Más amplia para que quepan ~5)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sets.length + 1,
              itemBuilder: (context, index) {
                if (index == _sets.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: FilledButton.icon(
                      onPressed: _addSet,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir Serie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF171717),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFF262626)),
                        ),
                      ),
                    ),
                  );
                }

                final s = _sets[index];
                return _buildSpaciousSetRow(context, index, s);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpaciousSetRow(BuildContext context, int index, ExerciseSetDraft s) {
    final isDone = s.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.1) : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone ? Colors.green.withOpacity(0.4) : const Color(0xFF2A2A2A),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Index y botón borrar
          GestureDetector(
            onLongPress: () => _removeSet(index),
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
                    onPressed: isDone ? null : () => _updateWeight(index, -2.5),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: isDone ? null : () => _editWeight(context, index),
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
                    onPressed: isDone ? null : () => _updateWeight(index, 2.5),
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
                    onPressed: isDone ? null : () => _updateReps(index, -1),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: isDone ? null : () => _editReps(context, index),
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
                    onPressed: isDone ? null : () => _updateReps(index, 1),
                  ),
                ],
              ),
            ],
          ),

          // Check
          GestureDetector(
            onTap: () => _toggleSetCompletion(index),
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
