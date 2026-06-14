import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym/gym_provider.dart';
import 'package:gym/local_database.dart';
import 'package:gym/widgets/create_template_modal.dart';
import 'package:gym/widgets/pattern_generator_modal.dart';
import 'package:intl/intl.dart';

class GymCalendarTab extends ConsumerStatefulWidget {
  const GymCalendarTab({super.key});

  @override
  ConsumerState<GymCalendarTab> createState() => _GymCalendarTabState();
}

class _GymCalendarTabState extends ConsumerState<GymCalendarTab> {
  late DateTime _selectedDate;
  late DateTime _weekStart;
  final Set<DateTime> _selectedDays = {};
  final Set<String> _pendingDeletePlanIds = {};

  bool get _selectionMode => _selectedDays.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = _dateOnly(now);
    _weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    Future.microtask(() => ref.read(gymRepositoryProvider).autoShiftPlannedWorkouts());
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _changeWeek(int deltaDays) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: deltaDays));
      _selectedDate = _weekStart;
      _selectedDays.clear();
    });
  }

  void _toggleSelectedDay(DateTime date) {
    final normalized = _dateOnly(date);
    setState(() {
      if (_selectedDays.contains(normalized)) {
        _selectedDays.remove(normalized);
      } else {
        _selectedDays.add(normalized);
      }
      _selectedDate = normalized;
    });
  }

  void _openPlannerSheet({
    required DateTime date,
    PlannedWorkout? focusedPlan,
    int initialTab = 0,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PlannerSheet(
        date: _dateOnly(date),
        focusedPlan: focusedPlan,
        initialTab: initialTab,
        onSchedule: (templateId) async {
          await ref.read(gymRepositoryProvider).scheduleWorkout(templateId, _dateOnly(date));
        },
        onMove: _movePlan,
        onChangeTemplate: _changePlanTemplate,
        onDelete: (plans) => _deletePlansWithUndo(plans),
        onDeleteDays: (days, plans) => _deletePlansWithUndo(
          plans.where((plan) => days.any((day) => _isSameDay(plan.plannedDate, day))).toList(),
        ),
      ),
    );
  }

  void _openPatternGenerator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const PatternGeneratorModal(),
      ),
    );
  }

  Future<void> _movePlan(PlannedWorkout plan) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: plan.plannedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.black,
              surface: const Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (newDate == null) return;
    await ref.read(gymRepositoryProvider).rescheduleWorkoutChain(plan.id, _dateOnly(newDate));
    if (!mounted) return;
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calendario ajustado desde el ${DateFormat('dd MMM').format(newDate)}')),
    );
  }

  Future<void> _changePlanTemplate(PlannedWorkout plan, String templateId) async {
    await ref.read(gymRepositoryProvider).updatePlannedWorkoutTemplate(plan.id, templateId);
    if (!mounted) return;
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rutina cambiada')),
    );
  }

  Future<void> _deletePlansWithUndo(List<PlannedWorkout> plans) async {
    if (plans.isEmpty) return;

    final ids = plans.map((plan) => plan.id).toSet();
    Navigator.of(context).maybePop();
    setState(() {
      _selectedDays.clear();
      _pendingDeletePlanIds.addAll(ids);
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(
          plans.length == 1
              ? 'Planificacion lista para borrar'
              : '${plans.length} planificaciones listas para borrar',
        ),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {},
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final reason = await controller.closed;
    if (reason == SnackBarClosedReason.action) {
      if (!mounted) return;
      setState(() => _pendingDeletePlanIds.removeAll(ids));
      return;
    }

    await ref.read(gymRepositoryProvider).deletePlannedWorkouts(ids.toList());
    if (!mounted) return;
    setState(() => _pendingDeletePlanIds.removeAll(ids));
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(plannedWorkoutsProvider(_weekStart));
    final templatesAsync = ref.watch(gymTemplatesProvider);

    return plansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (rawPlans) {
        final plans = rawPlans
            .where((plan) => !_pendingDeletePlanIds.contains(plan.id))
            .toList();
        final templates = templatesAsync.value ?? [];
        final selectedPlans = plans
            .where((plan) => _selectedDays.any((day) => _isSameDay(day, plan.plannedDate)))
            .toList();
        final dayPlans = plans
            .where((plan) => _isSameDay(plan.plannedDate, _selectedDate))
            .toList();

        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CalendarHeader(
                  weekStart: _weekStart,
                  selectionMode: _selectionMode,
                  onPrevious: () => _changeWeek(-7),
                  onNext: () => _changeWeek(7),
                  onEdit: () => _openPlannerSheet(date: _selectedDate, initialTab: 2),
                  onGenerate: _openPatternGenerator,
                ),
                CompactWeekCalendar(
                  weekStart: _weekStart,
                  selectedDate: _selectedDate,
                  selectedDays: _selectedDays,
                  plans: plans,
                  templates: templates,
                  onDayTap: (date) {
                    if (_selectionMode) {
                      _toggleSelectedDay(date);
                    } else {
                      setState(() => _selectedDate = _dateOnly(date));
                    }
                  },
                  onDayLongPress: _toggleSelectedDay,
                  onPlanTap: (plan) => _openPlannerSheet(
                    date: plan.plannedDate,
                    focusedPlan: plan,
                  ),
                  onPlanLongPress: (plan) => _toggleSelectedDay(plan.plannedDate),
                ),
                Expanded(
                  child: _DayPlanList(
                    date: _selectedDate,
                    plans: dayPlans,
                    templates: templates,
                    onAdd: () => _openPlannerSheet(date: _selectedDate),
                    onPlanTap: (plan) => _openPlannerSheet(
                      date: plan.plannedDate,
                      focusedPlan: plan,
                    ),
                    onPlanLongPress: (plan) => _toggleSelectedDay(plan.plannedDate),
                  ),
                ),
              ],
            ),
            if (_selectionMode)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _SelectionBar(
                  selectedDays: _selectedDays.length,
                  selectedPlans: selectedPlans.length,
                  onCancel: () => setState(_selectedDays.clear),
                  onDelete: () => _deletePlansWithUndo(selectedPlans),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.weekStart,
    required this.selectionMode,
    required this.onPrevious,
    required this.onNext,
    required this.onEdit,
    required this.onGenerate,
  });

  final DateTime weekStart;
  final bool selectionMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onEdit;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: selectionMode ? null : onPrevious,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekStart.add(const Duration(days: 6)))}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  selectionMode ? 'Seleccion multiple' : 'Semana de entrenamiento',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: selectionMode ? null : onNext,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.greenAccent),
            tooltip: 'Editar semana',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
            tooltip: 'Generar programa',
            onPressed: onGenerate,
          ),
        ],
      ),
    );
  }
}

class CompactWeekCalendar extends StatelessWidget {
  const CompactWeekCalendar({
    super.key,
    required this.weekStart,
    required this.selectedDate,
    required this.selectedDays,
    required this.plans,
    required this.templates,
    required this.onDayTap,
    required this.onDayLongPress,
    required this.onPlanTap,
    required this.onPlanLongPress,
  });

  final DateTime weekStart;
  final DateTime selectedDate;
  final Set<DateTime> selectedDays;
  final List<PlannedWorkout> plans;
  final List<WorkoutTemplateWithExercises> templates;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayLongPress;
  final ValueChanged<PlannedWorkout> onPlanTap;
  final ValueChanged<PlannedWorkout> onPlanLongPress;

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _templateName(String? templateId) {
    for (final item in templates) {
      if (item.template.id == templateId) return item.template.name;
    }
    return 'Rutina';
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());

    return SizedBox(
      height: 170,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = _dateOnly(weekStart.add(Duration(days: index)));
          final dayPlans = plans.where((plan) => _isSameDay(plan.plannedDate, date)).toList();
          final isSelected = _isSameDay(date, selectedDate);
          final isToday = _isSameDay(date, today);
          final isMultiSelected = selectedDays.contains(date);
          final completedCount = dayPlans.where((plan) => plan.isCompleted).length;

          Color borderColor = const Color(0xFF262626);
          if (isSelected) borderColor = Theme.of(context).colorScheme.primary;
          if (isMultiSelected) borderColor = Colors.redAccent;

          return GestureDetector(
            onTap: () => onDayTap(date),
            onLongPress: () => onDayLongPress(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 116,
              margin: const EdgeInsets.only(right: 10, top: 4, bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMultiSelected ? Colors.redAccent.withOpacity(0.12) : const Color(0xFF171717),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: isSelected || isMultiSelected ? 1.6 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('EEE').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isToday ? Colors.greenAccent : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (isMultiSelected)
                        const Icon(Icons.check_circle, size: 16, color: Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  _StatusPill(
                    text: dayPlans.isEmpty
                        ? 'Descanso'
                        : completedCount == dayPlans.length
                            ? 'Completado'
                            : '${dayPlans.length} pendiente${dayPlans.length == 1 ? '' : 's'}',
                    color: dayPlans.isEmpty
                        ? Colors.grey
                        : completedCount == dayPlans.length
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      children: dayPlans.take(2).map((plan) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: GestureDetector(
                            onTap: () => onPlanTap(plan),
                            onLongPress: () => onPlanLongPress(plan),
                            child: _PlanChip(
                              label: _templateName(plan.templateId),
                              completed: plan.isCompleted,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayPlanList extends StatelessWidget {
  const _DayPlanList({
    required this.date,
    required this.plans,
    required this.templates,
    required this.onAdd,
    required this.onPlanTap,
    required this.onPlanLongPress,
  });

  final DateTime date;
  final List<PlannedWorkout> plans;
  final List<WorkoutTemplateWithExercises> templates;
  final VoidCallback onAdd;
  final ValueChanged<PlannedWorkout> onPlanTap;
  final ValueChanged<PlannedWorkout> onPlanLongPress;

  String _templateName(String? templateId) {
    for (final item in templates) {
      if (item.template.id == templateId) return item.template.name;
    }
    return 'Rutina planificada';
  }

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available, color: Color(0xFF333333), size: 54),
              const SizedBox(height: 12),
              Text(
                '${DateFormat('EEE d MMM').format(date)} es descanso',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Agrega una rutina si quieres entrenar este dia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Agregar entrenamiento'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEE d MMM').format(date),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...plans.map((plan) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => onPlanTap(plan),
              onLongPress: () => onPlanLongPress(plan),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF171717),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 38,
                      decoration: BoxDecoration(
                        color: plan.isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _templateName(plan.templateId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.isCompleted ? 'Completado' : 'Pendiente',
                            style: TextStyle(
                              color: plan.isCompleted ? Colors.greenAccent : Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedDays,
    required this.selectedPlans,
    required this.onCancel,
    required this.onDelete,
  });

  final int selectedDays;
  final int selectedPlans;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, color: Colors.grey),
              tooltip: 'Cancelar',
            ),
            Expanded(
              child: Text(
                '$selectedDays dia${selectedDays == 1 ? '' : 's'} - $selectedPlans plan${selectedPlans == 1 ? '' : 'es'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.icon(
              onPressed: selectedPlans == 0 ? null : onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Borrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class PlannerSheet extends ConsumerStatefulWidget {
  const PlannerSheet({
    super.key,
    required this.date,
    required this.initialTab,
    required this.onSchedule,
    required this.onMove,
    required this.onChangeTemplate,
    required this.onDelete,
    required this.onDeleteDays,
    this.focusedPlan,
  });

  final DateTime date;
  final int initialTab;
  final PlannedWorkout? focusedPlan;
  final Future<void> Function(String templateId) onSchedule;
  final Future<void> Function(PlannedWorkout plan) onMove;
  final Future<void> Function(PlannedWorkout plan, String templateId) onChangeTemplate;
  final Future<void> Function(List<PlannedWorkout> plans) onDelete;
  final Future<void> Function(List<DateTime> days, List<PlannedWorkout> plans) onDeleteDays;

  @override
  ConsumerState<PlannerSheet> createState() => _PlannerSheetState();
}

class _PlannerSheetState extends ConsumerState<PlannerSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<DateTime> _selectedDays = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plannedWorkoutsProvider(widget.date.subtract(Duration(days: widget.date.weekday - 1)))).value ?? [];
    final templates = ref.watch(gymTemplatesProvider).value ?? [];
    final dayPlans = plans.where((plan) => _isSameDay(plan.plannedDate, widget.date)).toList();

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE d MMM').format(widget.date),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.greenAccent,
            tabs: const [
              Tab(text: 'Elegir'),
              Tab(text: 'Crear'),
              Tab(text: 'Editar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ChooseRoutineTab(
                  templates: templates,
                  plans: dayPlans,
                  focusedPlan: widget.focusedPlan,
                  onSchedule: widget.onSchedule,
                  onMove: widget.onMove,
                  onChangeTemplate: widget.onChangeTemplate,
                  onDelete: widget.onDelete,
                ),
                const CreateTemplateModal(embedded: true),
                _EditWeekTab(
                  weekStart: widget.date.subtract(Duration(days: widget.date.weekday - 1)),
                  plans: plans,
                  templates: templates,
                  selectedDays: _selectedDays,
                  onToggleDay: (date) {
                    setState(() {
                      final normalized = _dateOnly(date);
                      if (_selectedDays.contains(normalized)) {
                        _selectedDays.remove(normalized);
                      } else {
                        _selectedDays.add(normalized);
                      }
                    });
                  },
                  onDelete: () => widget.onDeleteDays(_selectedDays.toList(), plans),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChooseRoutineTab extends StatelessWidget {
  const _ChooseRoutineTab({
    required this.templates,
    required this.plans,
    required this.focusedPlan,
    required this.onSchedule,
    required this.onMove,
    required this.onChangeTemplate,
    required this.onDelete,
  });

  final List<WorkoutTemplateWithExercises> templates;
  final List<PlannedWorkout> plans;
  final PlannedWorkout? focusedPlan;
  final Future<void> Function(String templateId) onSchedule;
  final Future<void> Function(PlannedWorkout plan) onMove;
  final Future<void> Function(PlannedWorkout plan, String templateId) onChangeTemplate;
  final Future<void> Function(List<PlannedWorkout> plans) onDelete;

  String _templateName(String? templateId) {
    for (final item in templates) {
      if (item.template.id == templateId) return item.template.name;
    }
    return 'Rutina planificada';
  }

  @override
  Widget build(BuildContext context) {
    final plan = focusedPlan;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (plan != null) ...[
          const Text('Acciones rapidas', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ActionRow(
            title: _templateName(plan.templateId),
            subtitle: plan.isCompleted ? 'Completado' : 'Pendiente',
            actions: [
              _SheetAction(
                icon: Icons.drive_file_move_outline,
                label: 'Mover',
                color: Colors.white70,
                onTap: () => onMove(plan),
              ),
              _SheetAction(
                icon: Icons.swap_horiz,
                label: 'Cambiar',
                color: Colors.greenAccent,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Elige una rutina de la lista para cambiarla')),
                  );
                },
              ),
              _SheetAction(
                icon: Icons.delete_outline,
                label: 'Borrar',
                color: Colors.redAccent,
                onTap: () => onDelete([plan]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Cambiar rutina', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        ] else if (plans.isNotEmpty) ...[
          const Text('Planificado este dia', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...plans.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActionRow(
                  title: _templateName(item.templateId),
                  subtitle: item.isCompleted ? 'Completado' : 'Pendiente',
                  actions: [
                    _SheetAction(icon: Icons.drive_file_move_outline, label: 'Mover', color: Colors.white70, onTap: () => onMove(item)),
                    _SheetAction(icon: Icons.delete_outline, label: 'Borrar', color: Colors.redAccent, onTap: () => onDelete([item])),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          const Text('Agregar otra rutina', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        ],
        if (templates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Aun no tienes rutinas. Crea una desde la pestana Crear.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...templates.map((template) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: const Color(0xFF171717),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(template.template.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('${template.exercises.length} ejercicios', style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                onTap: () async {
                  if (plan == null) {
                    await onSchedule(template.template.id);
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    await onChangeTemplate(plan, template.template.id);
                  }
                },
              ),
            );
          }),
      ],
    );
  }
}

class _EditWeekTab extends StatelessWidget {
  const _EditWeekTab({
    required this.weekStart,
    required this.plans,
    required this.templates,
    required this.selectedDays,
    required this.onToggleDay,
    required this.onDelete,
  });

  final DateTime weekStart;
  final List<PlannedWorkout> plans;
  final List<WorkoutTemplateWithExercises> templates;
  final Set<DateTime> selectedDays;
  final ValueChanged<DateTime> onToggleDay;
  final VoidCallback onDelete;

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _templateName(String? templateId) {
    for (final item in templates) {
      if (item.template.id == templateId) return item.template.name;
    }
    return 'Rutina';
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlanCount = plans.where((plan) => selectedDays.any((day) => _isSameDay(day, plan.plannedDate))).length;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = weekStart.add(Duration(days: index));
              final dayPlans = plans.where((plan) => _isSameDay(plan.plannedDate, date)).toList();
              final selected = selectedDays.any((day) => _isSameDay(day, date));

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: dayPlans.isEmpty ? null : () => onToggleDay(date),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? Colors.redAccent.withOpacity(0.12) : const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Colors.redAccent : const Color(0xFF262626)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: dayPlans.isEmpty ? const Color(0xFF3A3A3A) : selected ? Colors.redAccent : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateFormat('EEE d').format(date)} - ${dayPlans.length} plan${dayPlans.length == 1 ? '' : 'es'}',
                                style: TextStyle(color: dayPlans.isEmpty ? Colors.grey : Colors.white, fontWeight: FontWeight.bold),
                              ),
                              if (dayPlans.isNotEmpty)
                                Text(
                                  dayPlans.map((plan) => _templateName(plan.templateId)).join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: selectedPlanCount == 0 ? null : onDelete,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2A2A2A),
              disabledForegroundColor: Colors.grey,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(selectedPlanCount == 0 ? 'Selecciona dias' : 'Borrar $selectedPlanCount planificaciones'),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<_SheetAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          ...actions.map((action) => IconButton(
                icon: Icon(action.icon, color: action.color),
                tooltip: action.label,
                onPressed: action.onTap,
              )),
        ],
      ),
    );
  }
}

class _SheetAction {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.label, required this.completed});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: completed ? Colors.greenAccent.withOpacity(0.12) : const Color(0xFF242424),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: completed ? Colors.greenAccent : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
