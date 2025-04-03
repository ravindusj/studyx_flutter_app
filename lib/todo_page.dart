import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'services/notification_service.dart';
import 'services/todo_notification_service.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({Key? key}) : super(key: key);

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  User? _currentUser;
  DateTime? _selectedDate;
  String _filterOption = 'All';
  int _priority = 0;
  String? _loadingTaskId;
  Set<String> _updatingTasks = {};
  bool _isListLoading = true;
  final NotificationService _notificationService = NotificationService();
  final TodoNotificationService _todoNotificationService = TodoNotificationService();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _initializeNotifications();
    if (_currentUser != null) {
      print("User authenticated: ${_currentUser!.uid}");
    } else {
      print("ERROR: No user authenticated!");
    }
    Future.delayed(const Duration(seconds: 1), _verifyDatabasePath);
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    await _todoNotificationService.initialize();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  CollectionReference get _todosRef =>
      FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid).collection('todos');

  Future<void> _addTodo() async {
    if (_textController.text.trim().isEmpty) return;
    final bool? result = await _showTaskDetailsDialog();
    if (result != true) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a due date before adding a task'),
          backgroundColor: Color.fromARGB(255, 185, 31, 20),
        ),
      );
      return;
    }
    final bool confirmed = await _showConfirmDialog(
      title: 'Add Task',
      content: 'Are you sure you want to add this task?',
      confirmText: 'Add',
    );
    if (!confirmed) return;
    setState(() => _isLoading = true);
    try {
      if (_currentUser == null) {
        throw Exception("User not authenticated");
      }
      final todoData = {
        'title': _textController.text.trim(),
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'dueDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'priority': _priority,
        'userId': _currentUser!.uid,
      };
      final docRef = await _todosRef.add(todoData);
      if (_selectedDate != null) {
        await _todoNotificationService.scheduleAllTodoNotifications();
      }
      _textController.clear();
      setState(() {
        _selectedDate = null;
        _priority = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showTaskDetailsDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task: ${_textController.text}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Text('Select due date:', style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Select date'
                                  : DateFormat('MMM d, y').format(_selectedDate!),
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                            InkWell(
                              onTap: () => setState(() => _selectedDate = null),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Select priority:', style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _priority = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _priority == 0
                                  ? (isDarkMode ? Colors.grey[700] : Colors.grey[200])
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Normal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _priority = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _priority == 1
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _priority == 1 ? Colors.orange : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.flag,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Medium',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _priority = 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _priority == 2
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _priority == 2 ? Colors.red : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.flag,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'High',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Proceed'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _verifyDatabasePath() {
    if (_currentUser == null) {
      print("ERROR: Current user is null. Not authenticated.");
      return;
    }
    final path = "users/${_currentUser!.uid}/todos";
    print("Database path: $path");
    FirebaseFirestore.instance.collection(path).limit(1).get().then((snapshot) {
      print("Collection access successful. Contains ${snapshot.docs.length} documents.");
    }).catchError((error) {
      print("Error accessing collection: $error");
    });
  }

  Future<void> _toggleTodoStatus(String id, bool currentStatus) async {
    if (_updatingTasks.contains(id)) return;
    setState(() {
      _updatingTasks.add(id);
    });
    try {
      await _todosRef.doc(id).update({'completed': !currentStatus});
      if (!currentStatus) {
        await _todoNotificationService.scheduleAllTodoNotifications();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingTasks.remove(id);
        });
      }
    }
  }

  Future<void> _deleteTodo(String id) async {
    final bool confirmed = await _showConfirmDialog(
      title: 'Delete Task',
      content: 'Are you sure you want to delete this task?',
      confirmText: 'Delete',
    );
    if (!confirmed) return;
    setState(() {
      _loadingTaskId = id;
    });
    try {
      await _todosRef.doc(id).delete();
      await _todoNotificationService.scheduleAllTodoNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingTaskId = null;
        });
      }
    }
  }

  Future<void> _updateDueDate(String id, DateTime? newDate) async {
    if (_updatingTasks.contains(id)) return;
    setState(() {
      _updatingTasks.add(id);
    });
    try {
      await _todosRef.doc(id).update({
        'dueDate': newDate != null ? Timestamp.fromDate(newDate) : null,
      });
      await _todoNotificationService.scheduleAllTodoNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingTasks.remove(id);
        });
      }
    }
  }

  Future<void> _updatePriority(String id, int priority) async {
    if (_updatingTasks.contains(id)) return;
    setState(() {
      _updatingTasks.add(id);
    });
    try {
      await _todosRef.doc(id).update({'priority': priority});
      await _todoNotificationService.scheduleAllTodoNotifications();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingTasks.remove(id);
        });
      }
    }
  }

  Future<void> _editTaskDetails(String id, String title, DateTime? currentDueDate, int currentPriority) async {
    DateTime? tempSelectedDate = currentDueDate;
    int tempPriority = currentPriority;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Task Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task: $title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text('Change due date:', style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: tempSelectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) {
                        setState(() {
                          tempSelectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tempSelectedDate == null
                                  ? 'Select date'
                                  : DateFormat('MMM d, y').format(tempSelectedDate!),
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                          if (tempSelectedDate != null)
                            InkWell(
                              onTap: () => setState(() => tempSelectedDate = null),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Change priority:', style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => tempPriority = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: tempPriority == 0
                                  ? (isDarkMode ? Colors.grey[700] : Colors.grey[200])
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Normal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => tempPriority = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: tempPriority == 1
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tempPriority == 1 ? Colors.orange : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.flag,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Medium',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => tempPriority = 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: tempPriority == 2
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: tempPriority == 2 ? Colors.red : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.flag,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'High',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == true) {
      if (tempSelectedDate != currentDueDate) {
        await _updateDueDate(id, tempSelectedDate);
      }
      if (tempPriority != currentPriority) {
        await _updatePriority(id, tempPriority);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Query<Object?> _getFilteredQuery() {
    Query query = _todosRef.orderBy('priority', descending: true);
    switch (_filterOption) {
      case 'Today':
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
        return query
            .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      case 'Upcoming':
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final startOfTomorrow = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
        return query.where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfTomorrow));
      case 'Overdue':
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        return query
            .where('dueDate', isLessThan: Timestamp.fromDate(startOfDay))
            .where('completed', isEqualTo: false);
      case 'Completed':
        return query.where('completed', isEqualTo: true);
      default:
        return query.orderBy('createdAt', descending: true);
    }
  }

  Color _getPriorityColor(int priority, bool isDarkMode) {
    switch (priority) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.red;
      default:
        return isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
    }
  }

  String _getPriorityText(int priority) {
    switch (priority) {
      case 1:
        return 'Medium';
      case 2:
        return 'High';
      default:
        return 'Normal';
    }
  }

  Widget _getFilterIcon(String filter, bool isDarkMode) {
    switch (filter) {
      case 'Today':
        return Icon(
          Icons.today,
          size: 16,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        );
      case 'Upcoming':
        return Icon(
          Icons.calendar_month,
          size: 16,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        );
      case 'Overdue':
        return const Icon(
          Icons.warning_amber,
          size: 16,
          color: Colors.red,
        );
      case 'Completed':
        return const Icon(
          Icons.task_alt,
          size: 16,
          color: Colors.green,
        );
      default:
        return Icon(
          Icons.list_alt,
          size: 16,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;

    if (_currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text('You need to be signed in to view your tasks.'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please sign in to continue')),
                );
              },
              child: Text('Sign In'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800.withOpacity(0.3) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? accentColor : primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: _isLoading
                        ? LoadingAnimationWidget.stretchedDots(
                            color: isDarkMode ? primaryColor : Colors.white,
                            size: 24,
                          )
                        : Icon(
                            Icons.add,
                            color: isDarkMode ? primaryColor : Colors.white,
                          ),
                    onPressed: _isLoading ? null : _addTodo,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing: $_filterOption tasks',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _filterOption,
                  onSelected: (String value) {
                    setState(() {
                      _filterOption = value;
                    });
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'All',
                      child: Row(
                        children: [
                          Icon(Icons.list_alt, size: 18),
                          SizedBox(width: 8),
                          Text('All Tasks'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'Today',
                      child: Row(
                        children: [
                          Icon(Icons.today, size: 18),
                          SizedBox(width: 8),
                          Text('Due Today'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'Upcoming',
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, size: 18),
                          SizedBox(width: 8),
                          Text('Upcoming'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'Overdue',
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Overdue'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'Completed',
                      child: Row(
                        children: [
                          Icon(Icons.task_alt, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Completed'),
                        ],
                      ),
                    ),
                  ],
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  offset: const Offset(0, 4),
                  icon: Icon(
                    Icons.filter_alt,
                    size: 24,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _isListLoading = true;
                });
                await Future.delayed(const Duration(milliseconds: 500));
                setState(() {
                  _isListLoading = false;
                });
              },
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredQuery().snapshots(),
                builder: (context, snapshot) {
                  if (_isListLoading && snapshot.connectionState != ConnectionState.waiting) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isListLoading = false;
                        });
                      }
                    });
                  }
                  if (snapshot.connectionState == ConnectionState.waiting && _isListLoading) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LoadingAnimationWidget.stretchedDots(
                            color: isDarkMode ? accentColor : primaryColor,
                            size: 50,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading your tasks...',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading data: ${snapshot.error}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isListLoading = true;
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.task_alt,
                            color: Colors.grey,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filterOption == 'All' ? 'No tasks yet' : 'No $_filterOption tasks',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filterOption == 'All' ? 'Add a task to get started' : 'Try a different filter',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final title = data['title'] as String;
                      final completed = data['completed'] as bool;
                      final Timestamp? dueDateTimestamp = data['dueDate'] as Timestamp?;
                      final DateTime? dueDate = dueDateTimestamp?.toDate();
                      final int priority = data['priority'] as int? ?? 0;
                      final bool isUpdating = _updatingTasks.contains(doc.id);
                      final bool isDeleting = _loadingTaskId == doc.id;
                      final bool isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && !completed;
                      String dateText = '';
                      if (dueDate != null) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final tomorrow = DateTime(now.year, now.month, now.day + 1);
                        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
                        if (dueDay == today) {
                          dateText = 'Today';
                        } else if (dueDay == tomorrow) {
                          dateText = 'Tomorrow';
                        } else {
                          dateText = DateFormat('MMM d, y').format(dueDate);
                        }
                      }
                      Color statusColor = Colors.grey;
                      String statusText = 'Normal';
                      if (completed) {
                        statusColor = Colors.green;
                        statusText = 'Completed';
                      } else if (isOverdue) {
                        statusColor = Colors.red;
                        statusText = 'Overdue';
                      } else if (priority == 2) {
                        statusColor = Colors.red.shade700;
                        statusText = 'High Priority';
                      } else if (priority == 1) {
                        statusColor = Colors.orange;
                        statusText = 'Medium Priority';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: Key(doc.id),
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await _showConfirmDialog(
                              title: 'Delete Task',
                              content: 'Are you sure you want to delete this task?',
                              confirmText: 'Delete',
                            );
                          },
                          onDismissed: (_) => _deleteTodo(doc.id),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: completed ? FontWeight.normal : FontWeight.bold,
                                                    decoration: completed ? TextDecoration.lineThrough : null,
                                                    color: completed
                                                        ? (isDarkMode ? Colors.grey : Colors.grey.shade700)
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  statusText,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (dueDate != null)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.event,
                                                  size: 14,
                                                  color: isOverdue
                                                      ? Colors.red
                                                      : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Due: $dateText',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isOverdue
                                                        ? Colors.red
                                                        : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
                                                    fontWeight: isOverdue ? FontWeight.bold : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: isUpdating
                                                    ? Center(
                                                        child: LoadingAnimationWidget.stretchedDots(
                                                          color: isDarkMode ? accentColor : primaryColor,
                                                          size: 20,
                                                        ),
                                                      )
                                                    : Checkbox(
                                                        value: completed,
                                                        activeColor: isDarkMode ? accentColor : primaryColor,
                                                        checkColor: isDarkMode ? Colors.black : null,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        onChanged: (value) => _toggleTodoStatus(doc.id, completed),
                                                      ),
                                              ),
                                              Row(
                                                children: [
                                                  isDeleting
                                                      ? SizedBox(
                                                          width: 32,
                                                          height: 32,
                                                          child: Center(
                                                            child: LoadingAnimationWidget.stretchedDots(
                                                              color: isDarkMode
                                                                  ? Colors.grey.shade400
                                                                  : Colors.grey.shade700,
                                                              size: 20,
                                                            ),
                                                          ),
                                                        )
                                                      : SizedBox(
                                                          width: 32,
                                                          height: 32,
                                                          child: PopupMenuButton<String>(
                                                            icon: Icon(
                                                              Icons.more_vert,
                                                              size: 18,
                                                              color: isDarkMode
                                                                  ? Colors.grey.shade400
                                                                  : Colors.grey.shade700,
                                                            ),
                                                            padding: EdgeInsets.zero,
                                                            onSelected: (String value) {
                                                              if (value == 'edit') {
                                                                _editTaskDetails(doc.id, title, dueDate, priority);
                                                              } else if (value == 'delete') {
                                                                _deleteTodo(doc.id);
                                                              }
                                                            },
                                                            elevation: 3,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            offset: const Offset(0, 4),
                                                            itemBuilder: (BuildContext context) =>
                                                                <PopupMenuEntry<String>>[
                                                              PopupMenuItem<String>(
                                                                value: 'edit',
                                                                height: 36,
                                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                                child: const Row(
                                                                  children: [
                                                                    Icon(Icons.edit, color: Colors.blue, size: 16),
                                                                    SizedBox(width: 8),
                                                                    Text('Change', style: TextStyle(fontSize: 13)),
                                                                  ],
                                                                ),
                                                              ),
                                                              const PopupMenuDivider(height: 1),
                                                              PopupMenuItem<String>(
                                                                value: 'delete',
                                                                height: 36,
                                                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                                child: const Row(
                                                                  children: [
                                                                    Icon(Icons.delete, color: Colors.red, size: 16),
                                                                    SizedBox(width: 8),
                                                                    Text('Delete', style: TextStyle(fontSize: 13)),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                            enabled: !isUpdating && !isDeleting,
                                                          ),
                                                        ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (isDeleting)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  LoadingAnimationWidget.stretchedDots(
                                                    color: isDarkMode ? Colors.white70 : Colors.black54,
                                                    size: 30,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Deleting...',
                                                    style: TextStyle(
                                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
