import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';

// --- TABLAS DEL SPRINT 1 (Notas) ---
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

class LifeAreas extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- TABLAS DEL SPRINT 2 (Hábitos) ---
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  
  // Nuevas columnas V2
  DateTimeColumn get startDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endDate => dateTime().nullable()();
  // Columnas antiguas V2 (mantener para no romper migraciones)
  TextColumn get frequencyType => text().withDefault(const Constant('daily'))();
  IntColumn get weeklyGoal => integer().nullable()();

  // Nuevas columnas V3 (UI)
  TextColumn get repeatMode => text().withDefault(const Constant('daily'))(); // 'daily', 'monthly', 'interval'
  TextColumn get specificDays => text().nullable()(); // '1,2,3'
  IntColumn get goalAmount => integer().withDefault(const Constant(1))();
  TextColumn get goalPeriod => text().withDefault(const Constant('day'))(); // 'day', 'week', 'month', 'year'
  TextColumn get timeOfDay => text().nullable()(); // 'Evening' etc.

  TextColumn get lifeAreaId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  DateTimeColumn get completedDate => dateTime()();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- TABLAS DEL SPRINT 3 (Gimnasio) ---

// 1. Plantillas
class WorkoutTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

// 2. Ejercicios de la plantilla
class TemplateExercises extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get muscleGroup => text()();
  TextColumn get exerciseName => text()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Registro de un día de entrenamiento
class WorkoutLogs extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text().nullable()(); // Nullable por si entrenas sin plantilla
  DateTimeColumn get date => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. Series (Peso y Repeticiones)
class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get workoutLogId => text()();
  TextColumn get exerciseName => text()();
  RealColumn get weight => real()(); // Real permite decimales (ej. 12.5 kg)
  IntColumn get reps => integer()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('Media'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get lifeAreaId => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- TABLAS DEL SPRINT 5 (Roadmaps) ---
class Roadmaps extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

class RoadmapMilestones extends Table {
  TextColumn get id => text()();
  TextColumn get roadmapId => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

class MilestoneTasks extends Table {
  TextColumn get id => text()();
  TextColumn get milestoneId => text()();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  BoolColumn get isSynced => boolean().clientDefault(() => false)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CONFIGURACIÓN DE LA BASE DE DATOS ---
@DriftDatabase(tables: [
  Notes,
  LifeAreas,
  Habits,
  HabitLogs,
  WorkoutTemplates,
  TemplateExercises,
  WorkoutLogs,
  WorkoutSets,
  Tasks,
  Roadmaps,
  RoadmapMilestones,
  MilestoneTasks
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(habits);
          await m.createTable(habitLogs);
        }
        if (from < 3) {
          await m.createTable(workoutTemplates);
          await m.createTable(templateExercises);
          await m.createTable(workoutLogs);
          await m.createTable(workoutSets);
        }
        // Migración para la Versión 4 (Tareas)
        if (from < 4) {
          await m.createTable(tasks);
        }
        // Migración para la Versión 5 (Roadmaps)
        if (from < 5) {
          await m.createTable(roadmaps);
          await m.createTable(roadmapMilestones);
          await m.createTable(milestoneTasks);
        }
        // Migración para la Versión 6 (Life Areas y Habits V2)
        if (from < 6) {
          await m.createTable(lifeAreas);
          await m.addColumn(habits, habits.startDate);
          await m.addColumn(habits, habits.endDate);
          await m.addColumn(habits, habits.frequencyType);
          await m.addColumn(habits, habits.specificDays);
          await m.addColumn(habits, habits.weeklyGoal);
          await m.addColumn(habits, habits.lifeAreaId);
        }
        // Migración para la Versión 7 (Habits UI)
        if (from < 7) {
          await m.addColumn(habits, habits.repeatMode);
          await m.addColumn(habits, habits.goalAmount);
          await m.addColumn(habits, habits.goalPeriod);
          await m.addColumn(habits, habits.timeOfDay);
        }
        // Migración para la Versión 8 (Tasks LifeArea)
        if (from < 8) {
          await m.addColumn(tasks, tasks.lifeAreaId);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}