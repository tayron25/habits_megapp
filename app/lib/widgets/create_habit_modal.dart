import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/habits_provider.dart';
import 'package:app/life_areas_provider.dart';
import 'package:app/widgets/create_life_area_modal.dart';

class CreateHabitModal extends ConsumerStatefulWidget {
  const CreateHabitModal({super.key});

  @override
  ConsumerState<CreateHabitModal> createState() => _CreateHabitModalState();
}

class _CreateHabitModalState extends ConsumerState<CreateHabitModal> {
  final _nameController = TextEditingController();
  final _weeklyGoalController = TextEditingController(text: '3');
  
  String? _selectedLifeAreaId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  String _frequencyType = 'daily'; // 'daily', 'specific_days', 'weekly_goal'
  final Set<int> _selectedDays = {}; // 1=Mon .. 7=Sun

  @override
  void dispose() {
    _nameController.dispose();
    _weeklyGoalController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    int? weeklyGoal;
    if (_frequencyType == 'weekly_goal') {
      weeklyGoal = int.tryParse(_weeklyGoalController.text.trim());
      if (weeklyGoal == null || weeklyGoal <= 0) return;
    }

    String? specificDaysStr;
    if (_frequencyType == 'specific_days') {
      if (_selectedDays.isEmpty) return; // Deben seleccionar al menos un día
      specificDaysStr = _selectedDays.toList().join(',');
    }

    ref.read(habitsProvider.notifier).addHabit(
          name: name,
          startDate: _startDate,
          endDate: _endDate,
          frequencyType: _frequencyType,
          specificDays: specificDaysStr,
          weeklyGoal: weeklyGoal,
          lifeAreaId: _selectedLifeAreaId,
        );
    
    Navigator.pop(context);
  }

  Future<void> _pickDate(bool isStart) async {
     final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: Theme.of(context).colorScheme.primary,
            surface: const Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lifeAreasAsync = ref.watch(lifeAreasProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 12,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Nuevo Hábito', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                
                // 1. Nombre
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: _inputDecoration('Ej: Leer, Ir al Gym...', colors.primary),
                ),
                const SizedBox(height: 16),

                // 2. Área de Vida
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Área de Vida:', style: TextStyle(color: Colors.grey)),
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
                  error: (_,__) => const Text('Error al cargar áreas'),
                  data: (areas) {
                    if (areas.isEmpty) return const Text('Sin áreas. Presiona "Nueva".', style: TextStyle(color: Colors.white38));
                    return Wrap(
                      spacing: 8,
                      children: areas.map((a) => ChoiceChip(
                        label: Text(a.name),
                        selected: _selectedLifeAreaId == a.id,
                        onSelected: (sel) => setState(() => _selectedLifeAreaId = sel ? a.id : null),
                      )).toList(),
                    );
                  }
                ),
                const SizedBox(height: 16),

                // 3. Duración (Fechas)
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Inicio', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fin (Opcional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(_endDate == null ? 'Infinito' : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                        trailing: _endDate != null ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(()=> _endDate = null)) : null,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 4. Frecuencia
                const Text('Frecuencia:', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'daily', label: Text('Diario')),
                    ButtonSegment(value: 'specific_days', label: Text('Días')),
                    ButtonSegment(value: 'weekly_goal', label: Text('X / Sem')),
                  ],
                  selected: {_frequencyType},
                  onSelectionChanged: (set) => setState(() => _frequencyType = set.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),

                if (_frequencyType == 'specific_days')
                  Wrap(
                    spacing: 4,
                    children: [
                      _buildDayChip(1, 'L'), _buildDayChip(2, 'M'), _buildDayChip(3, 'X'),
                      _buildDayChip(4, 'J'), _buildDayChip(5, 'V'), _buildDayChip(6, 'S'), _buildDayChip(7, 'D'),
                    ],
                  ),
                
                if (_frequencyType == 'weekly_goal')
                   TextField(
                    controller: _weeklyGoalController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Veces por semana', colors.primary),
                  ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Crear Hábito', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = _selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (val) _selectedDays.add(day);
          else _selectedDays.remove(day);
        });
      },
    );
  }

  InputDecoration _inputDecoration(String hint, Color primary) {
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