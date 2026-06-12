import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym_provider.dart';

class PatternGeneratorModal extends ConsumerStatefulWidget {
  const PatternGeneratorModal({super.key});

  @override
  ConsumerState<PatternGeneratorModal> createState() => _PatternGeneratorModalState();
}

class _PatternGeneratorModalState extends ConsumerState<PatternGeneratorModal> {
  final List<String?> _pattern = []; // null = Descanso
  int _weeks = 4;
  bool _isGenerating = false;

  void _addDayToPattern(String? templateId) {
    setState(() {
      _pattern.add(templateId);
    });
  }

  void _removeDayFromPattern(int index) {
    setState(() {
      _pattern.removeAt(index);
    });
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final templatesAsync = ref.watch(gymTemplatesProvider);
            return templatesAsync.when(
              data: (templates) {
                return ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Selecciona para el Patrón', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      leading: const Icon(Icons.nightlight_round, color: Colors.blueAccent),
                      title: const Text('Día de Descanso', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _addDayToPattern(null);
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(color: Color(0xFF2A2A2A)),
                    ...templates.map((t) => ListTile(
                      leading: const Icon(Icons.fitness_center, color: Colors.greenAccent),
                      title: Text(t.template.name, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        _addDayToPattern(t.template.id);
                        Navigator.pop(context);
                      },
                    ))
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            );
          },
        );
      },
    );
  }

  void _handleGenerate() async {
    if (_pattern.isEmpty) return;
    setState(() => _isGenerating = true);
    
    try {
      await ref.read(gymCalendarProvider).generatePattern(_pattern, _weeks);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Programa de $_weeks semanas generado con éxito.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Generador de Programas', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Define un ciclo (ej. Pecho, Espalda, Descanso). La app repetirá este ciclo en tu calendario.',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _pattern.isEmpty
                ? const Center(child: Text('El patrón está vacío. Añade días.', style: TextStyle(color: Colors.grey)))
                : Consumer(
                    builder: (context, ref, child) {
                      final templates = ref.watch(gymTemplatesProvider).value ?? [];
                      
                      return ReorderableListView.builder(
                        itemCount: _pattern.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _pattern.removeAt(oldIndex);
                            _pattern.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final tid = _pattern[index];
                          final name = tid == null 
                              ? 'Día de Descanso' 
                              : templates.firstWhere(
                                  (t) => t.template.id == tid, 
                                  orElse: () => throw Exception()
                                ).template.name;
                          final isRest = tid == null;

                          return Container(
                            key: ValueKey('pattern_$index'),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isRest ? Colors.blueAccent.withOpacity(0.2) : Colors.greenAccent.withOpacity(0.2),
                                child: Text('D${index+1}', style: TextStyle(color: isRest ? Colors.blueAccent : Colors.greenAccent)),
                              ),
                              title: Text(name, style: const TextStyle(color: Colors.white)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, color: Colors.redAccent),
                                onPressed: () => _removeDayFromPattern(index),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showTemplatePicker,
            icon: const Icon(Icons.add),
            label: const Text('Añadir Día al Patrón'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Generar por:', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<int>(
                  value: _weeks,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2 Semanas')),
                    DropdownMenuItem(value: 4, child: Text('4 Semanas')),
                    DropdownMenuItem(value: 8, child: Text('8 Semanas')),
                    DropdownMenuItem(value: 12, child: Text('12 Semanas')),
                  ],
                  onChanged: (val) {
                    setState(() => _weeks = val!);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isGenerating || _pattern.isEmpty ? null : _handleGenerate,
            child: _isGenerating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text('Guardar y Llenar Calendario'),
          ),
        ],
      ),
    );
  }
}
