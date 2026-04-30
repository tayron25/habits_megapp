import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/tasks_provider.dart';
import 'package:app/life_areas_provider.dart';
import 'package:app/widgets/create_life_area_modal.dart';

class CreateTaskModal extends ConsumerStatefulWidget {
  const CreateTaskModal({super.key});

  @override
  ConsumerState<CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends ConsumerState<CreateTaskModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _selectedPriority = 'Media';
  DateTime? _selectedDate;
  String? _selectedLifeAreaId;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final desc = _descController.text.trim();

    ref.read(tasksProvider.notifier).addTask(
          title: title,
          description: desc.isEmpty ? null : desc,
          priority: _selectedPriority,
          dueDate: _selectedDate,
          lifeAreaId: _selectedLifeAreaId,
        );

    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              surface: const Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lifeAreasAsync = ref.watch(lifeAreasProvider);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nueva Tarea',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                TextField(
                  controller: _titleController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: _inputDecoration('¿Qué necesitas hacer?', colors.primary),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _descController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  decoration: _inputDecoration('Detalles (opcional)', colors.primary),
                ),
                const SizedBox(height: 16),

                // --- Área de Vida ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Área de Vida:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nueva'),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) => const CreateLifeAreaModal(),
                        );
                      },
                    ),
                  ],
                ),
                lifeAreasAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_,__) => const Text('Error al cargar áreas', style: TextStyle(color: Colors.red)),
                  data: (areas) {
                    if (areas.isEmpty) return const Text('Sin áreas. Presiona "Nueva".', style: TextStyle(color: Colors.white38));
                    return Wrap(
                      spacing: 8,
                      children: areas.map((a) => ChoiceChip(
                        label: Text(a.name),
                        selected: _selectedLifeAreaId == a.id,
                        selectedColor: colors.primary,
                        backgroundColor: const Color(0xFF1A1A1A),
                        onSelected: (sel) => setState(() => _selectedLifeAreaId = sel ? a.id : null),
                      )).toList(),
                    );
                  }
                ),
                const SizedBox(height: 16),

                // --- Prioridad ---
                const Text('Prioridad:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: ['Baja', 'Media', 'Alta'].map((priority) {
                    final isSelected = _selectedPriority == priority;
                    Color priorityColor;
                    if (priority == 'Alta')
                      priorityColor = Colors.redAccent;
                    else if (priority == 'Media')
                      priorityColor = Colors.amber;
                    else
                      priorityColor = Colors.blueAccent;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(
                            priority,
                            style: TextStyle(color: isSelected ? Colors.black : Colors.white),
                          ),
                          selected: isSelected,
                          selectedColor: priorityColor,
                          backgroundColor: const Color(0xFF1A1A1A),
                          side: BorderSide(color: isSelected ? priorityColor : const Color(0xFF3A3A3A)),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedPriority = priority);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // --- Fecha Límite ---
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: Colors.grey),
                  title: Text(
                    _selectedDate == null ? 'Sin fecha límite' : 'Para el ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.white),
                  ),
                  trailing: _selectedDate != null
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () => setState(() => _selectedDate = null),
                        )
                      : null,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),

                // --- Botón de Guardar ---
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Crear Tarea', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  InputDecoration _inputDecoration(String hint, Color primaryColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF5A5A5A)),
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
