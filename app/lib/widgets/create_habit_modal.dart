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
  final _goalAmountController = TextEditingController(text: '2');
  final _intervalController = TextEditingController(text: '2');
  
  String? _selectedLifeAreaId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  String _repeatMode = 'daily'; // 'daily', 'monthly', 'interval'
  final Set<int> _selectedDays = {}; // 1=Mon .. 7=Sun (daily) or 1..31 (monthly)
  String _goalPeriod = 'week'; // 'day', 'week', 'month', 'year'

  @override
  void dispose() {
    _nameController.dispose();
    _goalAmountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final goalAmount = int.tryParse(_goalAmountController.text.trim()) ?? 1;
    if (goalAmount <= 0) return;

    String? specificDaysStr;
    if (_repeatMode == 'daily' && _selectedDays.isNotEmpty && _selectedDays.length < 7) {
      specificDaysStr = _selectedDays.toList().join(',');
    } else if (_repeatMode == 'monthly' && _selectedDays.isNotEmpty) {
      specificDaysStr = _selectedDays.toList().join(',');
    } else if (_repeatMode == 'interval') {
      final interval = int.tryParse(_intervalController.text.trim()) ?? 2;
      specificDaysStr = interval.toString();
    }

    ref.read(habitsProvider.notifier).addHabit(
          name: name,
          startDate: _startDate,
          endDate: _endDate,
          repeatMode: _repeatMode,
          specificDays: specificDaysStr,
          goalAmount: goalAmount,
          goalPeriod: _goalPeriod,
          timeOfDay: null,
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

                // 4. Repeat & Goal
                const SizedBox(height: 8),
                _buildRepeatRow(),
                const Divider(color: Color(0xFF2A2A2A), height: 32),
                _buildGoalRow(),
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

  Widget _buildRepeatRow() {
    final isEveryDay = _selectedDays.isEmpty || _selectedDays.length == 7;
    final everyDayText = isEveryDay ? 'Every Day' : '${_selectedDays.length} days';

    return Row(
      children: [
        const Icon(Icons.repeat, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Repeat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        _buildDropdown(
          value: _repeatMode,
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'interval', child: Text('Interval')),
          ],
          onChanged: (val) {
            setState(() {
              _repeatMode = val!;
              _selectedDays.clear();
            });
          },
        ),
        const SizedBox(width: 8),
        if (_repeatMode == 'daily')
          PopupMenuButton<int>(
            color: const Color(0xFF2A2A2A),
            offset: const Offset(0, 40),
            onSelected: (val) {
              if (val == 0) {
                setState(() => _selectedDays.clear());
              } else {
                setState(() {
                  if (_selectedDays.contains(val)) {
                    _selectedDays.remove(val);
                  } else {
                    _selectedDays.add(val);
                  }
                });
              }
            },
            itemBuilder: (context) => [
              _buildCheckableMenuItem(0, 'Every Day', isEveryDay),
              const PopupMenuDivider(),
              _buildCheckableMenuItem(7, 'Sunday', _selectedDays.contains(7)),
              _buildCheckableMenuItem(1, 'Monday', _selectedDays.contains(1)),
              _buildCheckableMenuItem(2, 'Tuesday', _selectedDays.contains(2)),
              _buildCheckableMenuItem(3, 'Wednesday', _selectedDays.contains(3)),
              _buildCheckableMenuItem(4, 'Thursday', _selectedDays.contains(4)),
              _buildCheckableMenuItem(5, 'Friday', _selectedDays.contains(5)),
              _buildCheckableMenuItem(6, 'Saturday', _selectedDays.contains(6)),
            ],
            child: _buildDropdownContainer(everyDayText),
          )
        else if (_repeatMode == 'monthly')
          GestureDetector(
            onTap: _showMonthlyDaysDialog,
            child: _buildDropdownContainer(
              _selectedDays.isEmpty ? 'Select days' : '${_selectedDays.length} days'
            ),
          )
        else if (_repeatMode == 'interval')
          Row(
            children: [
              const Text('every', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: TextField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3A3A3A))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3A3A3A))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('days', style: TextStyle(color: Colors.white70)),
            ],
          ),
      ],
    );
  }

  Future<void> _showMonthlyDaysDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF121212),
              surfaceTintColor: Colors.transparent,
              title: const Text('Days of the Month', style: TextStyle(color: Colors.white, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(31, (index) {
                    final day = index + 1;
                    final isSelected = _selectedDays.contains(day);
                    return InkWell(
                      onTap: () {
                        setStateDialog(() {
                          if (isSelected) _selectedDays.remove(day);
                          else _selectedDays.add(day);
                        });
                        setState(() {});
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blueAccent : const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? Colors.blueAccent : const Color(0xFF3A3A3A)),
                        ),
                        child: Text('$day', style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  PopupMenuItem<int> _buildCheckableMenuItem(int value, String text, bool isChecked) {
    return PopupMenuItem<int>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: const TextStyle(color: Colors.white)),
          if (isChecked) const Icon(Icons.check_box, color: Colors.blueAccent, size: 20)
          else const Icon(Icons.check_box_outline_blank, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildGoalRow() {
    return Row(
      children: [
        const Icon(Icons.track_changes, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Goal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        SizedBox(
          width: 50,
          height: 40,
          child: TextField(
            controller: _goalAmountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3A3A3A))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3A3A3A))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blueAccent)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text('times', style: TextStyle(color: Colors.white70)),
        const SizedBox(width: 8),
        _buildDropdown(
          value: _goalPeriod,
          items: const [
            DropdownMenuItem(value: 'day', child: Text('per day')),
            DropdownMenuItem(value: 'week', child: Text('per week')),
            DropdownMenuItem(value: 'month', child: Text('per month')),
            DropdownMenuItem(value: 'year', child: Text('per year')),
          ],
          onChanged: (val) => setState(() => _goalPeriod = val!),
        ),
      ],
    );
  }

  Widget _buildDropdownContainer(String text) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF3A3A3A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF3A3A3A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF2A2A2A),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
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