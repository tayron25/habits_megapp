import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';

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
  TextColumn get supersetId => text().nullable()();
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

class PendingSyncActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localTable => text()(); // Renombrado para evitar conflicto con Drift
  TextColumn get itemId => text()();
  TextColumn get action => text()(); // 'DELETE' (INSERT/UPDATE use isSynced flag)
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

// --- CONFIGURACIÓN DE LA BASE DE DATOS ---
@DriftDatabase(tables: [
  WorkoutTemplates,
  TemplateExercises,
  WorkoutLogs,
  WorkoutSets,
  PendingSyncActions
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
    final file = File(p.join(directory.path, 'gym_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
