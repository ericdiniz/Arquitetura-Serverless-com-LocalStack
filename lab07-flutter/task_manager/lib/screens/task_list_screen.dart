import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  String _filter = 'all';
  String _searchQuery = '';
  String _sortBy = 'date'; // date, priority, title
  String _categoryFilter = 'all';
  bool _isLoading = false;
  bool _isShakeDialogOpen = false;
  double? _nearbyLatitude;
  double? _nearbyLongitude;
  final double _nearbyRadiusInMeters = 1000;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _setupShakeDetection();
  }

  @override
  void dispose() {
    SensorService.instance.stop();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await DatabaseService.instance.readAll();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  void _setupShakeDetection() {
    SensorService.instance.startShakeDetection(() {
      if (!mounted || _isShakeDialogOpen) {
        return;
      }
      _showShakeDialog();
    });
  }

  void _showShakeDialog() {
    final pendingTasks = _tasks.where((task) => !task.completed).toList();
    if (pendingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Nenhuma tarefa pendente!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    _isShakeDialogOpen = true;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vibration, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Shake detectado!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecione uma tarefa para completar:'),
            const SizedBox(height: 16),
            for (final task in pendingTasks.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _completeTaskByShake(task),
                ),
              ),
            if (pendingTasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${pendingTasks.length - 3} outras tarefas',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ).whenComplete(() => _isShakeDialogOpen = false);
  }

  Future<void> _completeTaskByShake(Task task) async {
    final updated = task.copyWith(
      completed: true,
      completedAt: DateTime.now(),
      overrideCompletedAt: true,
      completedBy: 'shake',
      overrideCompletedBy: true,
    );

    await DatabaseService.instance.update(updated);
    if (!mounted) return;

    Navigator.pop(context);
    await _loadTasks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ "${task.title}" concluída via shake!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _toggleTask(Task task) async {
    final isCompleting = !task.completed;
    final updated = task.copyWith(
      completed: isCompleting,
      completedAt: isCompleting ? DateTime.now() : null,
      overrideCompletedAt: true,
      completedBy: isCompleting ? 'manual' : null,
      overrideCompletedBy: true,
    );
    await DatabaseService.instance.update(updated);
    await _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja excluir "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (task.hasPhotos) {
        for (final path in task.photoPaths) {
          await CameraService.instance.deletePhoto(path);
        }
      }
      await DatabaseService.instance.delete(task.id);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa excluída'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  List<Task> get _filteredTasks {
    // Work on a copy to avoid mutating the original list
    var tasks = List<Task>.from(_tasks);

    // Filter by status
    if (_filter == 'completed') {
      tasks = tasks.where((t) => t.completed).toList();
    } else if (_filter == 'pending') {
      tasks = tasks.where((t) => !t.completed).toList();
    } else if (_filter == 'nearby') {
      if (_nearbyLatitude != null && _nearbyLongitude != null) {
        tasks = tasks.where((task) {
          if (!task.hasLocation) return false;
          final distance = LocationService.instance.distanceBetween(
            _nearbyLatitude!,
            _nearbyLongitude!,
            task.latitude!,
            task.longitude!,
          );
          return distance <= _nearbyRadiusInMeters;
        }).toList();
      } else {
        tasks = [];
      }
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      tasks = tasks.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q);
      }).toList();
    }

    if (_categoryFilter != 'all') {
      tasks =
          tasks.where((task) => task.categoryId == _categoryFilter).toList();
    }

    // Sorting
    switch (_sortBy) {
      case 'priority':
        final priorityOrder = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
        tasks.sort((a, b) {
          final orderA = priorityOrder[a.priority] ?? 2;
          final orderB = priorityOrder[b.priority] ?? 2;
          return orderA.compareTo(orderB);
        });
        break;
      case 'title':
        tasks.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'dueDate':
        tasks.sort((a, b) {
          final dateA = a.dueDate;
          final dateB = b.dueDate;
          if (dateA == null && dateB == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          final comparison = dateA.compareTo(dateB);
          if (comparison != 0) {
            return comparison;
          }
          return a.title.compareTo(b.title);
        });
        break;
      case 'date':
      default:
        tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return tasks;
  }

  Future<void> _openTaskForm([Task? task]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(task: task),
      ),
    );

    if (result == true) {
      await _loadTasks();
    }
  }

  Future<void> _filterByNearby() async {
    final snapshot =
        await LocationService.instance.getCurrentLocationWithAddress();

    if (!mounted) return;

    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Não foi possível obter a localização atual'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _nearbyLatitude = snapshot.latitude;
      _nearbyLongitude = snapshot.longitude;
      _filter = 'nearby';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          snapshot.address != null
              ? '📍 Filtrando por tarefas próximas a ${snapshot.address}'
              : '📍 Filtrando tarefas próximas',
        ),
      ),
    );
  }

  // Summarizes task counts to populate the statistics header card.
  Map<String, int> _calculateStats() {
    final completed = _tasks.where((task) => task.completed).length;
    final pending = _tasks.length - completed;
    return {
      'total': _tasks.length,
      'completed': completed,
      'pending': pending,
    };
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Provides contextual messaging when the filtered list has no tasks.
  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filter) {
      case 'completed':
        message = 'Nenhuma tarefa concluída ainda';
        icon = Icons.check_circle_outline;
        break;
      case 'pending':
        message = 'Nenhuma tarefa pendente';
        icon = Icons.pending_actions;
        break;
      default:
        message = 'Nenhuma tarefa cadastrada';
        icon = Icons.task_alt;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openTaskForm(),
            icon: const Icon(Icons.add),
            label: const Text('Criar primeira tarefa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        actions: [
          // Menu de Ordenação
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'date', child: Text('Ordenar por Data')),
              PopupMenuItem(
                  value: 'priority', child: Text('Ordenar por Prioridade')),
              PopupMenuItem(value: 'title', child: Text('Ordenar por Título')),
              PopupMenuItem(
                  value: 'dueDate', child: Text('Ordenar por Vencimento')),
            ],
          ),

          // Menu de Filtro
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'nearby') {
                _filterByNearby();
              } else {
                setState(() => _filter = value);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending_actions),
                    SizedBox(width: 8),
                    Text('Pendentes'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'nearby',
                child: Row(
                  children: [
                    Icon(Icons.near_me),
                    SizedBox(width: 8),
                    Text('Próximas'),
                  ],
                ),
              ),
            ],
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.category_outlined),
            onSelected: (value) => setState(() => _categoryFilter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.category),
                    SizedBox(width: 8),
                    Text('Todas as categorias'),
                  ],
                ),
              ),
              ...Categories.all.map(
                (category) => PopupMenuItem(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(category.icon, color: category.color),
                      const SizedBox(width: 8),
                      Text(category.name),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar tarefas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          if (_tasks.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todas as categorias'),
                      selected: _categoryFilter == 'all',
                      onSelected: (_) =>
                          setState(() => _categoryFilter = 'all'),
                    ),
                  ),
                  ...Categories.all.map((category) {
                    final isSelected = _categoryFilter == category.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.icon,
                              size: 18,
                              color: isSelected ? Colors.white : category.color,
                            ),
                            const SizedBox(width: 6),
                            Text(category.name),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: category.color,
                        backgroundColor: category.color.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : category.color,
                        ),
                        onSelected: (_) =>
                            setState(() => _categoryFilter = category.id),
                      ),
                    );
                  }),
                ],
              ),
            ),

          if (_tasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 4),
                    color: Colors.black26,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.list,
                    'Total',
                    stats['total'].toString(),
                  ),
                  _buildStatItem(
                    Icons.pending_actions,
                    'Pendentes',
                    stats['pending'].toString(),
                  ),
                  _buildStatItem(
                    Icons.check_circle,
                    'Concluídas',
                    stats['completed'].toString(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTasks.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            return TaskCard(
                              task: task,
                              onTap: () => _openTaskForm(task),
                              onToggle: () => _toggleTask(task),
                              onDelete: () => _deleteTask(task),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
      ),
    );
  }
}
