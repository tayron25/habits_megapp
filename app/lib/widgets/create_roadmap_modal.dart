import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/roadmaps_provider.dart';

class CreateRoadmapModal extends ConsumerStatefulWidget {
  const CreateRoadmapModal({super.key});

  @override
  ConsumerState<CreateRoadmapModal> createState() => _CreateRoadmapModalState();
}

class _CreateRoadmapModalState extends ConsumerState<CreateRoadmapModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

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

    ref.read(roadmapsProvider.notifier).createRoadmap(
          title,
          desc.isEmpty ? null : desc,
        );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
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
                  'Nuevo Roadmap',
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
                  decoration: _inputDecoration('Meta Principal (Ej. Aprender Flutter)', colors.primary),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _descController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  decoration: _inputDecoration('Descripción o motivación (opcional)', colors.primary),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Crear Roadmap',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
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
