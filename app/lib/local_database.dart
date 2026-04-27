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

// --- TABLAS DEL SPRINT 2 (Hábitos) ---
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
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

// --- CONFIGURACIÓN DE LA BASE DE DATOS ---
@DriftDatabase(tables: [
  Notes,
  Habits,
  HabitLogs,
  WorkoutTemplates,
  TemplateExercises,
  WorkoutLogs,
  WorkoutSets
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // ¡Subimos a la versión 3!
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Si el usuario venía de la versión 1, le creamos los hábitos
        if (from < 2) {
          await m.createTable(habits);
          await m.createTable(habitLogs);
        }
        // Si venía de la versión 1 o 2, le creamos el gimnasio
        if (from < 3) {
          await m.createTable(workoutTemplates);
          await m.createTable(templateExercises);
          await m.createTable(workoutLogs);
          await m.createTable(workoutSets);
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