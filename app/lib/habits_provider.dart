import 'dart:async';

import 'package:app/habits_repository.dart';
import 'package:app/local_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:app/notes_provider.dart'; // O la ruta correcta a tu archivo

part 'habits_provider.g.dart';


typedef HabitWithStatusList = List<HabitWithStatus>;

class HabitWithStatus {
  const HabitWithStatus({
    required this.habit,
    required this.isCompletedToday,
    required this.currentProgress,
    required this.isGoalMet,
  });

  final Habit habit;
  final bool isCompletedToday;
  final int currentProgress;
  final bool isGoalMet;
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
    required String repeatMode,
    String? specificDays,
    required int goalAmount,
    required String goalPeriod,
    String? timeOfDay,
    String? lifeAreaId,
  }) {
    ref.read(habitsRepositoryProvider).createHabit(
          name: name,
          startDate: startDate,
          endDate: endDate,
          repeatMode: repeatMode,
          specificDays: specificDays,
          goalAmount: goalAmount,
          goalPeriod: goalPeriod,
          timeOfDay: timeOfDay,
          lifeAreaId: lifeAreaId,
        );
  }

  void updateHabit(
    String id, {
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    required String repeatMode,
    String? specificDays,
    required int goalAmount,
    required String goalPeriod,
    String? timeOfDay,
    String? lifeAreaId,
  }) {
    ref.read(habitsRepositoryProvider).updateHabit(
          id,
          name: name,
          startDate: startDate,
          endDate: endDate,
          repeatMode: repeatMode,
          specificDays: specificDays,
          goalAmount: goalAmount,
          goalPeriod: goalPeriod,
          timeOfDay: timeOfDay,
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

  void removeHabit(String habitId) {
    ref.read(habitsRepositoryProvider).deleteHabit(habitId);
  }

  Stream<HabitWithStatusList> _watchHabitStatuses(AppDatabase database) {
    return Stream.multi((controller) {
      var currentHabits = <Habit>[];
      var currentHabitLogs = <HabitLog>[];
      var habitsLoaded = false;
      var logsLoaded = false;

      late final StreamSubscription<List<Habit>> habitsSubscription;
      late final StreamSubscription<List<HabitLog>> habitLogsSubscription;

      void emitCurrentState() async {
        if (!habitsLoaded || !logsLoaded) {
          return;
        }

        final today = _normalizeDate(DateTime.now());
        final todayWeekday = DateTime.now().weekday; // 1=Mon, 7=Sun
        final repo = ref.read(habitsRepositoryProvider);

        final List<HabitWithStatus> combined = [];

        for (final habit in currentHabits) {
          // 1. Validar fechas de inicio y fin
          final habitStart = _normalizeDate(habit.startDate);
          if (today.isBefore(habitStart)) continue;

          if (habit.endDate != null) {
            final habitEnd = _normalizeDate(habit.endDate!);
            if (today.isAfter(habitEnd)) continue;
          }

          // 2. Validar frecuencia
          if (habit.repeatMode == 'daily' && habit.specificDays != null) {
            final days = habit.specificDays!.split(',');
            if (days.isNotEmpty && !days.contains(todayWeekday.toString())) continue;
          } else if (habit.repeatMode == 'monthly' && habit.specificDays != null) {
            final days = habit.specificDays!.split(',');
            if (days.isNotEmpty && !days.contains(today.day.toString())) continue;
          } else if (habit.repeatMode == 'interval' && habit.specificDays != null) {
            final interval = int.tryParse(habit.specificDays!) ?? 1;
            final diff = today.difference(habitStart).inDays;
            if (diff % interval != 0) continue;
          }

          // 3. Calcular rango de fechas para el periodo actual
          DateTime start;
          DateTime end;
          final now = DateTime.now();

          switch (habit.goalPeriod) {
            case 'week':
              final monday = now.subtract(Duration(days: now.weekday - 1));
              start = _normalizeDate(monday);
              end = DateTime(start.year, start.month, start.day).add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
              break;
            case 'month':
              start = DateTime(now.year, now.month, 1);
              final nextMonth = DateTime(now.year, now.month + 1, 1);
              end = nextMonth.subtract(const Duration(seconds: 1));
              break;
            case 'year':
              start = DateTime(now.year, 1, 1);
              end = DateTime(now.year, 12, 31, 23, 59, 59);
              break;
            case 'day':
            default:
              start = _normalizeDate(now);
              end = DateTime(now.year, now.month, now.day, 23, 59, 59);
              break;
          }

          // Obtener progreso usando el repositorio según las instrucciones
          int progress = await repo.getHabitLogsCountForPeriod(habit.id, start, end);

          combined.add(HabitWithStatus(
            habit: habit,
            isCompletedToday: currentHabitLogs.any(
              (habitLog) =>
                  habitLog.habitId == habit.id &&
                  _isSameDay(habitLog.completedDate, today),
            ),
            currentProgress: progress,
            isGoalMet: progress >= habit.goalAmount,
          ));
        }

        combined.sort((a, b) {
          if (a.isCompletedToday && !b.isCompletedToday) return 1;
          if (!a.isCompletedToday && b.isCompletedToday) return -1;
          return a.habit.createdAt.compareTo(b.habit.createdAt);
        });

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
