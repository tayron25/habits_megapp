import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gym_provider.dart';

class CreateTemplateModal extends ConsumerStatefulWidget {
  const CreateTemplateModal({super.key});

  @override
  ConsumerState<CreateTemplateModal> createState() => _CreateTemplateModalState();
}

class _CreateTemplateModalState extends ConsumerState<CreateTemplateModal> {
  final TextEditingController _nameController = TextEditingController();
  
  // Ahora usamos un mapa de strings directamente
  final List<Map<String, String?>> _exercises = [];
  Map<String, List<String>> _catalog = {};

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _addExerciseRow();
  }

  Future<void> _loadCatalog() async {
    final catalog = await ref.read(gymRepositoryProvider).getExerciseCatalog();
    if (mounted) {
      setState(() {
        _catalog = catalog;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addExerciseRow() {
    setState(() {
      _exercises.add({
        'muscle': null,
        'name': null,
      });
    });
  }

  void _removeExerciseRow(int index) {
    setState(() {
      _exercises.removeAt(index);
    });
  }

  void _handleSave() {
    final templateName = _nameController.text.trim();
    if (templateName.isEmpty || _exercises.isEmpty) return;

    final List<Map<String, String>> exercisesData = [];
    for (var ex in _exercises) {
      final muscle = ex['muscle']?.trim() ?? '';
      final name = ex['name']?.trim() ?? '';
      
      if (name.isNotEmpty) {
        exercisesData.add({
          'muscle_group': muscle.isEmpty ? 'General' : muscle,
          'exercise_name': name,
        });
      }
    }

    if (exercisesData.isEmpty) return;

    ref.read(gymTemplatesProvider.notifier).createTemplate(templateName, exercisesData);
    Navigator.pop(context);
  }

  void _showMusclePicker(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _SelectionSheet(
        title: 'Selecciona un Músculo',
        items: _catalog.keys.toList()..sort(),
        onSelected: (val) {
          setState(() {
            _exercises[index]['muscle'] = val;
            _exercises[index]['name'] = null; // Reseteamos el ejercicio
          });
        },
        onAddNew: () => _showAddNewDialog(
          title: 'Nuevo Músculo',
          onAdded: (newVal) {
            setState(() {
              if (!_catalog.containsKey(newVal)) _catalog[newVal] = [];
              _exercises[index]['muscle'] = newVal;
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
        const SnackBar(content: Text('Primero selecciona un músculo', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
      return;
    }
    
    final items = _catalog[currentMuscle] ?? [];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _SelectionSheet(
        title: 'Ejercicios de $currentMuscle',
        items: items,
        onSelected: (val) {
          setState(() => _exercises[index]['name'] = val);
        },
        onAddNew: () => _showAddNewDialog(
          title: 'Nuevo Ejercicio',
          onAdded: (newVal) {
            setState(() {
              if (!_catalog[currentMuscle]!.contains(newVal)) {
                _catalog[currentMuscle]!.add(newVal);
                _catalog[currentMuscle]!.sort();
              }
              _exercises[index]['name'] = newVal;
            });
          },
        ),
      ),
    );
  }

  void _showAddNewDialog({required String title, required Function(String) onAdded}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
            hintText: 'Escribe aquí...',
            hintStyle: TextStyle(color: Color(0xFF5A5A5A)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) onAdded(val);
              Navigator.pop(context); // Cierra diálogo
              Navigator.pop(context); // Cierra bottom sheet
            },
            child: const Text('Añadir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButton(String hint, String? value, VoidCallback onTap) {
    final hasValue = value != null && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? value : hint,
                style: TextStyle(
                  color: hasValue ? Colors.white : const Color(0xFF5A5A5A),
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nueva Rutina',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16, right: 16, bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Nombre de la Rutina ---
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Nombre de la rutina (Ej: Día de Pecho)',
                        hintStyle: const TextStyle(color: Color(0xFF5A5A5A)),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.primary.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Ejercicios:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),

                    // --- Lista dinámica de Ejercicios ---
                    ..._exercises.asMap().entries.map((entry) {
                      final index = entry.key;
                      final ex = entry.value;
                      final muscle = ex['muscle'];
                      final name = ex['name'];
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildSelectionButton('Músculo', muscle, () => _showMusclePicker(index)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: _buildSelectionButton('Ejercicio', name, () => _showExercisePicker(index, muscle)),
                            ),
                            if (_exercises.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                onPressed: () => _removeExerciseRow(index),
                              ),
                          ],
                        ),
                      );
                    }),

                    // --- Botón para agregar más filas ---
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextButton.icon(
                        onPressed: _addExerciseRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir otro ejercicio', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Botón de Guardar ---
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _handleSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Guardar Rutina', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
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

// Widget auxiliar para las hojas inferiores de selección
class _SelectionSheet extends StatelessWidget {
  final String title;
  final List<String> items;
  final Function(String) onSelected;
  final VoidCallback onAddNew;

  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.onSelected,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            
            // Lista de items
            Flexible(
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Aún no hay opciones.', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, i) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        title: Text(items[i], style: const TextStyle(color: Colors.white, fontSize: 16)),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF3A3A3A), size: 16),
                        onTap: () {
                          onSelected(items[i]);
                          Navigator.pop(context); // Cierra el bottom sheet
                        },
                      ),
                    ),
            ),
            
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            
            // Botón de añadir nuevo fijo abajo
            InkWell(
              onTap: onAddNew,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Añadir nuevo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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