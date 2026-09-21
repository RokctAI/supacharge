// Copyright (c) 2026 ROKCT INTELLIGENCE (PTY) LTD
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:comms_sdk/comms_sdk.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:base_sdk/base_sdk.dart';
// The base barrel does not re-export the theme tokens, and section 44
// is drawn in them explicitly ("dark base tokens transcribed from
// app_style.dart") rather than in Theme.of(context).colorScheme.
import 'package:base_sdk/src/presentation/theme/app_style.dart';
import 'package:productivity_sdk/productivity_sdk.dart';
import 'package:auto_route/auto_route.dart';
import 'dart:async';
import 'dart:math';

/// The installed /tasks route page: frame 44a's workspace, hosted by
/// [TasksWorkspace].
///
/// The route keeps its argument-free constructor ON PURPOSE. The manager
/// hub pushes `const TasksRoute()` (merchants' restaurant_page.dart), and a
/// page that grows a constructor parameter stops auto_route's generated
/// route being const — which breaks the composed shell at kernel compile,
/// not here (orders 1.19.1 learnt that the hard way). Anything that needs
/// to open the workspace in a particular state builds [TasksWorkspace]
/// directly, as the /tasks/run page does on a wide window.
@RoutePage()
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) => const TasksWorkspace();
}

/// The /tasks workspace — the list, its detail / compose / run pane and
/// the objective picker on one PlaneHost (sections 44, 46 and 47).
///
/// Built by [TasksPage] as the route, and by the /tasks/run page on a
/// wide window with [initialRunId] set: frame 47a rules that a run lives
/// in 44a's DETAIL plane — "46's mechanism, unchanged — no new plane" —
/// so the standalone run route hands a wide window to this workspace with
/// the run already open rather than hosting the run on planes of its own.
class TasksWorkspace extends StatefulWidget {
  const TasksWorkspace({super.key, this.initialRunId});

  /// The task whose run holds the detail plane from the first build, or
  /// null for the workspace at rest. An id the store does not hold opens
  /// nothing.
  final String? initialRunId;

  @override
  State<TasksWorkspace> createState() => _TasksWorkspaceState();
}

class _TasksWorkspaceState extends State<TasksWorkspace> {
  late final TodoRepositoryFacade _repository;

  /// NOTES — Ray 2026-09-18, on this page: "i cant do notes its only tasks
  /// and no seperate notes if need to be". A note is not a task with the
  /// task parts left blank: it has no done state, no deadline, no priority
  /// and no steps, so it gets its own store, its own list and its own
  /// editor rather than a mode of the task form.
  ///
  /// LOCAL ONLY, AND SAID OUT LOUD. Tasks sync because a Task doctype
  /// exists to sync to; no backend this app composes holds a note, so
  /// there is no note outbox, no note pull and nothing on this half of the
  /// page that can fail for want of a network.
  late final NoteRepositoryFacade _noteRepository;
  List<Map<String, dynamic>> _notes = <Map<String, dynamic>>[];

  /// Which list the first plane is drawing.
  WorkspaceList _list = WorkspaceList.tasks;

  String? _editingNoteId;
  bool _composingNote = false;

  /// One line the note editor says when the store refused the write, and
  /// nothing else — Ray: "notes seem like cant save". `saveNote` used to
  /// swallow a failed insert and report the note as saved, so the pane
  /// closed over a note that was never written. Now a refused write keeps
  /// the pane open with what the reader typed still in it.
  bool _noteSaveFailed = false;
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteBodyController = TextEditingController();

  List<Map<String, dynamic>> _todos = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();
  // Section 46: a step may carry an instruction and a duration (minutes).
  final TextEditingController _subtaskInstructionController =
      TextEditingController();
  final TextEditingController _subtaskMinutesController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  DateTime? _selectedDeadline;
  bool _isReminderSet = false;
  String _selectedPriority = 'Medium';
  String _filterStatus = 'All'; // All, Pending, Completed

  /// Whether the reader has picked a status filter themselves this session.
  ///
  /// Ray: "when thereis completed task switch from all to pending". The
  /// tabs open on Pending when the list already holds finished work
  /// ([InitialStatusFilter]) — but that is an INITIAL value, so it is
  /// chosen only while this is false. The moment the tabs are touched the
  /// page stops choosing, or every load of the list would throw away the
  /// filter the reader had just set.
  bool _filterTouched = false;
  String _sortBy = 'Created'; // Created, Deadline, Priority
  String _recurrence = 'None'; // None, Daily, Weekly, Monthly
  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String? _editingId;

  /// Section 46: the task whose run holds the detail plane, if any.
  String? _runningId;

  /// Section 46: `stepsAreSequential` for the task being composed.
  bool _stepsInOrder = false;

  /// Section 47 (47a–47d): the maintenance template the task being
  /// composed was filled from, if any. Written to the task map's
  /// `template` key so the setup run can be told apart on the way back.
  String? _templateKey;

  /// Frame 44c: the objective link on the task being composed — the
  /// `Strategic Objective` name (the typed column the server keeps) and
  /// the title / pillar pair chip 833 reads, kept beside it because a
  /// Frappe name is a hash and the row has to say something.
  String? _strategicObjective;
  String? _strategicObjectiveTitle;
  String? _strategicObjectivePillar;

  /// Frame 44c: the objective picker (834) holds the last plane.
  bool _pickingObjective = false;

  /// The plan, read once per page through the productivity module's own
  /// `get_strategic_objectives` / `get_pillars` / `get_kpis`, on the first
  /// open of the picker. Never in front of anything: the picker draws a
  /// spinner, then the cards or the backend's own error.
  late final ObjectivesRepositoryFacade _objectives;
  ObjectiveCatalog? _objectiveCatalog;
  bool _objectivesLoading = false;
  String? _objectivesError;

  /// Section 47n: where each task stands with the server, by client id.
  /// Read from the outbox beside the list and redrawn as a badge; never
  /// waited on.
  Map<String, TaskSyncState> _syncStates = <String, TaskSyncState>{};

  /// Whether the last pull failed (`TaskPullService.lastFailure`). Read by
  /// the empty state and nowhere else: a list with rows in it says nothing
  /// about the backend, and this page never names a cmd or an error.
  bool _syncFailed = TaskPullService.syncFailed;

  String? _selectedCategory;
  List<Map<String, dynamic>> _currentSubtasks = [];

  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _recurrences = ['None', 'Daily', 'Weekly', 'Monthly'];
  // SUPERSEDED, NOT DELETED. `_sortOptions` fed the shipped
  // DropdownButton and `_getPriorityColor` (below) tinted the shipped
  // card; design strip section 44 replaced both — the sort values now
  // live in `TaskSort` (chip 827's segment) and the tint in
  // `taskPriorityColor` (chip 825). They are LEFT HERE deliberately
  // rather than removed: nothing in this pass was asked to delete
  // shipped code, and a later reader deciding they are genuinely dead
  // should be the one to say so.
  final List<String> _sortOptions = ['Created', 'Deadline', 'Priority'];
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _repository = TodoRepositoryImpl(AppDatabase());
    _noteRepository = NoteRepositoryImpl(AppDatabase());
    _objectives = const ObjectivesRepositoryImpl();
    _selectedDay = _focusedDay;
    // Frame 47a's hand-off from /tasks/run on a wide window: the run pane
    // is open from the first frame, and `_loadTodos` below drops the id
    // again if the store turns out not to hold that task.
    _runningId = widget.initialRunId;
    _initNotifications();
    _loadTodos();
    _loadNotes();
    TaskPullService.lastFailure.addListener(_onPullStatusChanged);
    // Sync runs BESIDE the page, never in front of it. The list above is
    // already being read from the local store; this asks the backend for
    // anything it knows that this device does not, and redraws only if the
    // answer actually changed something. Unawaited on purpose: there is no
    // spinner and no gate — a device with no network or no backend simply
    // never gets an answer. What the page DOES notice is a pull that
    // failed: `TaskPullService.lastFailure` is watched above, and the empty
    // state says one friendly line when the list is empty because of it.
    unawaited(_syncInBackground());
  }

  @override
  void dispose() {
    TaskPullService.lastFailure.removeListener(_onPullStatusChanged);
    _noteTitleController.dispose();
    _noteBodyController.dispose();
    super.dispose();
  }

  /// A pull completed or failed; redraw only if the answer changed.
  void _onPullStatusChanged() {
    final bool failed = TaskPullService.syncFailed;
    if (!mounted || failed == _syncFailed) return;
    setState(() => _syncFailed = failed);
  }

  /// Drains queued task pushes and pulls down whatever changed elsewhere.
  ///
  /// Nothing waits for this and nothing depends on it. `syncNow` never
  /// throws on an unreachable backend — the pull records its failure on
  /// `TaskPullService.lastFailure` and in telemetry instead — so the only
  /// visible effects it can have are MORE tasks appearing, or the empty
  /// state's one line when nothing came down because the pull failed.
  Future<void> _syncInBackground() async {
    final bool changed = await _repository.syncNow();
    if (!mounted) return;
    if (changed) {
      await _loadTodos();
    } else {
      // Nothing new came down, but pushes may have gone up: the badges
      // move from "this device" to "synced" on their own facts.
      await _refreshSyncStates();
    }
  }

  Future<void> _initNotifications() async {
    await LocalNotifications.initialize();
  }

  Future<void> _loadTodos() async {
    final todos = await _repository.loadTodos();
    if (mounted) {
      setState(() {
        _todos = todos;
        // THE TABS' OPENING VALUE, DERIVED FROM THE LIST THAT JUST LANDED —
        // Ray: "when thereis completed task switch from all to pending".
        // Only while the reader has not picked one themselves, and only
        // from the default the page was built with: a list read again
        // mid-session (a sync, a snooze, a save) must not move the tabs
        // under the reader's hand.
        if (!_filterTouched) {
          _filterStatus = switch (InitialStatusFilter.forTodos(_todos)) {
            TaskStatusFilter.pending => 'Pending',
            TaskStatusFilter.completed => 'Completed',
            TaskStatusFilter.all => 'All',
          };
        }
        // A run pane for a task the store does not hold has nothing to
        // show — the id came in by route (the 47a hand-off) or a pull took
        // the row — so the pane closes and the list stands alone.
        final String? running = _runningId;
        if (running != null &&
            !_todos.any((t) => '${t['id'] ?? ''}' == running)) {
          _runningId = null;
        }
      });
    }
    await _refreshSyncStates();
  }

  Future<void> _saveTodos() async {
    await _repository.saveTodos(_todos);
    // The save queued a push; the badge says so until the push lands.
    await _refreshSyncStates();
  }

  /// Section 47n — one query for the whole list. Local only, and never in
  /// front of anything: an unreadable outbox leaves every badge reading
  /// "this device", which is then the truth.
  Future<void> _refreshSyncStates() async {
    final Map<String, bool> byClientId = <String, bool>{
      for (final t in _todos)
        if ((t['clientId'] ?? '').toString().isNotEmpty)
          t['clientId'].toString(): (t['remoteId'] ?? '').toString().isNotEmpty,
    };
    final Map<String, TaskSyncState> states =
        await TaskSyncQueue.statesFor(byClientId);
    if (mounted) setState(() => _syncStates = states);
  }

  // =================================================================
  // NOTES — the second list, its editor and its store. Every method here
  // is the tasks equivalent with the task-only halves absent: there is no
  // sync state to refresh, no reminder to schedule, no recurrence to roll
  // over and no subtask list to deep-copy.
  // =================================================================

  Future<void> _loadNotes() async {
    final List<Map<String, dynamic>> notes = await _noteRepository.loadNotes();
    if (mounted) setState(() => _notes = notes);
  }

  /// Switches the list plane between tasks and notes.
  ///
  /// CLOSES WHATEVER THE LAST PLANE IS CARRYING. A task form left open
  /// over the notes list would save a task the reader cannot see, and the
  /// corner pill would pop a pane belonging to a list that is no longer
  /// drawn. One list, one pane.
  void _showList(WorkspaceList list) {
    if (list == _list) return;
    _closePane();
    _closeNotePane();
    setState(() => _list = list);
  }

  /// True while the last plane is carrying a note.
  bool get _notePaneOpen => _editingNoteId != null || _composingNote;

  void _openNoteComposer() {
    _closeNotePane();
    setState(() => _composingNote = true);
  }

  /// The add button's long press — names both lists and opens the chosen
  /// one's new-item form (Ray: "plus opens new but i think hlding it should
  /// give me option like tasks notes").
  ///
  /// SWITCHES THE LIST WITH THE CHOICE. Starting a note from the tasks list
  /// and leaving the tasks list drawn would save the note behind the list
  /// the reader is looking at, which is the very thing `_showList` closes
  /// panes to prevent. So the segment moves first, then the composer opens.
  Future<void> _chooseNewItem() async {
    final WorkspaceList? chosen = await showNewItemSheet(context);
    if (chosen == null || !mounted) return;
    _showList(chosen);
    if (chosen == WorkspaceList.notes) {
      _openNoteComposer();
    } else {
      _openCompose();
    }
  }

  void _startEditingNote(Map<String, dynamic> note) {
    final NoteViewModel model = NoteViewModel.fromMap(note);
    setState(() {
      _composingNote = false;
      _editingNoteId = model.id;
      _noteTitleController.text = model.title;
      _noteBodyController.text = model.body;
    });
  }

  void _closeNotePane() {
    setState(() {
      _composingNote = false;
      _editingNoteId = null;
      _noteSaveFailed = false;
      _noteTitleController.clear();
      _noteBodyController.clear();
    });
  }

  /// Writes the open note and closes the pane.
  ///
  /// AN EMPTY NOTE IS NOT SAVED. A new note with neither a title nor a
  /// body is nothing at all, and storing it would put an untitled blank in
  /// the list; an EXISTING note emptied out is deleted instead, because
  /// that is what emptying it asks for.
  Future<void> _saveNote() async {
    final String title = _noteTitleController.text.trim();
    final String body = _noteBodyController.text;
    final String? id = _editingNoteId;
    if (title.isEmpty && body.trim().isEmpty) {
      if (id != null) {
        await _deleteNote(id);
        return;
      }
      _closeNotePane();
      return;
    }
    final Map<String, dynamic> existing = id == null
        ? const <String, dynamic>{}
        : _notes.firstWhere(
            (n) => '${n['id'] ?? ''}' == id,
            orElse: () => const <String, dynamic>{},
          );
    try {
      await _noteRepository.saveNote(<String, dynamic>{
        if (id != null) 'id': id,
        if (existing['createdAt'] != null) 'createdAt': existing['createdAt'],
        'title': title,
        'body': body,
      });
    } catch (_) {
      // THE PANE STAYS OPEN AND KEEPS THE WORDS. Closing it here is what
      // made a refused write look like a save; the reader's note is still
      // in the two controllers, so the only thing this does is say so and
      // leave the Save note button where it was.
      if (mounted) setState(() => _noteSaveFailed = true);
      return;
    }
    _closeNotePane();
    // The store stamped the updatedAt the list sorts on; read it back
    // rather than guessing at it.
    await _loadNotes();
  }

  Future<void> _deleteNote(String id) async {
    await _noteRepository.deleteNote(id);
    if (_editingNoteId == id) _closeNotePane();
    await _loadNotes();
  }

  /// PLANE 3, NOTES — the note editor, the compose pane's twin. Title,
  /// body, and the two actions a note has.
  Widget _noteEditorPane(BuildContext context, Color surface) {
    final bool editing = _editingNoteId != null;
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        // The same back-pill clearance the compose pane reserves: the
        // corner pill floats over THIS plane's foot, and the actions row
        // sat under it without this.
        child: PlaneBackClearance(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ListView(
              padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
              children: [
                Text(
                  editing ? 'Note' : 'New note',
                  style: AppStyle.interSemi(
                    size: 18,
                    color: AppStyle.textPrimary,
                  ),
                ),
                14.verticalSpace,
                _fieldLabel('TITLE'),
                _textField(_noteTitleController, 'What is this about?'),
                14.verticalSpace,
                _fieldLabel('NOTE'),
                // Plain text, and the field says so by being one: no
                // toolbar, no formatting marks, nothing this SDK cannot
                // render back.
                TextField(
                  key: const ValueKey<String>('note-body'),
                  controller: _noteBodyController,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: AppStyle.interNormal(
                    size: 13,
                    color: AppStyle.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write it down…',
                    hintStyle: AppStyle.interNormal(
                      size: 13,
                      color: AppStyle.textDarkFaint,
                    ),
                    filled: true,
                    fillColor: AppStyle.cardDarkAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_noteSaveFailed) ...[
                  12.verticalSpace,
                  _noteSaveFailedLine(),
                ],
                20.verticalSpace,
                _noteActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The one line a refused note write earns. Names nothing technical:
  /// the reader cannot act on a table name and this page never prints one.
  Widget _noteSaveFailedLine() {
    return Container(
      key: const ValueKey<String>('note-save-failed'),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppStyle.cardDarkAlt,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppStyle.red),
      ),
      child: Text(
        'This note could not be saved on this device. Your words are still '
        'here — try Save note again.',
        style: AppStyle.interNormal(size: 11, color: AppStyle.red),
      ),
    );
  }

  Widget _noteActions() {
    final String? id = _editingNoteId;
    return Row(
      children: [
        if (id != null) ...[
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () => _deleteNote(id),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, 44.h),
                side: BorderSide(color: AppStyle.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'Delete',
                style: AppStyle.interSemi(size: 13, color: AppStyle.red),
              ),
            ),
          ),
          10.horizontalSpace,
        ],
        Expanded(
          flex: 3,
          child: ElevatedButton(
            key: const ValueKey<String>('note-save'),
            onPressed: _saveNote,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.primary,
              foregroundColor: AppStyle.blackColor,
              minimumSize: Size(0, 44.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'Save note',
              style: AppStyle.interSemi(size: 13, color: AppStyle.blackColor),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportData() async {
    await _repository.exportTodos(_todos);
  }

  void _saveTask() {
    if (_controller.text.trim().isEmpty) return;

    final String title = _controller.text.trim();
    final String? deadlineStr = _selectedDeadline?.toIso8601String();
    final String? category = _categoryController.text.trim().isNotEmpty
        ? _categoryController.text.trim()
        : _selectedCategory;

    setState(() {
      if (_editingId != null) {
        // Updating existing by UUID
        final index = _todos.indexWhere((t) => t['id'] == _editingId);
        if (index != -1) {
          final String id = _editingId!;
          final int notifId =
              _todos[index]['notifId'] ?? Random().nextInt(100000);
          // The task's own start — what its end date is measured from
          // (section 47m, second pass). Kept as a DateTime rather than
          // re-parsed twice: the same value is written back and handed to
          // the rule.
          final DateTime createdAt =
              DateTime.tryParse('${_todos[index]['createdAt'] ?? ''}') ??
                  DateTime.now();

          LocalNotifications.cancelNotification(notifId);

          // Spread the stored map first: the form does not show remindAt,
          // snoozeCount, reminderFired, the sync ids or the step
          // timestamps, and rebuilding the map from the form alone
          // silently dropped every one of them on each edit.
          _todos[index] = {
            ..._todos[index],
            'id': id,
            'notifId': notifId,
            'title': title,
            'isDone': _todos[index]['isDone'],
            'deadline': deadlineStr,
            'reminder': _isReminderSet,
            'priority': _selectedPriority,
            'category': category,
            'recurrence': _recurrence,
            'stepsAreSequential': _stepsInOrder,
            // SECTION 47m, SECOND PASS — DERIVED, NEVER PICKED. Ray:
            // "long term task is selected not automatically detected from
            // end date". The switch that used to sit on this form is gone;
            // a deadline further out than LongTermRule.horizonDays from
            // the task's start is what puts it in the band, so moving the
            // deadline moves the task between the bands on save.
            'isLongTerm': LongTermRule.isLongTerm(
              endDate: _selectedDeadline,
              createdAt: createdAt,
            ),
            if (_templateKey != null)
              MaintenanceTemplates.templateKey: _templateKey,
            ..._objectiveLinkFields(existing: _todos[index]),
            'createdAt': createdAt.toIso8601String(),
            'subtasks': _currentSubtasks
                .map((s) => Map<String, dynamic>.from(s))
                .toList(),
          };

          if (_isReminderSet && _selectedDeadline != null) {
            LocalNotifications.scheduleNotification(
              id: notifId,
              title: 'Task Reminder',
              body: title,
              scheduledDate: _selectedDeadline!,
            );
          }
        }
        _editingId = null;
      } else {
        // Adding new
        final String id = _uuid.v4();
        final int notifId = Random().nextInt(100000);
        // A new task has no start but the moment it was made, which is
        // what the long-term rule measures its deadline against.
        final DateTime createdAt = DateTime.now();
        _todos.add({
          'id': id,
          'notifId': notifId,
          'title': title,
          'isDone': false,
          'deadline': deadlineStr,
          'reminder': _isReminderSet,
          'priority': _selectedPriority,
          'category': category,
          'recurrence': _recurrence,
          'stepsAreSequential': _stepsInOrder,
          // Same derivation as the edit branch above.
          'isLongTerm': LongTermRule.isLongTerm(
            endDate: _selectedDeadline,
            createdAt: createdAt,
          ),
          if (_templateKey != null)
            MaintenanceTemplates.templateKey: _templateKey,
          ..._objectiveLinkFields(),
          'createdAt': createdAt.toIso8601String(),
          'subtasks': _currentSubtasks
              .map((s) => Map<String, dynamic>.from(s))
              .toList(),
        });

        if (_isReminderSet && _selectedDeadline != null) {
          LocalNotifications.scheduleNotification(
            id: notifId,
            title: 'Task Reminder',
            body: title,
            scheduledDate: _selectedDeadline!,
          );
        }
      }

      // Reset form
      _controller.clear();
      _categoryController.clear();
      _subtaskController.clear();
      _subtaskInstructionController.clear();
      _subtaskMinutesController.clear();
      _selectedDeadline = null;
      _isReminderSet = false;
      _selectedPriority = 'Medium';
      _recurrence = 'None';
      _stepsInOrder = false;
      _templateKey = null;
      _strategicObjective = null;
      _strategicObjectiveTitle = null;
      _strategicObjectivePillar = null;
      _pickingObjective = false;
      _selectedCategory = null;
      _currentSubtasks = [];
    });
    _saveTodos();
  }

  void _addSubtask() {
    if (_subtaskController.text.trim().isNotEmpty) {
      // Section 46: the step's instruction and duration. Minutes on the
      // form, seconds on the map and the wire; 0 is an untimed step.
      final String instruction = _subtaskInstructionController.text.trim();
      final int minutes =
          int.tryParse(_subtaskMinutesController.text.trim()) ?? 0;
      setState(() {
        _currentSubtasks.add({
          'title': _subtaskController.text.trim(),
          'isDone': false,
          if (instruction.isNotEmpty) 'instruction': instruction,
          'durationSeconds': minutes < 0 ? 0 : minutes * 60,
        });
        _subtaskController.clear();
        _subtaskInstructionController.clear();
        _subtaskMinutesController.clear();
      });
    }
  }

  void _toggleSubtaskStatus(int taskIndex, int subtaskIndex) {
    setState(() {
      final subtasks = List<Map<String, dynamic>>.from(
        _todos[taskIndex]['subtasks'] ?? [],
      );
      subtasks[subtaskIndex]['isDone'] =
          !(subtasks[subtaskIndex]['isDone'] ?? false);
      _todos[taskIndex]['subtasks'] = subtasks;
    });
    _saveTodos();
  }

  void _toggleFormSubtaskStatus(int subtaskIndex) {
    setState(() {
      _currentSubtasks[subtaskIndex]['isDone'] =
          !(_currentSubtasks[subtaskIndex]['isDone'] ?? false);
    });
  }

  void _startEditing(int index) {
    setState(() {
      final task = _todos[index];
      _editingId = task['id'];
      // The card's expansion and the form are two views of one task, and on
      // the phone fold the form is a push over the list: leaving the card
      // expanded behind it means popping back onto a card mid-edit.
      _expandedId = null;
      _controller.text = task['title'];
      _selectedPriority = task['priority'] ?? 'Medium';
      _isReminderSet = task['reminder'] ?? false;
      _recurrence = task['recurrence'] ?? 'None';
      _stepsInOrder = task['stepsAreSequential'] == true;
      _templateKey = _linkText(task[MaintenanceTemplates.templateKey]);
      _strategicObjective = _linkText(task['strategicObjective']);
      _strategicObjectiveTitle = _linkText(task['strategicObjectiveTitle']);
      _strategicObjectivePillar = _linkText(task['strategicObjectivePillar']);
      _pickingObjective = false;
      _selectedCategory = task['category'];
      _categoryController.text = task['category'] ?? '';

      // Deep Copy Subtasks
      if (task['subtasks'] != null) {
        _currentSubtasks = (task['subtasks'] as List)
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      } else {
        _currentSubtasks = [];
      }

      if (task['deadline'] != null) {
        _selectedDeadline = DateTime.parse(task['deadline']);
      } else {
        _selectedDeadline = null;
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _controller.clear();
      _categoryController.clear();
      _subtaskController.clear();
      _subtaskInstructionController.clear();
      _subtaskMinutesController.clear();
      _selectedDeadline = null;
      _isReminderSet = false;
      _selectedPriority = 'Medium';
      _recurrence = 'None';
      _stepsInOrder = false;
      _templateKey = null;
      _strategicObjective = null;
      _strategicObjectiveTitle = null;
      _strategicObjectivePillar = null;
      _pickingObjective = false;
      _selectedCategory = null;
      _currentSubtasks = [];
    });
  }

  void _handleRecurrence(Map<String, dynamic> task) {
    final String recurrence = task['recurrence'] ?? 'None';
    if (recurrence == 'None' || task['deadline'] == null) return;

    final DateTime currentDeadline = DateTime.parse(task['deadline']);
    DateTime nextDeadline;

    if (recurrence == 'Daily') {
      nextDeadline = currentDeadline.add(const Duration(days: 1));
    } else if (recurrence == 'Weekly') {
      nextDeadline = currentDeadline.add(const Duration(days: 7));
    } else if (recurrence == 'Monthly') {
      nextDeadline = DateTime(
        currentDeadline.year,
        currentDeadline.month + 1,
        currentDeadline.day,
        currentDeadline.hour,
        currentDeadline.minute,
      );
    } else {
      return;
    }

    final String newId = _uuid.v4();
    final int notifId = Random().nextInt(100000);
    final bool hasReminder = task['reminder'] ?? false;
    final DateTime createdAt = DateTime.now();

    _todos.add({
      'id': newId,
      'notifId': notifId,
      'title': task['title'],
      'isDone': false,
      'deadline': nextDeadline.toIso8601String(),
      'reminder': hasReminder,
      'priority': task['priority'],
      'category': task['category'],
      'recurrence': recurrence,
      'createdAt': createdAt.toIso8601String(),
      'stepsAreSequential': task['stepsAreSequential'] == true,
      // The next instance is measured on its OWN dates, not the finished
      // one's: a weekly task whose next deadline is seven days out is not
      // long term however the instance before it was banded.
      'isLongTerm': LongTermRule.isLongTerm(
        endDate: nextDeadline,
        createdAt: createdAt,
      ),
      // Frame 44c: the objective is part of the procedure, not of the
      // progress — the next instance serves the same objective.
      if (task.containsKey('strategicObjective')) ...<String, dynamic>{
        'strategicObjective': task['strategicObjective'],
        'strategicObjectiveTitle': task['strategicObjectiveTitle'],
        'strategicObjectivePillar': task['strategicObjectivePillar'],
      },
      // The next instance starts with the PROCEDURE (title, instruction,
      // duration) and none of the run's progress: isDone cleared as
      // before, and the step timestamps with it.
      'subtasks': (task['subtasks'] as List?)
              ?.map((s) => TaskRunStep.freshCopy(Map<String, dynamic>.from(s)))
              .toList() ??
          [],
    });

    if (hasReminder) {
      LocalNotifications.scheduleNotification(
        id: notifId,
        title: 'Task Reminder',
        body: task['title'],
        scheduledDate: nextDeadline,
      );
    }
  }

  void _toggleTodo(int index) {
    final int notifId = _todos[index]['notifId'] ?? Random().nextInt(100000);

    setState(() {
      _todos[index]['isDone'] = !_todos[index]['isDone'];

      if (_todos[index]['isDone']) {
        LocalNotifications.cancelNotification(notifId);
        _handleRecurrence(_todos[index]);
      } else {
        final bool hasReminder = _todos[index]['reminder'] ?? false;
        final String? deadlineStr = _todos[index]['deadline'];
        if (hasReminder && deadlineStr != null) {
          final DateTime deadlineDate = DateTime.parse(deadlineStr);
          if (deadlineDate.isAfter(DateTime.now())) {
            LocalNotifications.scheduleNotification(
              id: notifId,
              title: 'Task Reminder',
              body: _todos[index]['title'],
              scheduledDate: deadlineDate,
            );
          }
        }
      }
    });
    _saveTodos();
  }

  void _removeTodo(int index) {
    LocalNotifications.cancelNotification(_todos[index]['notifId'] ?? 0);

    // Take the id before the map leaves the list: the row has to be deleted
    // by name. saveTodos only inserts and updates, so dropping the task from
    // _todos alone left the row behind and the task came back on the next
    // start. Pruning inside the save instead would be worse - this table has
    // another writer, and a save that deleted every row absent from this
    // list would delete that writer's rows too.
    final String id = (_todos[index]['id'] ?? '').toString();

    setState(() {
      _todos.removeAt(index);
    });
    _deleteTodo(id);
  }

  Future<void> _deleteTodo(String id) async {
    await _repository.deleteTodo(id);
  }

  Future<void> _pickDeadline() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDeadline != null
            ? TimeOfDay.fromDateTime(_selectedDeadline!)
            : TimeOfDay.now(),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDeadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Color _getPriorityColor(String priority, ColorScheme colors) {
    switch (priority) {
      case 'High':
        return colors.error;
      case 'Medium':
        return colors.primary;
      case 'Low':
        return Colors.green;
      default:
        return colors.primary;
    }
  }

  int _priorityWeight(String priority) {
    if (priority == 'High') return 3;
    if (priority == 'Medium') return 2;
    return 1;
  }

  List<MapEntry<int, Map<String, dynamic>>> _getFilteredAndSortedTodos() {
    // 1. Filter
    var filtered = _todos.asMap().entries.where((entry) {
      final todo = entry.value;
      if (_filterStatus == 'Pending' && todo['isDone'] == true) return false;
      if (_filterStatus == 'Completed' && todo['isDone'] == false) return false;

      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        final title = (todo['title'] as String).toLowerCase();
        final cat = (todo['category'] as String?)?.toLowerCase() ?? '';
        if (!title.contains(query) && !cat.contains(query)) return false;
      }

      if (_showCalendar && _selectedDay != null) {
        final deadlineStr = todo['deadline'] as String?;
        if (deadlineStr == null) return false;
        final dDate = DateTime.parse(deadlineStr);
        if (!isSameDay(dDate, _selectedDay)) return false;
      }

      return true;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final ta = a.value;
      final tb = b.value;

      if (_sortBy == 'Priority') {
        final wa = _priorityWeight(ta['priority'] ?? 'Medium');
        final wb = _priorityWeight(tb['priority'] ?? 'Medium');
        if (wa != wb) return wb.compareTo(wa); // Descending
      } else if (_sortBy == 'Deadline') {
        final daStr = ta['deadline'] as String?;
        final dbStr = tb['deadline'] as String?;
        if (daStr != null && dbStr != null) {
          return DateTime.parse(daStr).compareTo(DateTime.parse(dbStr));
        } else if (daStr != null) {
          return -1;
        } else if (dbStr != null) {
          return 1;
        }
      }

      // Default fallback to Created
      final caStr = ta['createdAt'] as String?;
      final cbStr = tb['createdAt'] as String?;
      if (caStr != null && cbStr != null) {
        return DateTime.parse(
          cbStr,
        ).compareTo(DateTime.parse(caStr)); // Newest first
      }
      return 0;
    });

    return filtered;
  }

  // ===================================================================
  // DESIGN STRIP SECTION 44 — the /tasks workspace.
  //
  // The page was BUILT and the screen was never designed; this is that
  // design pass, applied to the settled plane language. Frames 44a
  // (list · detail), 44b (the compose lane), 44d (the phone fold) and
  // 44e (calendar mode) are all states of this one composition.
  //
  // NO FIELD IS ADDED AND NONE IS REMOVED. Every handler above this
  // line is the shipped one, untouched: _saveTask, _startEditing,
  // _cancelEditing, _toggleTodo, _removeTodo, _addSubtask,
  // _toggleSubtaskStatus, _toggleFormSubtaskStatus, _handleRecurrence,
  // _pickDeadline, _exportData and _getFilteredAndSortedTodos. What
  // changed is where things are drawn, not what they do.
  //
  // THE PLANE CLAIM, AND THE FORK THIS FILE CLOSES. Frame 44a's own
  // stamp reads "/tasks DECLARES 2 — HUB YIELDS TO 1", while section 7e
  // had drawn /tasks landing in the bare trailing plane (a claim of
  // one). The frame calls that "a choice, not a defect" and asks for it
  // to be made explicitly rather than inherited. THIS FILE PICKS TWO,
  // on 44a's stamp: the workspace is two planes side by side — the list
  // in one, the detail / compose / run pane in the LAST — which is the
  // whole point of 44b: the shipped page wedged the compose form ABOVE
  // the list, five Expanded rows of chips and dropdowns competing with
  // the list for the same column.
  //
  // HOW THE TWO ARE DECLARED (TasksPlaneClaims). 44a's list is ONE plane
  // wide beside its pane — a single column of cards, not a column
  // stretched over two planes — so the list claims one plane and grows
  // into a second only while nothing else is on the stage
  // (PlaneSpan.twoIfSpare); the pane makes the default one-plane claim.
  // Three planes with a pane open are therefore list | pane | bare, two
  // planes are list | pane, and a run (46a, 47a) or the picker (44c) is
  // the same composition with a different pane. The plane 44a gives the
  // HUB — the manager hub compressed to one plane, its PRODUCTIVITY row
  // lit — is not this page's to draw: that hub is merchants_sdk's
  // RestaurantHubPlaneFlow, a one-step host whose rows push REAL routes,
  // and this SDK never imports it (ADR-005). Until the hub hosts /tasks
  // inside its own flow (the commerce half of 44a, not built here), the
  // plane it would keep trails BARE at the end, the ruled place for a
  // leftover plane (Ray 2026-08-29 10:47Z).
  //
  // The mechanism is base_sdk's PlaneHost — the section 38 list flow
  // ListPlaneFlow wraps, spelled out here because frame 44c pushes a
  // THIRD step (the objective picker) that the wrapper cannot express.
  // The corner back pill (canonical 347) pops the newest step while a
  // pane is open; at the root of a wide window this page floats the same
  // pill itself, popping the route to the hub — see build().
  //
  // TWO FLAGS RIDE THIS SCREEN AND ARE DRAWN, NOT HIDDEN. A THIRD IS
  // GONE:
  //   (a) WAS "these tasks live on this device only — no remote store,
  //       no sync", drawn by the local-only strip (828) above the first
  //       card. It is no longer true and the strip is no longer drawn:
  //       the workspace now syncs against the personal-task endpoints
  //       in `projects/frappe/src/task_sync.py` through the SyncEngine
  //       outbox. The local store is still the source of truth for
  //       every read on this page and every write still lands there
  //       first, so a device with no backend behaves exactly as it did
  //       when the strip was accurate — that part did not change, and
  //       must not.
  //   (b) `recurrence` is stored and NOTHING ever acts on it: no
  //       scheduler, no rollover, no next-instance creation anywhere in
  //       the SDK. A task marked Daily is a label. The REPEATS quad is
  //       drawn because the field is real.
  //   (c) the reminder toggle promises a LOCAL notification at the
  //       deadline and nothing more.
  // ===================================================================

  /// FRAME 44d — the fold. On one plane the detail pane has no phone
  /// form of its own: the first card expands IN PLACE, which is the
  /// shipped ExpansionTile behaviour kept, so the subtask check lines
  /// still reach the phone rather than becoming a second push.
  ///
  /// Read from the plane COUNT, never from this page's span: beside an
  /// open pane the list is granted ONE plane on a three-plane window too
  /// (44a), and that is not the fold. Outside a plane — the page's own
  /// context, above its host — the count comes from the window width by
  /// the host's thresholds, as TaskRunView derives it.
  bool _isSinglePlane(BuildContext context) =>
      (Planes.maybeOf(context)?.count ??
          PlaneHost.planeCountFor(MediaQuery.sizeOf(context).width)) <
      2;

  /// The task whose card is expanded on the phone fold.
  String? _expandedId;

  TaskStatusFilter get _statusFilter => switch (_filterStatus) {
        'Pending' => TaskStatusFilter.pending,
        'Completed' => TaskStatusFilter.completed,
        _ => TaskStatusFilter.all,
      };

  TaskSort get _sort => switch (_sortBy) {
        'Deadline' => TaskSort.deadline,
        'Priority' => TaskSort.priority,
        _ => TaskSort.created,
      };

  /// The tab counts, DERIVED from the same list the tabs filter — there
  /// is no count field to read.
  Map<TaskStatusFilter, int> get _statusCounts => {
        TaskStatusFilter.all: _todos.length,
        TaskStatusFilter.pending:
            _todos.where((t) => t['isDone'] != true).length,
        TaskStatusFilter.completed:
            _todos.where((t) => t['isDone'] == true).length,
      };

  @override
  Widget build(BuildContext context) {
    // A BuildContext lookup for the mode, not the app-wide AppStyle.isDark
    // static (Ray, 2026-09-19: "glance doesnt change test immediately
    // untill you come back if you switched theme mode" — the same defect,
    // found in this page by the audit that followed).
    //
    // Read HERE, in the State's own build and outside the LayoutBuilder and
    // the plane builders below, so the dependency lands on this element:
    // AppStyle's mode-resolving statics carry the right value but are not
    // an inherited widget, so reading one registers nothing — and this page
    // is a pushed ModalRoute, which caches the widget it built, so an
    // ancestor rebuild provably never reaches it either. The workspace and
    // every pane in it kept the previous mode's ground until the reader
    // left /tasks and came back. The resolved colour is handed DOWN to the
    // panes rather than each of them asking a static again, so the whole
    // page is painted for one mode: the one the theme reports.
    final Brightness brightness = Theme.of(context).brightness;
    final Color surface = AppStyle.surfaceFor(brightness);

    final String? runningId = _runningId;
    // A NOTE TAKES THE SAME LAST PLANE, and only ever instead of a task
    // pane: switching lists closes whatever was open (_showList), so the
    // two can never both be carrying something.
    final bool noteOpen = _notePaneOpen;
    final String? detailName = noteOpen
        ? 'note-${_editingNoteId ?? 'new'}'
        : runningId != null
            ? 'run-$runningId'
            : _editingId ?? (_paneOpen ? 'compose' : null);
    final WidgetBuilder? detailBuilder = noteOpen
        ? (context) => _noteEditorPane(context, surface)
        : runningId != null
            ? (context) => _runPane(context, runningId, surface)
            : _paneOpen
                ? (context) => _composePane(context, surface)
                : null;
    // The section-38 list flow, spelled out as the PlaneHost stack
    // ListPlaneFlow builds — same page names, same corner Back (347) —
    // because FRAME 44c pushes a THIRD step: the objective picker (834)
    // is a 1-plane push that wins the last plane, and "newest wins" then
    // slides list + detail left (the detail compresses into plane 2, the
    // list into plane 1). ListPlaneFlow carries exactly one detail and
    // cannot express that push; PlaneHost is what it wraps.
    //
    // THE GROUND IS PAINTED HERE, ONCE, and again by each plane's
    // Scaffold. Nothing beneath this page paints one: PlaneHost lays
    // its planes side by side over a 14-logical seam and leaves any
    // unclaimed plane an empty stage, AdaptiveShell adds nothing, and
    // the app theme sets no scaffoldBackgroundColor — so a transparent
    // page showed the platform's raw surface (opaque black on Android)
    // in BOTH theme modes. [AppStyle.surfaceFor] answers with the same two
    // values (light #ECECEF, dark #101010) for the mode the inherited
    // theme reports, the same seam task_run_page.dart paints.
    final Widget host = PlaneHost(
      back: FloatingNavBack(
        icon: Icons.arrow_back,
        label: AppHelpers.getTranslation(TrKeys.back),
        // The pill pops the NEWEST step: the picker while it is open,
        // else the detail / compose / run pane.
        onTap: _popPlane,
      ),
      stack: [
        PlanePage(
          name: 'list',
          span: TasksPlaneClaims.list,
          builder: (context) => _listPlane(context, surface),
        ),
        if (detailBuilder != null)
          PlanePage(
            name: 'list-detail-${detailName ?? ''}',
            span: TasksPlaneClaims.pane,
            builder: detailBuilder,
          ),
        if (detailBuilder != null &&
            _pickingObjective &&
            runningId == null &&
            !noteOpen)
          PlanePage(
            name: 'objective-picker',
            span: TasksPlaneClaims.pane,
            builder: (context) => _objectivePickerPane(context, surface),
          ),
      ],
    );
    return ColoredBox(
      color: surface,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // CANONICAL 347 AT THE ROOT OF A WIDE WINDOW. Frame 44a: "nav
          // has folded to the corner back pill because a pushed page
          // holds a plane", and 47a: "the corner Back still pops to the
          // hub". PlaneHost floats its pill only while the flow is deeper
          // than its root, so with nothing open this pushed page had no
          // way back on a tablet at all. The same pill, in the same
          // corner PlaneHost and calc's CalculatorView park it, pops the
          // ROUTE; the moment a pane opens PlaneHost's own pill takes
          // over (one back per screen, never two). One-plane windows are
          // untouched: the fold keeps its shipped navigation.
          final bool wide = PlaneHost.planeCountFor(constraints.maxWidth) >= 2;
          if (!wide || detailBuilder != null) return host;
          return Stack(
            children: [
              host,
              PositionedDirectional(
                end: 16,
                bottom: 16,
                child: SafeArea(
                  child: FloatingBackPill(
                    back: FloatingNavBack(
                      icon: Icons.arrow_back,
                      label: AppHelpers.getTranslation(TrKeys.back),
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Canonical 347 — back pops one step.
  void _popPlane() {
    if (_pickingObjective) {
      setState(() => _pickingObjective = false);
      return;
    }
    if (_notePaneOpen) {
      _closeNotePane();
      return;
    }
    _closePane();
  }

  /// True while the last plane is carrying something — an edit (the
  /// detail pane, 829), a new task (the compose lane, 830), or a run
  /// (section 46). Create and edit are ONE component with an empty
  /// model, exactly as the shipped page already treats them via
  /// `_editingId`.
  bool get _paneOpen => _editingId != null || _composing || _runningId != null;

  bool _composing = false;

  void _openCompose() {
    _cancelEditing();
    setState(() {
      _composing = true;
      _runningId = null;
    });
  }

  void _closePane() {
    _cancelEditing();
    setState(() {
      _composing = false;
      _runningId = null;
    });
  }

  // ===================================================================
  // DESIGN STRIP FRAME 44c — the M2 bridge, hosted here.
  //
  // Chip 833 (the link row in the detail pane) opens chip 834 (the
  // picker) as a further push with the default 1-plane claim. The plan
  // is read through the productivity module's own get_* endpoints; the
  // link is written onto the TASK MAP as `strategicObjective` and
  // travels through the existing `task.upsert` op to Task's typed
  // `strategic_objective` column. Nothing here can reach commit_plan.
  //
  // For a task being EDITED, Link objective writes at once — the row is
  // already a saved task and the link is a fact about it. For a task
  // being COMPOSED, the link waits on Save task with every other field.
  // ===================================================================

  static String? _linkText(Object? value) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  /// The link as it goes onto the task map.
  ///
  /// Absent is silence: a task that never had a link gets NO key, so the
  /// sync never mentions the column. A key present with null is an
  /// UNLINK — the wire sends the empty string that clears the column —
  /// which is why a task that had one keeps the key when it is removed.
  Map<String, dynamic> _objectiveLinkFields({Map<String, dynamic>? existing}) {
    final bool had = existing?.containsKey('strategicObjective') ?? false;
    if (_strategicObjective == null && !had) return const <String, dynamic>{};
    return <String, dynamic>{
      'strategicObjective': _strategicObjective,
      'strategicObjectiveTitle': _strategicObjectiveTitle,
      'strategicObjectivePillar': _strategicObjectivePillar,
    };
  }

  /// Chip 833 — open the picker. Reads the plan on the first open.
  void _openObjectivePicker() {
    setState(() => _pickingObjective = true);
    if (_objectiveCatalog == null && !_objectivesLoading) {
      unawaited(_loadObjectives());
    }
  }

  Future<void> _loadObjectives() async {
    setState(() {
      _objectivesLoading = true;
      _objectivesError = null;
    });
    final ApiResult<ObjectiveCatalog> result = await _objectives.loadCatalog();
    if (!mounted) return;
    setState(() {
      _objectivesLoading = false;
      switch (result) {
        case Success<ObjectiveCatalog>(:final data):
          _objectiveCatalog = data;
        case Failure<ObjectiveCatalog>(:final error):
          _objectivesError = error;
      }
    });
  }

  /// Chip 834's Link objective (or its clear, for null): the link lands
  /// on the form, and — for a saved task — on the task map and the store.
  void _applyObjectiveLink(StrategicObjective? objective) {
    final Pillar? pillar = _objectiveCatalog?.pillarNamed(objective?.pillar);
    setState(() {
      _strategicObjective = objective?.name;
      _strategicObjectiveTitle = objective?.title;
      _strategicObjectivePillar = pillar?.title;
      _pickingObjective = false;
      final String? id = _editingId;
      if (id != null) {
        final int index = _todos.indexWhere((t) => t['id'] == id);
        if (index != -1) {
          _todos[index] = <String, dynamic>{
            ..._todos[index],
            ..._objectiveLinkFields(existing: _todos[index]),
          };
        }
      }
    });
    if (_editingId != null) _saveTodos();
  }

  /// The task being composed, as chip 833 reads it: only the link fields
  /// matter to the row, and they come off the form state.
  TaskViewModel get _composedTask => TaskViewModel(
        id: _editingId ?? '',
        title: _controller.text,
        strategicObjective: _strategicObjective,
        strategicObjectiveTitle: _strategicObjectiveTitle,
        strategicObjectivePillar: _strategicObjectivePillar,
      );

  /// PLANE 3 (the LAST plane) — chip 834, the objective picker.
  Widget _objectivePickerPane(BuildContext context, Color surface) {
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: ObjectivePickerPane(
          key: const ValueKey<String>('objective-picker'),
          catalog: _objectiveCatalog,
          loading: _objectivesLoading,
          error: _objectivesError,
          initialSelection: _strategicObjective,
          onCancel: () => setState(() => _pickingObjective = false),
          onLink: _applyObjectiveLink,
          onRetry: _loadObjectives,
        ),
      ),
    );
  }

  // ===================================================================
  // DESIGN STRIP SECTION 46 — the guided run, hosted here.
  //
  // FRAME 46a: "the run is 44a's detail plane — no new push". On a wide
  // window the run takes the LAST plane exactly as the compose lane
  // does, so it claims no new plane and the corner Back (347) still pops
  // /tasks back to the hub. FRAME 46f: at one plane there is no detail
  // plane to land in, so the phone pushes the /tasks/run route with the
  // same view filling the screen.
  //
  // THE PAGE OWNS NO RUN STATE. TaskRunView derives everything from the
  // task map and hands the map back with progress written onto it; this
  // page puts it in the list and saves it the way it saves everything —
  // drift first, the outbox push unawaited behind it.
  //
  // DESIGN STRIP SECTION 47 (47a–47d, 47h, 47i) rides this same host
  // unchanged: an RO plant's service run is a task made from a template
  // (see `_templateChooser` in the compose lane), so it opens here, in
  // the detail plane, with the same view, the same Leave and the same
  // corner pill. Reading and photo steps are the view's business.
  // ===================================================================

  /// Chip 859 — open a task's run. The run pill on the card leads here:
  /// into the detail plane on a wide window (46a / 47a), onto the pushed
  /// /tasks/run page at one plane (46f). The width is read from this
  /// page's own context, above the host, so the fold test falls back to
  /// the window width.
  Future<void> _openRun(int index) async {
    final Map<String, dynamic> task = _todos[index];
    final String id = '${task['id'] ?? ''}';
    if (id.isEmpty) return;
    if (!_isSinglePlane(context)) {
      _cancelEditing();
      setState(() {
        _composing = false;
        _runningId = id;
      });
      return;
    }
    // The pushed page persists through the same repository; reload on
    // return so the badge on the card reads the run's new position, and
    // tick the task when the finished card asked for it.
    final Object? result = await context.router.pushNamed(
      '/tasks/run?task=$id',
    );
    if (!mounted) return;
    await _loadTodos();
    if (result == true) {
      final int again = _todos.indexWhere((t) => t['id'] == id);
      if (again != -1 && _todos[again]['isDone'] != true) _toggleTodo(again);
    }
  }

  /// The run wrote progress onto its task: put the map back and save.
  /// Frame 47d: when that task is the plant-setup run and it has been
  /// finished, its readings become the device's plant record — read by
  /// the maintenance templates for their due dates. Any other task is
  /// left alone by the capture.
  void _onRunChanged(Map<String, dynamic> task) {
    final int index = _todos.indexWhere((t) => t['id'] == task['id']);
    if (index == -1) return;
    setState(() => _todos[index] = task);
    _saveTodos();
    unawaited(MaintenancePlantStore.local.captureFromRun(task));
  }

  /// PLANE 3 (the LAST plane) — the run, in place of the static detail.
  Widget _runPane(BuildContext context, String id, Color surface) {
    final int index = _todos.indexWhere((t) => t['id'] == id);
    if (index == -1) {
      return const SizedBox.shrink();
    }
    final Map<String, dynamic> task = _todos[index];
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: TaskRunView(
          key: ValueKey<String>('run-$id'),
          task: task,
          onChanged: _onRunChanged,
          // Chip 866 — Leave, progress kept: nothing is written on the
          // way out, and the corner pill (347) does the same.
          onLeave: _closePane,
          onMarkDone: () {
            final int again = _todos.indexWhere((t) => t['id'] == id);
            if (again != -1 && _todos[again]['isDone'] != true) {
              _toggleTodo(again);
            }
            _closePane();
          },
        ),
      ),
    );
  }

  /// The words on a card's run pill: "Run" for an untouched run, else
  /// where it stopped — "Resume · Step 3 of 9" — unless that run is the
  /// one open in the plane right now, where "Resume" would be wrong.
  String _runLabelFor(TaskViewModel task) {
    final TaskRun run = task.run;
    final String? position = run.positionLabel;
    if (position == null) return 'Run';
    return task.id == _runningId ? position : 'Resume · $position';
  }

  // ===================================================================
  // DESIGN STRIP SECTION 47 — snooze (47k / 47l), the long-term band
  // (47m) and the sync-state badge (47n). Properties of THE TASK, every
  // task; no vertical has a privilege here.
  // ===================================================================

  /// CHIPS 1060 / 1062 — snooze this task's reminder. The sheet hands
  /// back a reminder time and nothing else; `snoozeReminder` writes it
  /// and NEVER the deadline; the device-local notification moves with it
  /// (47n: it reminds on this device until the push lands).
  Future<void> _snooze(int index) async {
    final Map<String, dynamic> todo = _todos[index];
    final TaskViewModel task = TaskViewModel.fromMap(todo);
    final DateTime? remindAt = await showSnoozeSheet(context, task: task);
    if (remindAt == null || !mounted) return;
    final bool applied = await _repository.snoozeReminder(task.id, remindAt);
    if (!applied || !mounted) return;
    final int notifId = todo['notifId'] ?? Random().nextInt(100000);
    LocalNotifications.cancelNotification(notifId);
    LocalNotifications.scheduleNotification(
      id: notifId,
      title: 'Task Reminder',
      body: task.title,
      scheduledDate: remindAt,
    );
    unawaited(
      TelemetryClient.I.track(
        'task_reminder_snoozed',
        properties: <String, dynamic>{
          'minutes_ahead': remindAt.difference(DateTime.now()).inMinutes,
          'snooze_count': task.snoozeCount + 1,
        },
      ),
    );
    // The repository wrote the row; read it back rather than guessing at
    // what it holds now.
    await _loadTodos();
  }

  /// CHIP 1064 — the day's list, split into the long-term band and the
  /// rest. Both halves keep the filter and sort the list already has.
  ({
    List<MapEntry<int, Map<String, dynamic>>> longTerm,
    List<MapEntry<int, Map<String, dynamic>>> rest
  }) _banded(List<MapEntry<int, Map<String, dynamic>>> displayed) {
    final longTerm = <MapEntry<int, Map<String, dynamic>>>[];
    final rest = <MapEntry<int, Map<String, dynamic>>>[];
    for (final entry in displayed) {
      (entry.value['isLongTerm'] == true ? longTerm : rest).add(entry);
    }
    return (longTerm: longTerm, rest: rest);
  }

  // -------------------------------------------------------------- list

  /// PLANE 1–2 — the task list in the section-33 list language.
  Widget _listPlane(BuildContext context, Color surface) {
    final bool notes = _list == WorkspaceList.notes;
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  12.verticalSpace,
                  // NOTES BESIDE TASKS — Ray 2026-09-18: "i cant do notes its
                  // only tasks and no seperate notes if need to be". The
                  // segment chooses which list THIS plane draws; everything
                  // below it belongs to the chosen list and nothing else on
                  // the workspace changes. Same control chip 827 uses for the
                  // sort, for the same reason: two values, both visible, the
                  // active one lit.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: WorkspaceListSegment(
                      active: _list,
                      counts: <WorkspaceList, int>{
                        WorkspaceList.tasks: _todos.length,
                        WorkspaceList.notes: _notes.length,
                      },
                      onChanged: _showList,
                    ),
                  ),
                  10.verticalSpace,
                  ...notes ? _noteListRows() : _taskListRows(context),
                ],
              ),
            ),
            // THE PLUS IS ON THE FLOATING NAV (Ray, 2026-09-20: "i think
            // productivity plus should be in the floating nav when you in
            // its page. floating nav already accept modes and buttons"). It
            // was a FloatingActionButton in Scaffold.floatingActionButton,
            // wrapped in a GestureDetector because a FAB has no long press;
            // it is now one round control on base_sdk's own bar, in the
            // leadingActions slot whose doc names this very case ("a tasks
            // app's 'new task'"). ONE plus per screen, so the FAB is gone
            // rather than duplicated — see ProductivityPlusNav, which owns
            // every decision about the bar so this page keeps none.
            //
            // STACKED OVER THE BODY, which is the bar's host contract and not
            // a preference: "Hosts place it in a Stack over the page body and
            // hand it a FloatingNavMode" (base_sdk floating_bottom_nav.dart),
            // and adaptive_bar.md §3 names the slot a host owes it — "a
            // full-size Stack slot (Positioned.fill, or the usual full-size
            // Align)". Scaffold.bottomNavigationBar is NOT that slot, and the
            // difference is mechanical, not stylistic: it reserves the pill's
            // height as a strip of body inset, which docks the bar in a lane
            // of its own where the housing is specified to float "with a
            // margin above the bottom edge, never docked flush", leaves the
            // frosted BlurWrap a flat background colour to blur instead of
            // the list it exists to sit over, and double-counts the keyboard
            // — Scaffold lifts the slot above the inset while the bar adds
            // MediaQuery.viewInsets.bottom itself. Inside the body the bar
            // reads that inset as zero, because Scaffold removes it from the
            // body it has already shrunk, so it is counted once.
            //
            // AND THE PILL DOES NOT MOVE. It brings its own SafeArea plus
            // 18.h; nested inside this SafeArea the inner one contributes
            // nothing, so the pill rests exactly where the bottom slot
            // rested it - the safe-area inset plus 18.h above the screen
            // edge. Both lists already clear 88.h below their last row and
            // the pill is 60.r of housing under that 18.h, so no padding
            // changes here either.
            //
            // A TAP STILL NEVER ASKS A QUESTION: it opens a new item of the
            // list this plane is drawing — a task on Tasks, a note on
            // Notes. The LONG PRESS is still Ray's shortcut to the other one
            // ("plus opens new but i think hlding it should give me option
            // like tasks notes"), carried across on
            // FloatingNavAction.onLongPress.
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ProductivityPlusNav(
                  list: _list,
                  onNew: notes ? _openNoteComposer : _openCompose,
                  onChooseList: _chooseNewItem,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The tasks half of the list plane — every control and the banded list
  /// the workspace shipped with, unchanged, now rows of the plane's column
  /// rather than the whole of it.
  List<Widget> _taskListRows(BuildContext context) {
    final displayedTodos = _getFilteredAndSortedTodos();
    final singlePlane = _isSinglePlane(context);
    return <Widget>[
      // CANONICAL 700 — header and count pill, carrying the two
      // header utilities: 832 calendar mode and 835 Backup.
      TaskListHeader(
        title: 'Tasks',
        count: displayedTodos.length,
        actions: [
          _headerAction(
            icon: _showCalendar ? Icons.list : Icons.calendar_month,
            tooltip: 'Calendar mode',
            onTap: () => setState(() => _showCalendar = !_showCalendar),
          ),
          // CHIP 835 — the only way a task leaves the device
          // (flag a). Kept in the header on every frame.
          _headerAction(
            icon: Icons.download,
            tooltip: 'Backup',
            onTap: _exportData,
          ),
        ],
      ),
      10.verticalSpace,
      _searchField(),
      10.verticalSpace,
      // CANONICAL 362 / 363 — the status tabs, re-dressing the
      // shipped ChoiceChip row.
      TaskStatusTabs(
        active: _statusFilter,
        counts: _statusCounts,
        onChanged: (filter) => setState(() {
          // The reader has spoken: the derived opening value above never
          // runs again this session.
          _filterTouched = true;
          _filterStatus = switch (filter) {
            TaskStatusFilter.pending => 'Pending',
            TaskStatusFilter.completed => 'Completed',
            TaskStatusFilter.all => 'All',
          };
        }),
      ),
      10.verticalSpace,
      Align(
        alignment: AlignmentDirectional.centerStart,
        // CHIP 827 — the sort segment. Promoted from the shipped
        // DropdownButton because there are only three values and
        // a dropdown hides two of them behind a tap.
        child: TaskSortSegment(
          active: _sort,
          onChanged: (sort) => setState(() {
            _sortBy = switch (sort) {
              TaskSort.deadline => 'Deadline',
              TaskSort.priority => 'Priority',
              TaskSort.created => 'Created',
            };
          }),
        ),
      ),
      12.verticalSpace,
      if (_showCalendar) ...[
        _calendar(),
        12.verticalSpace,
      ],
      Expanded(
        child: displayedTodos.isEmpty
            ? _emptyList()
            : Builder(
                builder: (context) {
                  // CHIP 1064 — the long-term band sits above
                  // the day's work; the rest keep their list.
                  final banded = _banded(displayedTodos);
                  final rows = <Widget>[
                    if (banded.longTerm.isNotEmpty) ...[
                      LongTermBandHeader(
                        count: banded.longTerm.length,
                      ),
                      for (final entry in banded.longTerm) ...[
                        _card(entry.key, entry.value, singlePlane),
                        8.verticalSpace,
                      ],
                      if (banded.rest.isNotEmpty) ...[
                        4.verticalSpace,
                        _bandLabel('EVERYTHING ELSE'),
                      ],
                    ],
                    for (var i = 0; i < banded.rest.length; i++) ...[
                      if (i > 0) 8.verticalSpace,
                      _card(
                        banded.rest[i].key,
                        banded.rest[i].value,
                        singlePlane,
                      ),
                    ],
                  ];
                  return ListView(
                    padding: EdgeInsets.only(bottom: 88.h),
                    children: rows,
                  );
                },
              ),
      ),
    ];
  }

  /// The notes half — the same list language with none of the task
  /// furniture: no status tabs (a note is not pending or completed), no
  /// sort segment (newest change first is the only order a note list
  /// wants) and no calendar (a note has no date to fall on).
  List<Widget> _noteListRows() {
    return <Widget>[
      TaskListHeader(
        title: WorkspaceListSegment.labelFor(WorkspaceList.notes),
        count: _notes.length,
      ),
      10.verticalSpace,
      Expanded(
        child: _notes.isEmpty
            ? _emptyNotes()
            : ListView.separated(
                padding: EdgeInsets.only(bottom: 88.h),
                itemCount: _notes.length,
                separatorBuilder: (context, _) => 8.verticalSpace,
                itemBuilder: (context, index) {
                  final NoteViewModel note =
                      NoteViewModel.fromMap(_notes[index]);
                  return NoteCard(
                    key: ValueKey<String>('note-card-${note.id}'),
                    note: note,
                    selected: _editingNoteId == note.id,
                    onTap: () => _startEditingNote(_notes[index]),
                    onDelete: () => _deleteNote(note.id),
                  );
                },
              ),
      ),
    ];
  }

  Widget _emptyNotes() {
    return Center(
      child: Text(
        'No notes yet.',
        style: AppStyle.interNormal(size: 13, color: AppStyle.textDarkFaint),
      ),
    );
  }

  /// One card of the list, with everything sections 44, 46 and 47 hang
  /// on it. [originalIndex] is the task's index in `_todos`.
  Widget _card(int originalIndex, Map<String, dynamic> todo, bool singlePlane) {
    final task = TaskViewModel.fromMap(todo);
    final String clientId = (todo['clientId'] ?? '').toString();
    return TaskCard(
      // One key per task, so the guided tour (and any test) can reach a
      // particular card and its run pill without depending on list order.
      key: ValueKey<String>('task-card-${task.id}'),
      task: task,
      selected: _editingId == task.id || _runningId == task.id,
      // CHIP 859 — the run pill, for a task with steps that is not done.
      onRun: task.hasSubtasks && !task.isDone
          ? () => _openRun(originalIndex)
          : null,
      runLabel: _runLabelFor(task),
      // CHIPS 1066 / 1067 / 1068 — where the task stands with the server.
      syncState: clientId.isEmpty
          ? TaskSyncState.thisDevice
          : _syncStates[clientId] ?? TaskSyncState.thisDevice,
      // CHIP 1060 — snooze, on the expanded card at the fold.
      onSnooze: task.hasReminder && !task.isDone
          ? () => _snooze(originalIndex)
          : null,
      // FRAME 44d: on one plane the card expands in place instead of
      // pushing a pane.
      expanded: singlePlane && _expandedId == task.id,
      // THE PHONE FOLD'S WAY INTO THE TASK FORM — Ray: "tasks saved cant be
      // edited". On a wide window the tap below opens the form in the detail
      // plane; on one plane that tap expands the card instead (frame 44d),
      // which left the form with no gesture at all and a saved task
      // unchangeable on a phone. The expanded card carries the door.
      onEdit: singlePlane ? () => _startEditing(originalIndex) : null,
      onToggleDone: () => _toggleTodo(originalIndex),
      onTap: () => singlePlane
          ? setState(
              () => _expandedId = _expandedId == task.id ? null : task.id,
            )
          : _startEditing(originalIndex),
      onToggleSubtask: (i) => _toggleSubtaskStatus(originalIndex, i),
    );
  }

  Widget _bandLabel(String label) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text(
          label,
          style: AppStyle.interNormal(
            size: 11,
            color: AppStyle.textDarkFaint,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      iconSize: 20.r,
      color: AppStyle.textDarkSecondary,
      icon: Icon(icon),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      style: AppStyle.interNormal(size: 13, color: AppStyle.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search tasks or categories...',
        hintStyle:
            AppStyle.interNormal(size: 13, color: AppStyle.textDarkFaint),
        prefixIcon: Icon(Icons.search, size: 18.r),
        filled: true,
        fillColor: AppStyle.cardDarkAlt,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _emptyList() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nothing here yet.',
            style:
                AppStyle.interNormal(size: 13, color: AppStyle.textDarkFaint),
          ),
          // The one line about a failed pull. `_todos`, not the filtered
          // view: a filter that hides every row is not an empty list, and
          // the notice draws nothing unless the LOCAL list is empty AND
          // the last pull failed.
          TaskSyncNotice(
            localListEmpty: _todos.isEmpty,
            lastPullFailed: _syncFailed,
          ),
        ],
      ),
    );
  }

  /// FRAME 44e — calendar mode, a MODE OF THE LIST PLANE rather than a
  /// screen of its own, re-dressed in base tokens: today ringed in
  /// primary, the selected day filled primary, and a primary dot under
  /// any day a local task's `deadline` lands on.
  ///
  /// THE DAY DOT IS A REAL MARKER — derived from local rows and nothing
  /// more. Flag (a) is unchanged by the mode: the days being marked are
  /// local rows.
  Widget _calendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selected, focused) => setState(() {
        _selectedDay = isSameDay(_selectedDay, selected) ? null : selected;
        _focusedDay = focused;
      }),
      eventLoader: (day) => _todos.where((t) {
        final deadline = t['deadline'] as String?;
        if (deadline == null) return false;
        final parsed = DateTime.tryParse(deadline);
        return parsed != null && isSameDay(parsed, day);
      }).toList(),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle:
            AppStyle.interSemi(size: 14, color: AppStyle.textPrimary),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppStyle.interNormal(
          size: 11,
          color: AppStyle.textDarkFaint,
        ),
        weekendStyle: AppStyle.interNormal(
          size: 11,
          color: AppStyle.textDarkFaint,
        ),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle:
            AppStyle.interNormal(size: 12, color: AppStyle.textPrimary),
        weekendTextStyle:
            AppStyle.interNormal(size: 12, color: AppStyle.textPrimary),
        outsideTextStyle:
            AppStyle.interNormal(size: 12, color: AppStyle.textDarkFaint),
        todayDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppStyle.primary),
        ),
        todayTextStyle:
            AppStyle.interSemi(size: 12, color: AppStyle.textPrimary),
        selectedDecoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppStyle.primary,
        ),
        selectedTextStyle:
            AppStyle.interSemi(size: 12, color: AppStyle.blackColor),
        markerDecoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppStyle.primary,
        ),
        markersMaxCount: 1,
      ),
    );
  }

  // ----------------------------------------------------- compose plane

  /// PLANE 3 (the LAST plane) — frame 44b's compose lane and frame 44a's
  /// detail pane, which are ONE component with an empty model.
  ///
  /// GIVING IT THE LAST PLANE IS THE WHOLE CHANGE. The shipped page
  /// built all of this as an inline form wedged ABOVE the list; here the
  /// list keeps its planes and stays legible while you type.
  Widget _composePane(BuildContext context, Color surface) {
    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        // BACK-PILL CLEARANCE (tour run 34040758271, still 10, phone and
        // tablet): PlaneHost floats the corner pill (347) over THIS
        // plane's foot, and the form scrolled under it — the Long term
        // switch on the phone, Save task on the tablet, sat under the
        // pill. The band is reserved OUTSIDE the list by the pill's own
        // figures (planeBackClearance), so the viewport ends above the
        // pill at every scroll offset; padding inside the list only ever
        // cleared it at the end of the scroll. The pill itself is neither
        // moved nor hidden.
        child: PlaneBackClearance(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ListView(
              padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _editingId == null ? 'New task' : 'Task',
                        style: AppStyle.interSemi(
                          size: 18,
                          color: AppStyle.textPrimary,
                        ),
                      ),
                    ),
                    // The only state the pane adds.
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppStyle.strokeDark),
                      ),
                      child: Text(
                        'unsaved',
                        style: AppStyle.interNormal(
                          size: 11,
                          color: AppStyle.textDarkFaint,
                        ),
                      ),
                    ),
                  ],
                ),
                14.verticalSpace,
                // SECTION 47 — "From template": the RO plant's service
                // runs, offered on a new task only. Picking one fills THIS
                // form; nothing is saved until Save task, as ever.
                if (_editingId == null) ...[
                  _templateChooser(),
                  14.verticalSpace,
                ],
                _fieldLabel('TITLE'),
                _textField(_controller, 'What needs doing?'),
                14.verticalSpace,
                _fieldLabel('PRIORITY'),
                _priorityTriple(),
                14.verticalSpace,
                _fieldLabel('DEADLINE'),
                _deadlineRow(),
                6.verticalSpace,
                // SECTION 47m, SECOND PASS — where the Long term switch
                // used to be, one derived line reading back what the
                // deadline just decided.
                _longTermDerivedLine(),
                14.verticalSpace,
                _fieldLabel('CATEGORY'),
                _textField(_categoryController, 'Plant, admin, errand…'),
                14.verticalSpace,
                // FLAG (b) — drawn because the field is real; it is
                // flagged because nothing ever acts on it.
                _fieldLabel('REPEATS'),
                _recurrenceQuad(),
                14.verticalSpace,
                // FLAG (c) — a local notification at the deadline, and
                // nothing more. The sub-line says exactly that.
                _reminderToggle(),
                // CHIPS 1061 / 1060 — for a saved task with a reminder, the
                // two clocks and the snooze control, right under the toggle
                // that made the reminder.
                if (_editingId != null) ..._editingReminderRow(),
                14.verticalSpace,
                _fieldLabel('STEPS'),
                // Section 46: the order rule. Off is today's any-order
                // checklist; on, a run opens the steps one at a time.
                _stepsInOrderToggle(),
                8.verticalSpace,
                for (var i = 0; i < _currentSubtasks.length; i++)
                  SubtaskCheckLine(
                    subtask: SubtaskViewModel.fromMap(_currentSubtasks[i]),
                    onToggle: () => _toggleFormSubtaskStatus(i),
                    onRemove: () =>
                        setState(() => _currentSubtasks.removeAt(i)),
                  ),
                8.verticalSpace,
                _subtaskComposer(),
                14.verticalSpace,
                // CHIP 833 — the M2 link row: what objective of the plan
                // this task serves, and the door to the picker (834).
                _fieldLabel('OBJECTIVE'),
                ObjectiveLinkRow(
                  task: _composedTask,
                  onTap: _openObjectivePicker,
                  onClear: _strategicObjective == null
                      ? null
                      : () => _applyObjectiveLink(null),
                ),
                20.verticalSpace,
                _paneActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text(
          label,
          style: AppStyle.interNormal(
            size: 11,
            color: AppStyle.textDarkFaint,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _textField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: AppStyle.interNormal(size: 13, color: AppStyle.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            AppStyle.interNormal(size: 13, color: AppStyle.textDarkFaint),
        filled: true,
        fillColor: AppStyle.cardDarkAlt,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// The shipped `_priorities` triple.
  Widget _priorityTriple() {
    return Row(
      children: [
        for (final priority in _priorities) ...[
          _pill(
            label: priority,
            selected: _selectedPriority == priority,
            tint: taskPriorityColor(priority),
            onTap: () => setState(() => _selectedPriority = priority),
          ),
          if (priority != _priorities.last) 8.horizontalSpace,
        ],
      ],
    );
  }

  /// The shipped `_recurrences` quad as a pill switcher.
  Widget _recurrenceQuad() {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final recurrence in _recurrences)
          _pill(
            label: recurrence,
            selected: _recurrence == recurrence,
            onTap: () => setState(() => _recurrence = recurrence),
          ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? tint,
  }) {
    final color = tint ?? AppStyle.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.16) : AppStyle.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? color : AppStyle.strokeDarkSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppStyle.interSemi(
            size: 12,
            color: selected ? color : AppStyle.textDarkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _deadlineRow() {
    final deadline = _selectedDeadline;
    return GestureDetector(
      onTap: _pickDeadline,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppStyle.cardDarkAlt,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 16.r, color: AppStyle.textDarkFaint),
            8.horizontalSpace,
            Expanded(
              child: Text(
                deadline == null
                    ? 'No deadline'
                    : kTaskDeadlineFormat.format(deadline),
                style: AppStyle.interNormal(
                  size: 13,
                  color: deadline == null
                      ? AppStyle.textDarkFaint
                      : AppStyle.textPrimary,
                ),
              ),
            ),
            if (deadline != null)
              GestureDetector(
                onTap: () => setState(() => _selectedDeadline = null),
                child: Icon(
                  Icons.close,
                  size: 15.r,
                  color: AppStyle.textDarkFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// FLAG (c) — the sub-line is the honest half of this control.
  Widget _reminderToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Remind me',
                style: AppStyle.interSemi(
                  size: 13,
                  color: AppStyle.textPrimary,
                ),
              ),
              2.verticalSpace,
              Text(
                'a local notification at the deadline',
                style: AppStyle.interNormal(
                  size: 11,
                  color: AppStyle.textDarkFaint,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _isReminderSet,
          activeThumbColor: AppStyle.primary,
          onChanged: (value) => setState(() => _isReminderSet = value),
        ),
      ],
    );
  }

  /// Section 46 — the order rule, drawn as the toggle it is.
  Widget _stepsInOrderToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Steps in order',
                style: AppStyle.interSemi(
                  size: 13,
                  color: AppStyle.textPrimary,
                ),
              ),
              2.verticalSpace,
              Text(
                _stepsInOrder
                    ? 'a run opens them one at a time; the next unlocks when the one before is done'
                    : 'a checklist — tick them in any order',
                style: AppStyle.interNormal(
                  size: 11,
                  color: AppStyle.textDarkFaint,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _stepsInOrder,
          activeThumbColor: AppStyle.primary,
          onChanged: (value) => setState(() => _stepsInOrder = value),
        ),
      ],
    );
  }

  /// The two-clock row for the task being edited, when it has a reminder.
  List<Widget> _editingReminderRow() {
    final int index = _todos.indexWhere((t) => t['id'] == _editingId);
    if (index == -1) return const <Widget>[];
    final TaskViewModel task = TaskViewModel.fromMap(_todos[index]);
    if (!task.hasReminder) return const <Widget>[];
    return <Widget>[
      10.verticalSpace,
      TaskReminderRow(
        task: task,
        onSnooze: task.isDone ? null : () => _snooze(index),
      ),
    ];
  }

  /// CHIP 1064, SECOND PASS — the band, READ BACK rather than chosen.
  ///
  /// Frame 47m shipped this as a switch and said so: "set by hand ...
  /// nothing derives it". Ray, on the launcher: "long term task is
  /// selected not automatically detected from end date". So the control
  /// is gone and this line takes its place — a statement of what the
  /// deadline above already decided, with no tap of its own. A form that
  /// kept the switch beside the rule would let the two disagree, and the
  /// switch would win until the next save overwrote it.
  Widget _longTermDerivedLine() {
    final bool derived = LongTermRule.isLongTerm(
      endDate: _selectedDeadline,
      createdAt: _composedCreatedAt,
    );
    final Color tint =
        derived ? LongTermBandHeader.tint : AppStyle.textDarkFaint;
    return Row(
      children: [
        Icon(
          derived ? Icons.event_repeat : Icons.today,
          size: 14.r,
          color: tint,
        ),
        6.horizontalSpace,
        Expanded(
          child: Text(
            derived
                ? 'Long term — the deadline is more than '
                    '${LongTermRule.horizonDays} days out, so this sits in '
                    'the band above the day\'s work'
                : _selectedDeadline == null
                    ? 'No deadline, so not long term — set one more than '
                        '${LongTermRule.horizonDays} days out for the '
                        'long-term band'
                    : 'Part of the day\'s work — a deadline more than '
                        '${LongTermRule.horizonDays} days out moves it to '
                        'the long-term band',
            style: AppStyle.interNormal(size: 11, color: tint),
          ),
        ),
      ],
    );
  }

  /// The start the long-term rule measures the composed task's deadline
  /// against: the task's own creation while editing, else now.
  DateTime get _composedCreatedAt {
    final int index = _todos.indexWhere((t) => t['id'] == _editingId);
    if (index == -1) return DateTime.now();
    return DateTime.tryParse('${_todos[index]['createdAt'] ?? ''}') ??
        DateTime.now();
  }

  // ===================================================================
  // DESIGN STRIP SECTION 47 — the RO plant's service runs as ORDINARY
  // TASKS (frames 47a–47d, 47h, 47i; Ray 2026-08-31: "maintenance is
  // just a normal multi step task with reminder, no privilege"). The
  // compose lane gains ONE row: "From template", which fills this same
  // form with a template's title, steps, deadline, reminder and
  // recurrence, so the task is saved, listed, run and reminded of
  // exactly as any other. No hub row, no dashboard, no plane of its own.
  //
  // FRAME 47d's gate: the plant has to be described before it can be
  // serviced. Until the setup run has been finished on this device the
  // service templates are drawn but not live — present and dimmed, never
  // hidden — and the one line under them says why.
  // ===================================================================

  /// Frame 47d's record, read on each build: null until the setup run has
  /// been finished on this device.
  PlantRecord? get _plant => MaintenancePlantStore.local.current();

  /// The words on a template's chip. Keys, not English: the composed
  /// app's TrKeys carries them from this SDK's manifest.
  String _templateLabel(MaintenanceTemplate template) =>
      AppHelpers.getTranslation(switch (template) {
        MaintenanceTemplate.plantSetup => TrKeys.plantSetup,
        MaintenanceTemplate.softenerMaintenance => TrKeys.softenerMaintenance,
        MaintenanceTemplate.megaCharMaintenance => TrKeys.megacharMaintenance,
        MaintenanceTemplate.preFilterReplacement => TrKeys.preFilterReplacement,
        MaintenanceTemplate.roFilterReplacement => TrKeys.roFilterReplacement,
        MaintenanceTemplate.membraneReplacement => TrKeys.roMembraneReplacement,
      });

  Widget _templateChooser() {
    final PlantRecord? plant = _plant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(
          AppHelpers.getTranslation(TrKeys.fromTemplate).toUpperCase(),
        ),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final MaintenanceTemplate template in MaintenanceTemplates.all)
              _templateChip(
                template,
                offered: MaintenanceTemplates.isOffered(template, plant),
              ),
          ],
        ),
        if (plant == null) ...[
          6.verticalSpace,
          Text(
            AppHelpers.getTranslation(TrKeys.describeThePlantFirst),
            style: AppStyle.interNormal(
              size: 11,
              color: AppStyle.textDarkFaint,
            ),
          ),
        ],
      ],
    );
  }

  Widget _templateChip(MaintenanceTemplate template, {required bool offered}) {
    final bool selected = _templateKey == template.key;
    return InkWell(
      key: ValueKey<String>('template-${template.key}'),
      onTap: offered ? () => _applyTemplate(template) : null,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: selected ? AppStyle.primary : AppStyle.cardDarkAlt,
          border: Border.all(
            color: selected ? AppStyle.primary : AppStyle.strokeDark,
          ),
        ),
        child: Text(
          _templateLabel(template),
          style: AppStyle.interNormal(
            size: 12,
            color: selected
                ? AppStyle.blackColor
                : offered
                    ? AppStyle.textPrimary
                    : AppStyle.textDarkFaint,
          ),
        ),
      ),
    );
  }

  /// Fill the form from [template]. Everything the template sets is a
  /// field the form already has, so the operator can change any of it
  /// before saving — a 20-minute rinse is a number on a step.
  void _applyTemplate(MaintenanceTemplate template) {
    final Map<String, dynamic> task = MaintenanceTemplates.build(
      template,
      now: DateTime.now(),
      plant: _plant,
    );
    setState(() {
      _templateKey = template.key;
      _controller.text = '${task['title'] ?? ''}';
      _stepsInOrder = task['stepsAreSequential'] == true;
      _recurrence = '${task['recurrence'] ?? 'None'}';
      _isReminderSet = task['reminder'] == true;
      _selectedDeadline = task['deadline'] == null
          ? null
          : DateTime.tryParse('${task['deadline']}');
      _currentSubtasks = List<Map<String, dynamic>>.from(
        (task['subtasks'] as List? ?? const [])
            .map((s) => Map<String, dynamic>.from(s as Map)),
      );
    });
  }

  /// CHIP 831 — dashed means nothing committed yet. Section 46 gave the
  /// composer two more fields: what to do on the step, and how long it
  /// takes (minutes; blank or 0 is an untimed step with no clock).
  Widget _subtaskComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _composerField(
          _subtaskController,
          'Name the step, then add it',
          onSubmitted: (_) => _addSubtask(),
        ),
        6.verticalSpace,
        _composerField(
          _subtaskInstructionController,
          'What to do on this step (optional)',
        ),
        6.verticalSpace,
        Row(
          children: [
            SizedBox(
              width: 110.w,
              child: _composerField(
                _subtaskMinutesController,
                'Minutes',
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _addSubtask(),
              ),
            ),
            8.horizontalSpace,
            Expanded(
              child: Text(
                'blank or 0 = no clock, just a confirmation',
                style: AppStyle.interNormal(
                  size: 11,
                  color: AppStyle.textDarkFaint,
                ),
              ),
            ),
          ],
        ),
        8.verticalSpace,
        SubtaskComposerRow(
          label: _editingId == null ? 'Add a step' : 'Add a subtask',
          onTap: _addSubtask,
        ),
      ],
    );
  }

  Widget _composerField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      style: AppStyle.interNormal(size: 12, color: AppStyle.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            AppStyle.interNormal(size: 12, color: AppStyle.textDarkFaint),
        filled: true,
        fillColor: AppStyle.cardDarkAlt,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Delete / Save task at 1 : 1.5, per frame 44a.
  Widget _paneActions() {
    return Row(
      children: [
        if (_editingId != null) ...[
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () {
                final index = _todos.indexWhere((t) => t['id'] == _editingId);
                if (index != -1) _removeTodo(index);
                _closePane();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, 44.h),
                side: BorderSide(color: AppStyle.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'Delete',
                style: AppStyle.interSemi(size: 13, color: AppStyle.red),
              ),
            ),
          ),
          10.horizontalSpace,
        ],
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: () {
              _saveTask();
              _closePane();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.primary,
              foregroundColor: AppStyle.blackColor,
              minimumSize: Size(0, 44.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'Save task',
              style: AppStyle.interSemi(size: 13, color: AppStyle.blackColor),
            ),
          ),
        ),
      ],
    );
  }
}
