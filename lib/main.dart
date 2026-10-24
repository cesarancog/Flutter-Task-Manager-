
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ==========================================
// 1. TASK MODEL
// ==========================================

class Task {
  final int id;
  final String title;
  final bool isCompleted;

  const Task({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int,
      title: map['title'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }
}

// ==========================================
// 2. DATABASE HELPER
// ==========================================

class TaskDatabase {
  TaskDatabase._();

  static final TaskDatabase instance = TaskDatabase._();

  Future<Database>? _databaseFuture;

  Future<Database> get database {
    return _databaseFuture ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = p.join(
      databaseDirectory,
      'tasks.db',
    );

    return openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }
}

// ==========================================
// 3. TASK REPOSITORY
// ==========================================

class TaskRepository {
  final TaskDatabase _storage;

  TaskRepository(this._storage);

  Future<int> create(String title) async {
    final db = await _storage.database;

    return db.insert(
      'tasks',
      {'title': title},
    );
  }

  Future<List<Task>> getAll() async {
    final db = await _storage.database;

    final rows = await db.query(
      'tasks',
      orderBy: 'id DESC',
    );

    return rows.map((row) => Task.fromMap(row)).toList();
  }

  Future<int> updateCompletion(int id, bool completed) async {
    final db = await _storage.database;

    return db.update(
      'tasks',
      {'is_completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _storage.database;

    return db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ==========================================
// 4. MAIN APPLICATION
// ==========================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskManagerApp());
}

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
      ),
      home: const TaskHomePage(),
    );
  }
}

// ==========================================
// 5. TASK USER INTERFACE
// ==========================================

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  final TextEditingController _controller =
      TextEditingController();

  final TaskRepository _repository =
      TaskRepository(TaskDatabase.instance);

  List<Task> _tasks = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  int get _completedCount =>
      _tasks.where((task) => task.isCompleted).length;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final savedTasks = await _repository.getAll();

      if (!mounted) return;

      setState(() {
        _tasks = savedTasks;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load tasks. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addTask() async {
    final title = _controller.text.trim();

    // Reject empty or whitespace-only titles.
    if (title.isEmpty) {
      _showMessage('Please enter a task title.');
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.create(title);

      if (!mounted) return;

      _controller.clear();
      await _loadTasks();

      if (mounted && _errorMessage == null) {
        _showMessage('Task added successfully!');
      }
    } catch (e) {
      _showMessage('Failed to save the task. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleTask(Task task, bool completed) async {
    try {
      await _repository.updateCompletion(task.id, completed);
      await _loadTasks();

      if (mounted && _errorMessage == null) {
        _showMessage(
          completed
              ? 'Task marked as completed.'
              : 'Task marked as pending.',
        );
      }
    } catch (e) {
      _showMessage('Failed to update the task.');
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await _repository.delete(task.id);
      await _loadTasks();

      if (mounted && _errorMessage == null) {
        _showMessage('Task deleted successfully.');
      }
    } catch (e) {
      _showMessage('Failed to delete the task.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Task Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stay organized!',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your tasks are saved locally on this device.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),

              // Add-task input.
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isSaving) _addTask();
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter a task title',
                        prefixIcon: const Icon(Icons.edit_note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _addTask,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Task summary.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.indigo,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_tasks.length} total tasks',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '$_completedCount completed',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'My Tasks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Saved tasks.
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: _loadTasks,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _tasks.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.task_alt,
                                      size: 60,
                                      color: Colors.black26,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No tasks yet.',
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text('Add your first task above.'),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadTasks,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: _tasks.length,
                                  itemBuilder: (context, index) {
                                    final task = _tasks[index];

                                    return Card(
                                      margin: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: ListTile(
                                        leading: Checkbox(
                                          value: task.isCompleted,
                                          onChanged: (value) {
                                            if (value != null) {
                                              _toggleTask(task, value);
                                            }
                                          },
                                        ),
                                        title: Text(
                                          task.title,
                                          style: TextStyle(
                                            decoration:
                                                task.isCompleted
                                                    ? TextDecoration
                                                        .lineThrough
                                                    : TextDecoration.none,
                                            color: task.isCompleted
                                                ? Colors.black45
                                                : Colors.black87,
                                          ),
                                        ),
                                        subtitle: Text(
                                          task.isCompleted
                                              ? 'Completed'
                                              : 'Pending',
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Delete task',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            _deleteTask(task);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
