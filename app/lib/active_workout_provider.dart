import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_workout_provider.g.dart';

// Estructura temporal para una serie en pantalla
class SetDraft {
  double weight;
  int reps;
  SetDraft({this.weight = 0, this.reps = 0});
}

// Mapa que relaciona el nombre del ejercicio con su lista de series
@riverpod
class ActiveWorkoutNotifier extends _$ActiveWorkoutNotifier {
  @override
  Map<String, List<SetDraft>> build() {
    // Estado inicial: un mapa vacío
    return {};
  }

  void init(List<String> exerciseNames) {
    state = { for (var name in exerciseNames) name : [SetDraft()] };
  }

  void addSet(String exerciseName) {
    state = {
      ...state,
      exerciseName: [...state[exerciseName]!, SetDraft()]
    };
  }

  void removeSet(String exerciseName, int index) {
    final sets = [...state[exerciseName]!];
    if (sets.length > 1) {
      sets.removeAt(index);
      state = { ...state, exerciseName: sets };
    }
  }

  void updateSet(String exerciseName, int index, {double? weight, int? reps}) {
    final sets = [...state[exerciseName]!];
    if (weight != null) sets[index].weight = weight;
    if (reps != null) sets[index].reps = reps;
    state = { ...state, exerciseName: sets };
  }
}