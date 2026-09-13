import '../../domain/entities/file_entity.dart';
import '../../domain/entities/viewer_type.dart';

class FileModel extends FileEntity {
  const FileModel({
    required super.path,
    required super.name,
    required super.size,
    required super.lastModified,
    super.detectedType = ViewerType.unknown,
    super.mimeType,
  });

  factory FileModel.fromEntity(FileEntity entity) {
    return FileModel(
      path: entity.path,
      name: entity.name,
      size: entity.size,
      lastModified: entity.lastModified,
      detectedType: entity.detectedType,
      mimeType: entity.mimeType,
    );
  }

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String) ?? DateTime.now()
          : DateTime.now(),
      detectedType: ViewerType.values.firstWhere(
        (e) => e.name == (json['detectedType'] as String?),
        orElse: () => ViewerType.unknown,
      ),
      mimeType: json['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'lastModified': lastModified.toIso8601String(),
      'detectedType': detectedType.name,
      'mimeType': mimeType,
    };
  }
}
