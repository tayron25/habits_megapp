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
  TextColumn get lifeAreaId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('captured'))();
  DateTimeColumn get processedAt => dateTime().nullable()();
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

// --- EL MÓDULO DE GIMNASIO FUE EXTRAÍDO A UNA APP INDEPENDIENTE ---
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('Media'))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get lifeAreaId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get processedAt => dateTime().nullable()();
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
  BoolColumn get showOnHome => boolean().withDefault(const Constant(true))();
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

class PendingSyncActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localTable => text()(); // Renombrado para evitar conflicto con Drift
  TextColumn get itemId => text()();
  TextColumn get action => text()(); // 'DELETE' (INSERT/UPDATE use isSynced flag)
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
}

// --- CONFIGURACIÓN DE LA BASE DE DATOS ---
@DriftDatabase(tables: [
  Notes,
  LifeAreas,
  Habits,
  HabitLogs,
  Tasks,
  Roadmaps,
  RoadmapMilestones,
  MilestoneTasks,
  PendingSyncActions
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _ensureNoteProcessingColumns();
        await _ensureTaskProcessingColumns();
        await _ensureRoadmapHomeColumns();
        await _ensureAnalyticsColumns();
        await _ensureActivityEventsTable();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(habits);
          await m.createTable(habitLogs);
        }
        if (from < 3) {
          // Tablas del gimnasio extraídas, ya no se crean en la app principal.
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
        // Migración para la Versión 9 (Sync Queue)
        if (from < 9) {
          await m.createTable(pendingSyncActions);
        }
        // Migración para la Versión 10 (Supersets)
        if (from < 10) {
          // Extraído al gimnasio
        }
        // Migración para la Versión 11 (Extracción de Gym)
        if (from < 11) {
          await m.issueCustomQuery('DROP TABLE IF EXISTS workout_templates;');
          await m.issueCustomQuery('DROP TABLE IF EXISTS template_exercises;');
          await m.issueCustomQuery('DROP TABLE IF EXISTS workout_logs;');
          await m.issueCustomQuery('DROP TABLE IF EXISTS workout_sets;');
        }
        if (from < 12) {
          await _ensureNoteProcessingColumns();
        }
        if (from < 13) {
          await _ensureTaskProcessingColumns();
        }
        if (from < 14) {
          await _ensureRoadmapHomeColumns();
        }
        if (from < 15) {
          await _ensureAnalyticsColumns();
          await _ensureActivityEventsTable();
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _ensureNoteProcessingColumns() async {
    await _addColumnIfMissing('notes', 'life_area_id', 'TEXT');
    await _addColumnIfMissing('notes', 'status', "TEXT NOT NULL DEFAULT 'captured'");
    await _addColumnIfMissing('notes', 'processed_at', 'INTEGER');
  }

  Future<void> _ensureTaskProcessingColumns() async {
    await _addColumnIfMissing('tasks', 'status', "TEXT NOT NULL DEFAULT 'active'");
    await _addColumnIfMissing('tasks', 'processed_at', 'INTEGER');
  }

  Future<void> _ensureRoadmapHomeColumns() async {
    await _addColumnIfMissing('roadmaps', 'show_on_home', 'INTEGER NOT NULL DEFAULT 1');
  }

  Future<void> _ensureAnalyticsColumns() async {
    await _addColumnIfMissing('notes', 'converted_to_type', 'TEXT');
    await _addColumnIfMissing('notes', 'converted_to_id', 'TEXT');
    await _addColumnIfMissing('notes', 'note_type', 'TEXT');

    await _addColumnIfMissing('tasks', 'planned_date', 'INTEGER');
    await _addColumnIfMissing('tasks', 'completed_at', 'INTEGER');
    await _addColumnIfMissing('tasks', 'missed_at', 'INTEGER');
    await _addColumnIfMissing('tasks', 'origin_type', 'TEXT');
    await _addColumnIfMissing('tasks', 'origin_id', 'TEXT');

    await _addColumnIfMissing('habit_logs', 'target_date', 'INTEGER');
    await _addColumnIfMissing('habit_logs', 'status', "TEXT NOT NULL DEFAULT 'done'");
    await _addColumnIfMissing('habit_logs', 'logged_at', 'INTEGER');
    await _addColumnIfMissing('habit_logs', 'amount', 'INTEGER');
    await _addColumnIfMissing('habit_logs', 'source', "TEXT NOT NULL DEFAULT 'manual'");

    await _addColumnIfMissing('roadmaps', 'life_area_id', 'TEXT');

    await _addColumnIfMissing('milestone_tasks', 'status', "TEXT NOT NULL DEFAULT 'active'");
    await _addColumnIfMissing('milestone_tasks', 'completed_at', 'INTEGER');
  }

  Future<void> _ensureActivityEventsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS activity_events (
        id TEXT PRIMARY KEY NOT NULL,
        event_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        life_area_id TEXT NULL,
        occurred_at INTEGER NOT NULL,
        local_date INTEGER NOT NULL,
        source_app TEXT NOT NULL DEFAULT 'life_os',
        metadata_json TEXT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _addColumnIfMissing(String table, String column, String definition) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    final exists = columns.any((row) => row.read<String>('name') == column);
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
