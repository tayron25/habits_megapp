import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Asegúrate de que esta ruta coincida con el nombre real de tu proyecto y carpeta
import 'widgets/quick_capture_modal.dart'; 
import 'notes_provider.dart'; // Ajusta la ruta si es necesario

void main() async {
  // 1. Asegurar que los bindings nativos estén listos antes de inicializar bases de datos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializar Supabase (Reemplaza con tus URLs temporales si ya creaste el proyecto, 
  // o déjalo con strings vacíos solo para que no crashee por ahora).
  await Supabase.initialize(
    url: 'https://tazkviborrgtmaggowmk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRhemt2aWJvcnJndG1hZ2dvd21rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyNDIzNDIsImV4cCI6MjA5MjgxODM0Mn0.VY5lKytV-hLy3BAFKZeyJsZriqQmjFHKqZ0SMuTb83A',
  );

  // 3. Envolver la app en ProviderScope (OBLIGATORIO para que Riverpod funcione)
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life OS',
      // Cambiamos a modo oscuro por defecto como definimos en el diseño
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

// Asegúrate de tener estas importaciones arriba:


class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el estado de las notas
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoy'),
        elevation: 0,
      ),
      body: notesAsync.when(
        // ESTADO 1: Cargando datos
        loading: () => const Center(child: CircularProgressIndicator()),
        
        // ESTADO 2: Error al cargar
        error: (error, stack) => Center(child: Text('Error: $error')),
        
        // ESTADO 3: Datos cargados correctamente
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Text(
                'Tu mente está en blanco.\n¡Anota algo!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // Lista de notas
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.content,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Indicador visual de sincronización (Nube)
                      Icon(
                        note.isSynced ? Icons.cloud_done : Icons.cloud_off,
                        color: note.isSynced ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const QuickCaptureModal(),
          );
        },
        tooltip: 'Nueva Nota',
        child: const Icon(Icons.add),
      ),
    );
  }
}