import 'dart:convert';

import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? categoryId;
  final List<String> photoPaths;
  final DateTime? completedAt;
  final String? completedBy;
  final double? latitude;
  final double? longitude;
  final String? locationName;

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = 'medium',
    DateTime? createdAt,
    this.dueDate,
    this.categoryId,
    List<String>? photoPaths,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        photoPaths = List.unmodifiable(photoPaths ?? const []);

  bool get hasPhotos => photoPaths.isNotEmpty;
  String? get primaryPhotoPath => hasPhotos ? photoPaths.first : null;
  @Deprecated('Use hasPhotos')
  bool get hasPhoto => hasPhotos;
  @Deprecated('Use primaryPhotoPath')
  String? get photoPath => primaryPhotoPath;
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'categoryId': categoryId,
      'photoPath': primaryPhotoPath,
      'photoPaths': jsonEncode(photoPaths),
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    List<String> parsedPhotoPaths = const [];
    final rawPhotoPaths = map['photoPaths'];
    if (rawPhotoPaths is String && rawPhotoPaths.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPhotoPaths);
        if (decoded is List) {
          parsedPhotoPaths = decoded
              .whereType<String>()
              .where((path) => path.isNotEmpty)
              .toList();
        }
      } catch (_) {
        parsedPhotoPaths = const [];
      }
    }

    if (parsedPhotoPaths.isEmpty && map['photoPath'] != null) {
      final singlePath = map['photoPath'] as String?;
      if (singlePath != null && singlePath.isNotEmpty) {
        parsedPhotoPaths = [singlePath];
      }
    }

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      completed: map['completed'] == 1,
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['createdAt']),
      dueDate:
          map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      categoryId: map['categoryId'],
      photoPaths: parsedPhotoPaths,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'])
          : null,
      completedBy: map['completedBy'],
      latitude: map['latitude'] != null
          ? (map['latitude'] as num?)?.toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num?)?.toDouble()
          : null,
      locationName: map['locationName'],
    );
  }

  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? dueDate,
    bool overrideDueDate = false,
    String? categoryId,
    bool overrideCategory = false,
    List<String>? photoPaths,
    bool overridePhotos = false,
    DateTime? completedAt,
    bool overrideCompletedAt = false,
    String? completedBy,
    bool overrideCompletedBy = false,
    double? latitude,
    double? longitude,
    bool overrideLocation = false,
    String? locationName,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      dueDate: overrideDueDate ? dueDate : this.dueDate,
      categoryId: overrideCategory ? categoryId : this.categoryId,
      photoPaths: overridePhotos ? (photoPaths ?? const []) : this.photoPaths,
      completedAt: overrideCompletedAt ? completedAt : this.completedAt,
      completedBy: overrideCompletedBy ? completedBy : this.completedBy,
      latitude: overrideLocation ? latitude : this.latitude,
      longitude: overrideLocation ? longitude : this.longitude,
      locationName: overrideLocation ? locationName : this.locationName,
    );
  }
}
