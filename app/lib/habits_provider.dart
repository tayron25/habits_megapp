import 'dart:async';

import 'package:app/habits_repository.dart';
import 'package:app/local_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/notes_provider.dart'; // O la ruta correcta a tu archivo

part 'habits_provider.g.dart';


typedef HabitWithStatusList = List<HabitWithStatus>;

class HabitWithStatus {
  const HabitWithStatus({
    required this.habit,
    required this.isCompletedToday,
  });

  final Habit habit;
  final bool isCompletedToday;
}


final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(
    supabaseClient: ref.read(supabaseClientProvider), // Usa el de notas
    database: ref.read(appDatabaseProvider), // Usa el de notas
  );
});



@riverpod
class HabitsNotifier extends _$HabitsNotifier {
  @override
  Stream<HabitWithStatusList> build() {
    
    final database = ref.watch(appDatabaseProvider); 
    return _watchHabitStatuses(database);
  }

  void addHabit({
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    required String frequencyType,
    String? specificDays,
    int? weeklyGoal,
    String? lifeAreaId,
  }) {
    ref.read(habitsRepositoryProvider).createHabit(
          name: name,
          startDate: startDate,
          endDate: endDate,
          frequencyType: frequencyType,
          specificDays: specificDays,
          weeklyGoal: weeklyGoal,
          lifeAreaId: lifeAreaId,
        );
  }

  void toggleHabit(String habitId, bool isCompleted) {
    ref.read(habitsRepositoryProvider).toggleHabitCompletion(
          habitId,
          DateTime.now(),
          isCompleted,
        );
  }

  Stream<HabitWithStatusList> _watchHabitStatuses(AppDatabase database) {
    return Stream.multi((controller) {
      var currentHabits = <Habit>[];
      var currentHabitLogs = <HabitLog>[];
      var habitsLoaded = false;
      var logsLoaded = false;

      late final StreamSubscription<List<Habit>> habitsSubscription;
      late final StreamSubscription<List<HabitLog>> habitLogsSubscription;

      void emitCurrentState() {
        if (!habitsLoaded || !logsLoaded) {
          return;
        }

        final today = _normalizeDate(DateTime.now());
        final todayWeekday = DateTime.now().weekday; // 1=Mon, 7=Sun

        final combined = currentHabits
            .where((habit) {
              // 1. Validar fechas de inicio y fin
              final habitStart = _normalizeDate(habit.startDate);
              if (today.isBefore(habitStart)) return false;

              if (habit.endDate != null) {
                final habitEnd = _normalizeDate(habit.endDate!);
                if (today.isAfter(habitEnd)) return false;
              }

              // 2. Validar frecuencia
              if (habit.frequencyType == 'specific_days' && habit.specificDays != null) {
                final days = habit.specificDays!.split(',');
                if (!days.contains(todayWeekday.toString())) return false;
              }
              // Si es 'weekly_goal' o 'daily', por ahora lo mostramos todos los días 
              // hasta que implementemos la lógica de la barra de progreso semanal.

              return true;
            })
            .map(
              (habit) => HabitWithStatus(
                habit: habit,
                isCompletedToday: currentHabitLogs.any(
                  (habitLog) =>
                      habitLog.habitId == habit.id &&
                      _isSameDay(habitLog.completedDate, today),
                ),
              ),
            )
            .toList(growable: false);

        controller.add(combined);
      }

      habitsSubscription = database.select(database.habits).watch().listen(
            (habits) {
              currentHabits = habits;
              habitsLoaded = true;
              emitCurrentState();
            },
            onError: controller.addError,
          );

      habitLogsSubscription = database.select(database.habitLogs).watch().listen(
            (habitLogs) {
              currentHabitLogs = habitLogs;
              logsLoaded = true;
              emitCurrentState();
            },
            onError: controller.addError,
          );

      controller.onCancel = () async {
        await habitsSubscription.cancel();
        await habitLogsSubscription.cancel();
      };
    });
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}