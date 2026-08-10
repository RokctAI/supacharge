// ==========================================
// [GENERATED TEMPLATE FILE]
// This file was installed from: productivity_sdk
// Feel free to modify and customize this code.
// Note: If you edit this file, the SDK installer will detect your changes
// and automatically skip overwriting it during future upgrades.
// ==========================================

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:comms_sdk/comms_sdk.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:base_sdk/base_sdk.dart';
import 'package:productivity_sdk/productivity_sdk.dart';
import 'package:auto_route/auto_route.dart';
import 'dart:math';

@RoutePage()
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  late final TodoRepositoryFacade _repository;

  List<Map<String, dynamic>> _todos = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  DateTime? _selectedDeadline;
  bool _isReminderSet = false;
  String _selectedPriority = 'Medium';
  String _filterStatus = 'All'; // All, Pending, Completed
  String _sortBy = 'Created'; // Created, Deadline, Priority
  String _recurrence = 'None'; // None, Daily, Weekly, Monthly
  bool _showCalendar = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String? _editingId;

  String? _selectedCategory;
  List<Map<String, dynamic>> _currentSubtasks = [];

  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _recurrences = ['None', 'Daily', 'Weekly', 'Monthly'];
  final List<String> _sortOptions = ['Created', 'Deadline', 'Priority'];
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _repository = TodoRepositoryImpl(AppDatabase());
    _selectedDay = _focusedDay;
    _initNotifications();
    _loadTodos();
  }

  Future<void> _initNotifications() async {
    await LocalNotifications.initialize();
  }

  Future<void> _loadTodos() async {
    final todos = await _repository.loadTodos();
    if (mounted) {
      setState(() {
        _todos = todos;
      });
    }
  }

  Future<void> _saveTodos() async {
    await _repository.saveTodos(_todos);
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

          LocalNotifications.cancelNotification(notifId);

          _todos[index] = {
            'id': id,
            'notifId': notifId,
            'title': title,
            'isDone': _todos[index]['isDone'],
            'deadline': deadlineStr,
            'reminder': _isReminderSet,
            'priority': _selectedPriority,
            'category': category,
            'recurrence': _recurrence,
            'createdAt':
                _todos[index]['createdAt'] ?? DateTime.now().toIso8601String(),
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
          'createdAt': DateTime.now().toIso8601String(),
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
      _selectedDeadline = null;
      _isReminderSet = false;
      _selectedPriority = 'Medium';
      _recurrence = 'None';
      _selectedCategory = null;
      _currentSubtasks = [];
    });
    _saveTodos();
  }

  void _addSubtask() {
    if (_subtaskController.text.trim().isNotEmpty) {
      setState(() {
        _currentSubtasks.add({
          'title': _subtaskController.text.trim(),
          'isDone': false,
        });
        _subtaskController.clear();
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
      _controller.text = task['title'];
      _selectedPriority = task['priority'] ?? 'Medium';
      _isReminderSet = task['reminder'] ?? false;
      _recurrence = task['recurrence'] ?? 'None';
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
      _selectedDeadline = null;
      _isReminderSet = false;
      _selectedPriority = 'Medium';
      _recurrence = 'None';
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
      'createdAt': DateTime.now().toIso8601String(),
      'subtasks': (task['subtasks'] as List?)?.map((s) {
            final copy = Map<String, dynamic>.from(s);
            copy['isDone'] = false;
            return copy;
          }).toList() ??
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

    setState(() {
      _todos.removeAt(index);
    });
    _saveTodos();
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayedTodos = _getFilteredAndSortedTodos();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tasks & Productivity Manager',
          style: TextStyle(color: colors.onSurface, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.list : Icons.calendar_month),
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'Backup Data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Controls (Search, Filters, Sorting)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tasks or categories...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withOpacity(0.5),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                8.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: ['All', 'Pending', 'Completed'].map((status) {
                        return Padding(
                          padding: EdgeInsets.only(right: 4.w),
                          child: ChoiceChip(
                            label: Text(
                              status,
                              style: TextStyle(fontSize: 12.sp),
                            ),
                            selected: _filterStatus == status,
                            onSelected: (selected) {
                              setState(() => _filterStatus = status);
                            },
                            padding: EdgeInsets.zero,
                          ),
                        );
                      }).toList(),
                    ),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      icon: Icon(Icons.sort, size: 16.r),
                      items: _sortOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            'Sort: $value',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => _sortBy = newValue);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_showCalendar)
            TableCalendar(
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarFormat: CalendarFormat.week,
            ),

          // Form Area
          Container(
            padding: EdgeInsets.all(16.r),
            color: colors.surfaceContainerHighest.withOpacity(0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: _editingId != null
                              ? 'Edit task title'
                              : 'Add a new task',
                          hintStyle: TextStyle(
                            color: colors.onSurface.withOpacity(0.5),
                          ),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                      ),
                    ),
                    8.horizontalSpace,
                    IconButton(
                      icon: Icon(
                        _editingId != null
                            ? Icons.check_circle
                            : Icons.add_circle,
                        color: colors.primary,
                        size: 40.r,
                      ),
                      onPressed: _saveTask,
                    ),
                  ],
                ),
                8.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          hintText: 'Category',
                          hintStyle: TextStyle(
                            color: colors.onSurface.withOpacity(0.5),
                            fontSize: 13.sp,
                          ),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    8.horizontalSpace,
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _recurrence,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                        ),
                        items: _recurrences
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: TextStyle(fontSize: 13.sp),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _recurrence = val);
                        },
                      ),
                    ),
                  ],
                ),
                8.verticalSpace,
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subtaskController,
                        decoration: InputDecoration(
                          hintText: 'Add a subtask...',
                          hintStyle: TextStyle(
                            color: colors.onSurface.withOpacity(0.5),
                            fontSize: 13.sp,
                          ),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _addSubtask(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, size: 24.r, color: colors.primary),
                      onPressed: _addSubtask,
                    ),
                  ],
                ),
                if (_currentSubtasks.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 4.h),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colors.outline.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: _currentSubtasks.asMap().entries.map((entry) {
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: entry.value['isDone'] ?? false,
                          onChanged: (val) =>
                              _toggleFormSubtaskStatus(entry.key),
                          title: Text(
                            entry.value['title'],
                            style: TextStyle(fontSize: 13.sp),
                          ),
                          secondary: IconButton(
                            icon: Icon(Icons.close, size: 16.r),
                            onPressed: () {
                              setState(() {
                                _currentSubtasks.removeAt(entry.key);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                8.verticalSpace,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: _selectedPriority,
                      underline: const SizedBox(),
                      icon: Icon(
                        Icons.flag,
                        size: 18.r,
                        color: _getPriorityColor(_selectedPriority, colors),
                      ),
                      items: _priorities.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: TextStyle(fontSize: 13.sp)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedPriority = newValue;
                          });
                        }
                      },
                    ),
                    TextButton.icon(
                      onPressed: _pickDeadline,
                      icon: Icon(Icons.calendar_today, size: 16.r),
                      label: Text(
                        _selectedDeadline == null
                            ? 'Deadline'
                            : DateFormat(
                                'MMM dd, hh:mm a',
                              ).format(_selectedDeadline!),
                        style: TextStyle(fontSize: 13.sp),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.notifications, size: 16.r),
                        Switch(
                          value: _isReminderSet,
                          onChanged: (val) {
                            setState(() {
                              _isReminderSet = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (_editingId != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _cancelEditing,
                      child: Text(
                        'Cancel Edit',
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: displayedTodos.length,
              itemBuilder: (context, index) {
                final originalIndex = displayedTodos[index].key;
                final todo = displayedTodos[index].value;

                final bool isDone = todo['isDone'] ?? false;
                final String title = todo['title'];
                final String? deadlineStr = todo['deadline'];
                final bool hasReminder = todo['reminder'] ?? false;
                final String priority = todo['priority'] ?? 'Medium';
                final String? category = todo['category'];
                final String recurrence = todo['recurrence'] ?? 'None';
                final List<Map<String, dynamic>> subtasks =
                    List<Map<String, dynamic>>.from(todo['subtasks'] ?? []);

                String? formattedDeadline;
                if (deadlineStr != null) {
                  final DateTime deadlineDate = DateTime.parse(deadlineStr);
                  formattedDeadline = DateFormat(
                    'MMM dd, hh:mm a',
                  ).format(deadlineDate);
                }

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: colors.outline.withOpacity(0.1)),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Checkbox(
                        value: isDone,
                        activeColor: colors.primary,
                        onChanged: (bool? value) {
                          _toggleTodo(originalIndex);
                        },
                      ),
                      title: InkWell(
                        onTap: () => _startEditing(originalIndex),
                        child: Text(
                          title,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w500,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          4.verticalSpace,
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8.w,
                            runSpacing: 4.h,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag,
                                    size: 14.r,
                                    color: _getPriorityColor(priority, colors),
                                  ),
                                  4.horizontalSpace,
                                  Text(
                                    priority,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: _getPriorityColor(
                                        priority,
                                        colors,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (category != null && category.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: colors.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              if (recurrence != 'None')
                                Icon(
                                  Icons.repeat,
                                  size: 14.r,
                                  color: colors.tertiary,
                                ),
                              if (formattedDeadline != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 14.r,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    4.horizontalSpace,
                                    Text(
                                      formattedDeadline,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              if (hasReminder && formattedDeadline != null)
                                Icon(
                                  Icons.notifications_active,
                                  size: 14.r,
                                  color: colors.primary,
                                ),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: colors.error),
                        onPressed: () => _removeTodo(originalIndex),
                      ),
                      children: subtasks.isEmpty
                          ? []
                          : [
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 32.w,
                                  right: 16.w,
                                  bottom: 8.h,
                                ),
                                child: Column(
                                  children: subtasks.asMap().entries.map((st) {
                                    return CheckboxListTile(
                                      dense: true,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      value: st.value['isDone'] ?? false,
                                      onChanged: (val) {
                                        _toggleSubtaskStatus(
                                          originalIndex,
                                          st.key,
                                        );
                                      },
                                      title: Text(
                                        st.value['title'],
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          decoration: st.value['isDone'] == true
                                              ? TextDecoration.lineThrough
                                              : null,
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
          ),
        ],
      ),
    );
  }
}
