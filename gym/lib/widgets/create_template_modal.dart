import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym_provider.dart';
import 'package:uuid/uuid.dart';

class CreateTemplateModal extends ConsumerStatefulWidget {
  const CreateTemplateModal({
    super.key,
    this.template,
    this.embedded = false,
  });

  final WorkoutTemplateWithExercises? template;
  final bool embedded;

  @override
  ConsumerState<CreateTemplateModal> createState() => _CreateTemplateModalState();
}

class _CreateTemplateModalState extends ConsumerState<CreateTemplateModal> {
  final TextEditingController _nameController = TextEditingController();
  final List<Map<String, dynamic>> _exercises = [];
  Map<String, List<String>> _catalog = {};
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    final existingTemplate = widget.template;
    if (existingTemplate == null) {
      _addExerciseRow();
    } else {
      _nameController.text = existingTemplate.template.name;
      _exercises.addAll(existingTemplate.exercises.map((exercise) => {
            'muscle': exercise.muscleGroup,
            'name': exercise.exerciseName,
            'supersetId': exercise.supersetId,
            'progressionRule': exercise.progressionRule,
            'progressionTargetReps': exercise.progressionTargetReps,
            'progressionTargetWeightIncrease': exercise.progressionTargetWeightIncrease,
          }));
      if (_exercises.isEmpty) _addExerciseRow();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final catalog = await ref.read(gymRepositoryProvider).getExerciseCatalog();
    if (!mounted) return;
    setState(() => _catalog = catalog);
  }

  void _addExerciseRow({String? supersetId}) {
    setState(() {
      _exercises.add({
        'muscle': null,
        'name': null,
        'supersetId': supersetId,
        'progressionRule': null,
        'progressionTargetReps': null,
        'progressionTargetWeightIncrease': null,
      });
    });
  }

  void _addSupersetBlock() {
    final supersetId = const Uuid().v4();
    _addExerciseRow(supersetId: supersetId);
    _addExerciseRow(supersetId: supersetId);
  }

  void _removeExerciseRow(int index) {
    setState(() => _exercises.removeAt(index));
  }

  bool get _canContinue {
    if (_step == 0) return _nameController.text.trim().isNotEmpty;
    if (_step == 1) return _exercises.any((ex) => (ex['name'] ?? '').toString().isNotEmpty);
    return true;
  }

  void _handleSave() {
    final templateName = _nameController.text.trim();
    if (templateName.isEmpty) return;

    final exercisesData = <Map<String, dynamic>>[];
    for (final ex in _exercises) {
      final muscle = (ex['muscle'] ?? '').toString().trim();
      final name = (ex['name'] ?? '').toString().trim();
      final supersetId = (ex['supersetId'] ?? '').toString().trim();

      if (name.isEmpty) continue;
      if (ex['progressionRule'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Configura la progresion de $name', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _step = 2);
        return;
      }

      exercisesData.add({
        'muscle_group': muscle.isEmpty ? 'General' : muscle,
        'exercise_name': name,
        if (supersetId.isNotEmpty) 'superset_id': supersetId,
        'progression_rule': ex['progressionRule'],
        'progression_target_reps': ex['progressionTargetReps'],
        'progression_target_weight_increase': ex['progressionTargetWeightIncrease'],
      });
    }

    if (exercisesData.isEmpty) return;

    final existingTemplate = widget.template;
    if (existingTemplate == null) {
      ref.read(gymTemplatesProvider.notifier).createTemplate(templateName, exercisesData);
    } else {
      ref.read(gymTemplatesProvider.notifier).updateTemplate(
            existingTemplate.template.id,
            templateName,
            exercisesData,
          );
    }
    Navigator.pop(context);
  }

  void _showMusclePicker(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _SelectionSheet(
        title: 'Selecciona un musculo',
        items: _catalog.keys.toList()..sort(),
        onSelected: (value) {
          setState(() {
            _exercises[index]['muscle'] = value;
            _exercises[index]['name'] = null;
          });
        },
        onAddNew: () => _showAddNewDialog(
          title: 'Nuevo musculo',
          onAdded: (newValue) {
            setState(() {
              _catalog.putIfAbsent(newValue, () => []);
              _exercises[index]['muscle'] = newValue;
              _exercises[index]['name'] = null;
            });
          },
        ),
      ),
    );
  }

  void _showExercisePicker(int index, String? currentMuscle) {
    if (currentMuscle == null || currentMuscle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero selecciona un musculo', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _SelectionSheet(
        title: 'Ejercicios de $currentMuscle',
        items: _catalog[currentMuscle] ?? [],
        onSelected: (value) => setState(() => _exercises[index]['name'] = value),
        onAddNew: () => _showAddNewDialog(
          title: 'Nuevo ejercicio',
          onAdded: (newValue) {
            setState(() {
              _catalog.putIfAbsent(currentMuscle, () => []);
              if (!_catalog[currentMuscle]!.contains(newValue)) {
                _catalog[currentMuscle]!.add(newValue);
                _catalog[currentMuscle]!.sort();
              }
              _exercises[index]['name'] = newValue;
            });
          },
        ),
      ),
    );
  }

  void _showAddNewDialog({required String title, required ValueChanged<String> onAdded}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Escribe aqui...',
            hintStyle: TextStyle(color: Color(0xFF5A5A5A)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) onAdded(value);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showProgressionConfig(int index) {
    final ex = _exercises[index];
    final weightController = TextEditingController(
      text: (ex['progressionTargetWeightIncrease'] ?? 2.5).toString(),
    );
    String? selectedRule = ex['progressionRule'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Configurar ejercicio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRule,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Tipo de entrenamiento',
                      labelStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bajo', child: Text('Fuerza: 8 a 12 reps')),
                      DropdownMenuItem(value: 'alto', child: Text('Hipertrofia: 12 a 16 reps')),
                      DropdownMenuItem(value: 'manual', child: Text('Manual: copiar ultimo')),
                    ],
                    onChanged: (value) => setSheetState(() => selectedRule = value),
                  ),
                  if (selectedRule == 'bajo' || selectedRule == 'alto') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Aumento al subir nivel',
                        suffixText: 'kg',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [1.25, 2.0, 2.5, 5.0].map((weight) {
                        return ActionChip(
                          label: Text('+$weight kg'),
                          onPressed: () => setSheetState(() => weightController.text = weight.toString()),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      if (selectedRule == null) return;
                      setState(() {
                        _exercises[index]['progressionRule'] = selectedRule;
                        if (selectedRule == 'bajo' || selectedRule == 'alto') {
                          _exercises[index]['progressionTargetWeightIncrease'] =
                              double.tryParse(weightController.text) ?? 2.5;
                        } else {
                          _exercises[index]['progressionTargetWeightIncrease'] = null;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Guardar configuracion'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<List<int>> _groupedExerciseIndices() {
    final grouped = <List<int>>[];
    for (int i = 0; i < _exercises.length; i++) {
      final supersetId = _exercises[i]['supersetId'];
      if (supersetId != null && grouped.isNotEmpty && _exercises[grouped.last.last]['supersetId'] == supersetId) {
        grouped.last.add(i);
      } else {
        grouped.add([i]);
      }
    }
    return grouped;
  }

  Widget _selectionButton(String hint, String? value, VoidCallback onTap) {
    final hasValue = value != null && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? value : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasValue ? Colors.white : const Color(0xFF5A5A5A),
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _nameStep(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Nombre', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          autofocus: !widget.embedded,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Ej: Pecho y triceps',
            hintStyle: const TextStyle(color: Color(0xFF5A5A5A)),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary.withOpacity(0.5)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Corto y reconocible. Lo veras como chip en el calendario.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _exercisesStep(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ejercicios', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._groupedExerciseIndices().map((indices) {
          final first = _exercises[indices.first];
          final isGroup = first['supersetId'] != null;
          Widget row(int index) {
            final ex = _exercises[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _selectionButton('Musculo', ex['muscle'], () => _showMusclePicker(index)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _selectionButton('Ejercicio', ex['name'], () => _showExercisePicker(index, ex['muscle'])),
                  ),
                  if (_exercises.length > 1)
                    IconButton(
                      onPressed: () => _removeExerciseRow(index),
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    ),
                ],
              ),
            );
          }

          if (!isGroup) return row(indices.first);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: Colors.purpleAccent, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Superserie', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _exercises.removeWhere((ex) => ex['supersetId'] == first['supersetId']);
                      }),
                      icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                    ),
                  ],
                ),
                ...indices.map(row),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _addExerciseRow(),
          icon: const Icon(Icons.add),
          label: const Text('Agregar ejercicio'),
          style: TextButton.styleFrom(foregroundColor: colors.primary),
        ),
        TextButton.icon(
          onPressed: _addSupersetBlock,
          icon: const Icon(Icons.library_add),
          label: const Text('Agregar superserie'),
          style: TextButton.styleFrom(foregroundColor: Colors.purpleAccent),
        ),
      ],
    );
  }

  Widget _progressionStep() {
    final configured = _exercises.where((ex) => ex['progressionRule'] != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Progresion', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('$configured de ${_exercises.length} configurados', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        ..._exercises.asMap().entries.map((entry) {
          final index = entry.key;
          final ex = entry.value;
          final name = (ex['name'] ?? 'Ejercicio').toString();
          final rule = ex['progressionRule']?.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              tileColor: const Color(0xFF171717),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                rule == null ? 'Toca para configurar' : 'Tipo: $rule',
                style: TextStyle(color: rule == null ? Colors.orangeAccent : Colors.grey),
              ),
              trailing: Icon(rule == null ? Icons.settings : Icons.check_circle, color: rule == null ? Colors.orangeAccent : Colors.greenAccent),
              onTap: () => _showProgressionConfig(index),
            ),
          );
        }),
      ],
    );
  }

  Widget _stepContent(ColorScheme colors) {
    if (_step == 0) return _nameStep(colors);
    if (_step == 1) return _exercisesStep(colors);
    return _progressionStep();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = widget.template == null ? 'Nueva rutina' : 'Editar rutina';

    final content = Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: widget.embedded ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(24)),
        border: widget.embedded ? null : Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          if (!widget.embedded) ...[
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(16, widget.embedded ? 16 : 0, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    Text('Paso ${_step + 1}/3', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: index <= _step ? colors.primary : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _stepContent(colors),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Atras'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _step == 2
                          ? _handleSave
                          : _canContinue
                              ? () => setState(() => _step++)
                              : null,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      child: Text(_step == 2 ? (widget.template == null ? 'Guardar rutina' : 'Actualizar rutina') : 'Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;
    return FractionallySizedBox(heightFactor: 0.9, child: content);
  }
}

class _SelectionSheet extends StatelessWidget {
  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.onSelected,
    required this.onAddNew,
  });

  final String title;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Flexible(
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Aun no hay opciones.', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        title: Text(items[index], style: const TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                        onTap: () {
                          onSelected(items[index]);
                          Navigator.pop(context);
                        },
                      ),
                    ),
            ),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            InkWell(
              onTap: onAddNew,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Agregar nuevo',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
