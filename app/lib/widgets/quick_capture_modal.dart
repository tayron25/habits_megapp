import 'package:app/local_database.dart';
import 'package:app/notes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuickCaptureModal extends ConsumerWidget {
  final Note? existingNote;
  const QuickCaptureModal({super.key, this.existingNote});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _QuickCaptureModalBody(
      existingNote: existingNote,
      onSave: (content) {
        if (existingNote == null) {
          ref.read(notesProvider.notifier).addNote(content);
        } else {
          ref.read(notesProvider.notifier).updateNote(existingNote!.id, content);
        }
      },
    );
  }
}

class _QuickCaptureModalBody extends StatefulWidget {
  const _QuickCaptureModalBody({required this.onSave, this.existingNote});

  final ValueChanged<String> onSave;
  final Note? existingNote;

  @override
  State<_QuickCaptureModalBody> createState() => _QuickCaptureModalBodyState();
}

class _QuickCaptureModalBodyState extends State<_QuickCaptureModalBody> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      _controller.text = widget.existingNote!.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    widget.onSave(text);
    _controller.clear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                    const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 6,
                minLines: 4,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: colors.primary,
                decoration: InputDecoration(
                  hintText: 'Escribe una nota rápida...',
                  hintStyle: const TextStyle(color: Color(0xFF7A7A7A)),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary.withOpacity(0.35)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                  child: Text(widget.existingNote == null ? 'Guardar' : 'Actualizar'),
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
}
