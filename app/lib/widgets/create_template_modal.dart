import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Asegúrate de que esta ruta apunte a tu provider del gimnasio
import '../gym_provider.dart';

class CreateTemplateModal extends ConsumerStatefulWidget {
  const CreateTemplateModal({super.key});

  @override
  ConsumerState<CreateTemplateModal> createState() => _CreateTemplateModalState();
}

class _CreateTemplateModalState extends ConsumerState<CreateTemplateModal> {
  final TextEditingController _nameController = TextEditingController();
  
  // Lista para manejar dinámicamente los campos de los ejercicios
  final List<Map<String, TextEditingController>> _exercises = [];

  @override
  void initState() {
    super.initState();
    // Empezamos con un ejercicio vacío por defecto
    _addExerciseRow();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var controllers in _exercises) {
      controllers['muscle']?.dispose();
      controllers['name']?.dispose();
    }
    super.dispose();
  }

  void _addExerciseRow() {
    setState(() {
      _exercises.add({
        'muscle': TextEditingController(),
        'name': TextEditingController(),
      });
    });
  }

  void _removeExerciseRow(int index) {
    setState(() {
      final controllers = _exercises.removeAt(index);
      controllers['muscle']?.dispose();
      controllers['name']?.dispose();
    });
  }

  void _handleSave() {
    final templateName = _nameController.text.trim();
    if (templateName.isEmpty || _exercises.isEmpty) return;

    // Convertimos los controladores a la lista de Strings que espera el Repositorio
    final List<Map<String, String>> exercisesData = [];
    for (var controllers in _exercises) {
      final muscle = controllers['muscle']!.text.trim();
      final name = controllers['name']!.text.trim();
      
      // Solo agregamos si el usuario escribió algo en el nombre del ejercicio
      if (name.isNotEmpty) {
        exercisesData.add({
          'muscle_group': muscle.isEmpty ? 'General' : muscle,
          'exercise_name': name,
        });
      }
    }

    if (exercisesData.isEmpty) return; // Validación por si dejaron los campos en blanco

    // Llamamos a la magia de Riverpod
    // ✅ Correcto (sin la palabra Notifier en el provider)
    ref.read(gymTemplatesProvider.notifier).createTemplate(templateName, exercisesData);
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Como este modal puede crecer mucho, ocupamos FractionallySizedBox
    // para que tome hasta el 90% del alto de la pantalla si es necesario.
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Área scrolleable para no desbordar la pantalla
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
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: _inputDecoration('Nombre de la rutina (Ej: Día de Pecho)', colors.primary),
                    ),
                    const SizedBox(height: 24),
                    const Text('Ejercicios:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // --- Lista dinámica de Ejercicios ---
                    ..._exercises.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controllers = entry.value;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            // Grupo muscular (más pequeño)
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: controllers['muscle'],
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration('Músculo', colors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Nombre del ejercicio (más grande)
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: controllers['name'],
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration('Ejercicio (Ej: Press)', colors.primary),
                              ),
                            ),
                            // Botón de eliminar (solo si hay más de 1 ejercicio)
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
                    TextButton.icon(
                      onPressed: _addExerciseRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar otro ejercicio'),
                      style: TextButton.styleFrom(foregroundColor: colors.primary),
                    ),
                    const SizedBox(height: 24),

                    // --- Botón de Guardar ---
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _handleSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Guardar Rutina', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Pequeño helper para no repetir código de diseño en los TextFields
  InputDecoration _inputDecoration(String hint, Color primaryColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF5A5A5A)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
      ),
    );
  }
}