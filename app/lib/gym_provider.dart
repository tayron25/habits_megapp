import 'dart:async';
import 'package:app/gym_repository.dart';
import 'package:app/local_database.dart';
// Importamos el provider principal para usar la misma conexión de DB
import 'package:app/notes_provider.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gym_provider.g.dart';

// Esta clase combina la plantilla y sus ejercicios para mandarla a la UI
class WorkoutTemplateWithExercises {
  WorkoutTemplateWithExercises({required this.template, required this.exercises});
  final WorkoutTemplate template;
  final List<TemplateExercise> exercises;
}

// Inyectamos nuestro nuevo Repositorio
final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepository(
    supabaseClient: ref.read(supabaseClientProvider),
    database: ref.read(appDatabaseProvider),
  );
});

@riverpod
class GymTemplatesNotifier extends _$GymTemplatesNotifier {
  @override
  Stream<List<WorkoutTemplateWithExercises>> build() {
    final database = ref.watch(appDatabaseProvider);
    return _watchTemplatesWithExercises(database);
  }

  // Método público para la UI
  void createTemplate(String name, List<Map<String, String>> exercises) {
    ref.read(gymRepositoryProvider).saveWorkoutTemplate(name, exercises);
  }

  // Este método hace un "Join" en memoria para juntar plantillas con sus ejercicios
  Stream<List<WorkoutTemplateWithExercises>> _watchTemplatesWithExercises(AppDatabase database) {
    final templatesStream = database.select(database.workoutTemplates).watch();
    final exercisesStream = database.select(database.templateExercises).watch();

    return StreamQuery.combine2(templatesStream, exercisesStream, 
      (List<WorkoutTemplate> templates, List<TemplateExercise> allExercises) {
      
      return templates.map((template) {
        // Filtramos los ejercicios que pertenecen a esta plantilla
        final templateExercises = allExercises
            .where((ex) => ex.templateId == template.id)
            .toList();
        
        return WorkoutTemplateWithExercises(
          template: template,
          exercises: templateExercises,
        );
      }).toList();
    });
  }
}

final todayWorkoutSetsProvider = StreamProvider.family<List<WorkoutSet>, String>((ref, templateId) {
  return ref.watch(gymRepositoryProvider).watchTodaySets(templateId);
});

// Pequeña utilidad para combinar streams de Drift
class StreamQuery {
  static Stream<T> combine2<A, B, T>(
      Stream<A> streamA, Stream<B> streamB, T Function(A a, B b) combiner) async* {
    A? latestA;
    B? latestB;
    bool hasA = false;
    bool hasB = false;

    final controller = StreamController<T>();

    final subA = streamA.listen((a) {
      latestA = a;
      hasA = true;
      if (hasB) controller.add(combiner(latestA as A, latestB as B));
    }, onError: controller.addError);

    final subB = streamB.listen((b) {
      latestB = b;
      hasB = true;
      if (hasA) controller.add(combiner(latestA as A, latestB as B));
    }, onError: controller.addError);

    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };

    yield* controller.stream;
  }
}