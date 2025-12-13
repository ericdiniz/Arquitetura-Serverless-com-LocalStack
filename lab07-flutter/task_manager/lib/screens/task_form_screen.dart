import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../services/camera_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/photo_filter_service.dart';
import '../services/upload_service.dart';
import '../widgets/location_picker.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const int _maxPhotos = 5;

  String _priority = 'medium';
  bool _completed = false;
  bool _isSaving = false;
  DateTime? _dueDate;
  late String _categoryId;
  List<String> _photoPaths = <String>[];
  late final Set<String> _initialPhotoPaths;
  final Set<String> _newPhotoPaths = <String>{};
  final Set<String> _removedInitialPhotoPaths = <String>{};
  bool _didPersistPhotos = false;
  double? _latitude;
  double? _longitude;
  String? _locationName;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _categoryId = Categories.defaultCategory().id;
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _completed = widget.task!.completed;
      _dueDate = widget.task!.dueDate;
      _categoryId = widget.task!.categoryId ?? _categoryId;
      _photoPaths = List<String>.from(widget.task!.photoPaths);
      _latitude = widget.task!.latitude;
      _longitude = widget.task!.longitude;
      _locationName = widget.task!.locationName;
    } else {
      _photoPaths = <String>[];
    }
    _initialPhotoPaths = Set<String>.from(_photoPaths);
  }

  @override
  void dispose() {
    if (!_didPersistPhotos) {
      _cleanupUnsavedPhotos();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Handles both creation and update flows, showing feedback for each case.
  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.task == null) {
        final task = Task(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          dueDate: _dueDate,
          categoryId: _categoryId,
          photoPaths: _photoPaths,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
        );
        await DatabaseService.instance.create(task);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa criada com sucesso'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final updated = widget.task!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          completed: _completed,
          dueDate: _dueDate,
          overrideDueDate: true,
          categoryId: _categoryId,
          overrideCategory: true,
          photoPaths: _photoPaths,
          overridePhotos: true,
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          overrideLocation: true,
        );
        await DatabaseService.instance.update(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Tarefa atualizada'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      await _persistPhotoChanges();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar tarefa: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _persistPhotoChanges() async {
    for (final removed in _removedInitialPhotoPaths) {
      await CameraService.instance.deletePhoto(removed);
    }
    _removedInitialPhotoPaths.clear();
    // Upload newly added photos to backend (LocalStack) so they are stored in S3
    if (_newPhotoPaths.isNotEmpty) {
      for (final newPath in List<String>.from(_newPhotoPaths)) {
        try {
          final success = await UploadService.uploadFile(newPath);
          // If upload failed we keep the local copy; we only log here.
          if (!success) {
            // ignore: avoid_print
            print('Upload failed for $newPath');
          }
        } catch (e) {
          // ignore: avoid_print
          print('Upload exception for $newPath: $e');
        }
      }
    }

    _newPhotoPaths.clear();
    _initialPhotoPaths
      ..clear()
      ..addAll(_photoPaths);
    _didPersistPhotos = true;
  }

  void _cleanupUnsavedPhotos() {
    for (final path in _newPhotoPaths) {
      CameraService.instance.deletePhoto(path);
    }
  }

  Future<void> _takePicture() async {
    if (_photoPaths.length >= _maxPhotos) {
      _showPhotoLimitWarning();
      return;
    }

    final path = await CameraService.instance.takePicture(context);
    if (path == null) {
      return;
    }

    await _handleNewPhoto(path);
  }

  Future<void> _removePhoto(String path) async {
    if (!_photoPaths.contains(path)) {
      return;
    }

    setState(() {
      _photoPaths = List<String>.from(_photoPaths)..remove(path);
    });

    if (_initialPhotoPaths.contains(path)) {
      _removedInitialPhotoPaths.add(path);
    } else {
      _newPhotoPaths.remove(path);
      await CameraService.instance.deletePhoto(path);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Foto removida'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickLocation() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LocationPicker(
        initialLatitude: _latitude,
        initialLongitude: _longitude,
        initialAddress: _locationName,
        onLocationSelected: (lat, lon, address) {
          setState(() {
            _latitude = lat;
            _longitude = lon;
            _locationName = address;
          });
        },
      ),
    );
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Localização removida'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final remainingSlots = _maxPhotos - _photoPaths.length;
    if (remainingSlots <= 0) {
      _showPhotoLimitWarning();
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage();
      if (images.isEmpty) {
        return;
      }

      int added = 0;
      for (final image in images) {
        if (_photoPaths.length >= _maxPhotos) {
          break;
        }

        final savedPath = await CameraService.instance.savePicture(image);
        await _handleNewPhoto(savedPath, showSuccessFeedback: false);
        added += 1;
      }

      if (added > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🖼️ $added foto(s) adicionada(s) da galeria'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar imagem: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewPhoto(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Pré-visualização'),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(path)),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoLimitWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Limite de $_maxPhotos foto(s) por tarefa atingido'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleNewPhoto(
    String originalPath, {
    bool showSuccessFeedback = true,
  }) async {
    if (!mounted) {
      await CameraService.instance.deletePhoto(originalPath);
      return;
    }

    final filter = await _promptFilterSelection(
      title: 'Escolha um filtro para a nova foto',
    );

    if (filter == null) {
      await CameraService.instance.deletePhoto(originalPath);
      return;
    }

    if (_photoPaths.length >= _maxPhotos) {
      await CameraService.instance.deletePhoto(originalPath);
      _showPhotoLimitWarning();
      return;
    }

    late final String processedPath;
    try {
      processedPath = await _applyFilterIfNeeded(originalPath, filter);
    } catch (error) {
      await CameraService.instance.deletePhoto(originalPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aplicar filtro: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) {
      await CameraService.instance.deletePhoto(processedPath);
      return;
    }

    if (_photoPaths.contains(processedPath)) {
      await CameraService.instance.deletePhoto(processedPath);
      return;
    }

    setState(() {
      _photoPaths = List<String>.from(_photoPaths)..add(processedPath);
    });

    _newPhotoPaths.add(processedPath);

    if (showSuccessFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Foto adicionada'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _applyFilterToExistingPhoto(String path) async {
    if (!mounted || !_photoPaths.contains(path)) {
      return;
    }

    final filter = await _promptFilterSelection(
      title: 'Aplicar filtro',
    );

    if (filter == null || filter == PhotoFilterType.original) {
      return;
    }

    final duplicatePath = await _duplicatePhoto(path);
    if (duplicatePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível preparar a foto para o filtro'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    late final String processedPath;
    try {
      processedPath = await _applyFilterIfNeeded(duplicatePath, filter);
    } catch (error) {
      await CameraService.instance.deletePhoto(duplicatePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aplicar filtro: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) {
      await CameraService.instance.deletePhoto(processedPath);
      return;
    }

    setState(() {
      final index = _photoPaths.indexOf(path);
      if (index != -1) {
        final updated = List<String>.from(_photoPaths);
        updated[index] = processedPath;
        _photoPaths = updated;
      }
    });

    if (_initialPhotoPaths.contains(path)) {
      _removedInitialPhotoPaths.add(path);
    } else {
      _newPhotoPaths.remove(path);
    }
    _newPhotoPaths.add(processedPath);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎨 Filtro aplicado'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<String?> _duplicatePhoto(String path) async {
    try {
      final original = File(path);
      if (!await original.exists()) {
        return null;
      }

      final directory = original.parent.path;
      final fileName =
          'task_${DateTime.now().millisecondsSinceEpoch}_${original.hashCode}.jpg';
      final copy = await original.copy('$directory/$fileName');
      return copy.path;
    } catch (_) {
      return null;
    }
  }

  Future<String> _applyFilterIfNeeded(
    String path,
    PhotoFilterType filter,
  ) {
    if (filter == PhotoFilterType.original) {
      return Future.value(path);
    }
    return PhotoFilterService.instance.applyFilter(path, filter);
  }

  Future<PhotoFilterType?> _promptFilterSelection(
      {required String title}) async {
    if (!mounted) return null;

    return showModalBottomSheet<PhotoFilterType>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Original'),
                onTap: () => Navigator.pop(context, PhotoFilterType.original),
              ),
              ListTile(
                leading: const Icon(Icons.filter_b_and_w),
                title: const Text('Preto e branco'),
                onTap: () => Navigator.pop(context, PhotoFilterType.grayscale),
              ),
              ListTile(
                leading: const Icon(Icons.tonality),
                title: const Text('Sépia'),
                onTap: () => Navigator.pop(context, PhotoFilterType.sepia),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context, null),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoThumbnail(String path, int index) {
    return SizedBox(
      width: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image,
                        color: Colors.grey.shade500,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Erro ao carregar',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => _viewPhoto(path),
                    icon: const Icon(Icons.zoom_in),
                    tooltip: 'Visualizar',
                  ),
                  const SizedBox(height: 8),
                  IconButton.filledTonal(
                    onPressed: () => _applyFilterToExistingPhoto(path),
                    icon: const Icon(Icons.brush),
                    tooltip: 'Aplicar filtro',
                  ),
                  const SizedBox(height: 8),
                  IconButton.filledTonal(
                    onPressed: () => _removePhoto(path),
                    icon: const Icon(Icons.delete),
                    tooltip: 'Remover',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initialDate = _dueDate ?? now;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Selecionar data de vencimento',
    );

    if (selectedDate != null) {
      setState(() {
        _dueDate = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ex: Estudar Flutter',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe um título';
                        }
                        if (value.trim().length < 3) {
                          return 'Título deve ter pelo menos 3 caracteres';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Adicione mais detalhes...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 500,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Baixa'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Média'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Row(
                            children: [
                              Icon(Icons.flag, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Alta'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Row(
                            children: [
                              Icon(Icons.priority_high, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('Urgente'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final category in Categories.all)
                          DropdownMenuItem(
                            value: category.id,
                            child: Row(
                              children: [
                                Icon(category.icon, color: category.color),
                                const SizedBox(width: 8),
                                Text(category.name),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _categoryId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Localização',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                if (_latitude != null)
                                  IconButton(
                                    tooltip: 'Remover localização',
                                    onPressed: _removeLocation,
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_latitude != null && _longitude != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  _locationName ??
                                      LocationService.instance
                                          .formatCoordinates(
                                              _latitude!, _longitude!),
                                ),
                                subtitle: Text(
                                  LocationService.instance.formatCoordinates(
                                    _latitude!,
                                    _longitude!,
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Alterar localização',
                                  icon: const Icon(Icons.edit_location_alt),
                                  onPressed: _pickLocation,
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _pickLocation,
                                icon: const Icon(Icons.add_location_alt),
                                label: const Text('Adicionar localização'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Anexar fotos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_photoPaths.length}/$_maxPhotos',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_photoPaths.isEmpty)
                              Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Nenhuma foto anexada',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            else
                              SizedBox(
                                height: 180,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _photoPaths.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final path = _photoPaths[index];
                                    return _buildPhotoThumbnail(path, index);
                                  },
                                ),
                              ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _photoPaths.length >= _maxPhotos
                                  ? null
                                  : _takePicture,
                              icon: const Icon(Icons.camera),
                              label: Text(
                                _photoPaths.isEmpty
                                    ? 'Capturar foto'
                                    : 'Capturar outra foto',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _photoPaths.length >= _maxPhotos
                                  ? null
                                  : _pickFromGallery,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Selecionar da galeria'),
                            ),
                            if (_photoPaths.length >= _maxPhotos)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Você atingiu o limite máximo de fotos para esta tarefa.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.event,
                          color: _dueDate != null
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: const Text('Data de vencimento'),
                        subtitle: Text(
                          _dueDate != null
                              ? 'Vence em ${dateFormat.format(_dueDate!)}'
                              : 'Nenhuma data definida',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_dueDate != null)
                              IconButton(
                                tooltip: 'Limpar data',
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    setState(() => _dueDate = null),
                              ),
                            IconButton(
                              tooltip: 'Selecionar data',
                              icon: const Icon(Icons.calendar_today),
                              onPressed: _pickDueDate,
                            ),
                          ],
                        ),
                        onTap: _pickDueDate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: SwitchListTile(
                        value: _completed,
                        title: const Text('Tarefa completa'),
                        subtitle: Text(
                          _completed
                              ? 'Esta tarefa está concluída'
                              : 'Esta tarefa ainda está pendente',
                        ),
                        secondary: Icon(
                          _completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _completed ? Colors.green : Colors.grey,
                        ),
                        onChanged: (value) =>
                            setState(() => _completed = value),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saveTask,
                      icon: const Icon(Icons.save),
                      label:
                          Text(isEditing ? 'Atualizar Tarefa' : 'Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
