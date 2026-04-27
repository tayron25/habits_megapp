import 'package:app/local_database.dart';
import 'package:app/notes_provider.dart';
import 'package:app/roadmaps_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'roadmaps_provider.g.dart';

class MilestoneWithTasks {
  final RoadmapMilestone milestone;
  final List<MilestoneTask> tasks;
  
  MilestoneWithTasks(this.milestone, this.tasks);

  double get progress {
    if (tasks.isEmpty) return 0.0;
    int completed = tasks.where((t) => t.isCompleted).length;
    return completed / tasks.length;
  }
}

class RoadmapWithDetails {
  final Roadmap roadmap;
  final List<MilestoneWithTasks> milestones;

  RoadmapWithDetails(this.roadmap, this.milestones);

  double get progress {
    int totalTasks = 0;
    int completedTasks = 0;
    for (var m in milestones) {
      for (var t in m.tasks) {
        totalTasks++;
        if (t.isCompleted) completedTasks++;
      }
    }
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }
}

typedef RoadmapsList = List<RoadmapWithDetails>;

final roadmapsRepositoryProvider = Provider<RoadmapsRepository>((ref) {
  return RoadmapsRepository(
    supabaseClient: ref.read(supabaseClientProvider),
    database: ref.read(appDatabaseProvider),
  );
});

@riverpod
class RoadmapsNotifier extends _$RoadmapsNotifier {
  @override
  Stream<RoadmapsList> build() {
    final db = ref.watch(appDatabaseProvider);

    final roadmapsStream = db.select(db.roadmaps).watch();
    final milestonesStream = db.select(db.roadmapMilestones).watch();
    final tasksStream = db.select(db.milestoneTasks).watch();

    return Rx.combineLatest3(
      roadmapsStream,
      milestonesStream,
      tasksStream,
      (List<Roadmap> roadmaps, List<RoadmapMilestone> milestones, List<MilestoneTask> tasks) {
        
        return roadmaps.map((roadmap) {
          // Filtrar milestones de este roadmap
          final roadmapMilestones = milestones.where((m) => m.roadmapId == roadmap.id).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          // Mapear cada milestone a MilestoneWithTasks
          final milestonesWithTasks = roadmapMilestones.map((milestone) {
            final milestoneTasks = tasks.where((t) => t.milestoneId == milestone.id).toList()
               ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return MilestoneWithTasks(milestone, milestoneTasks);
          }).toList();

          return RoadmapWithDetails(roadmap, milestonesWithTasks);
        }).toList()..sort((a, b) => a.roadmap.createdAt.compareTo(b.roadmap.createdAt));
      },
    );
  }

  void createRoadmap(String title, String? description) {
    ref.read(roadmapsRepositoryProvider).createRoadmap(title: title, description: description);
  }

  void deleteRoadmap(String id) {
    ref.read(roadmapsRepositoryProvider).deleteRoadmap(id);
  }

  void addMilestone(String roadmapId, String title) {
    ref.read(roadmapsRepositoryProvider).addMilestone(roadmapId: roadmapId, title: title);
  }

  void deleteMilestone(String id) {
    ref.read(roadmapsRepositoryProvider).deleteMilestone(id);
  }

  void addTaskToMilestone(String milestoneId, String title) {
    ref.read(roadmapsRepositoryProvider).addTaskToMilestone(milestoneId: milestoneId, title: title);
  }

  void toggleTaskStatus(String id, bool isCompleted) {
    ref.read(roadmapsRepositoryProvider).toggleMilestoneTask(id, isCompleted);
  }

  void deleteTask(String id) {
    ref.read(roadmapsRepositoryProvider).deleteMilestoneTask(id);
  }
}
