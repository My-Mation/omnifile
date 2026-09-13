import 'package:equatable/equatable.dart';
import 'viewer_type.dart';

class FileEntity extends Equatable {
  final String path;
  final String name;
  final int size;
  final DateTime lastModified;
  final ViewerType detectedType;
  final String? mimeType;

  const FileEntity({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
    this.detectedType = ViewerType.unknown,
    this.mimeType,
  });

  FileEntity copyWith({
    String? path,
    String? name,
    int? size,
    DateTime? lastModified,
    ViewerType? detectedType,
    String? mimeType,
  }) {
    return FileEntity(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      detectedType: detectedType ?? this.detectedType,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot != -1 ? name.substring(dot + 1).toLowerCase() : '';
  }

  @override
  List<Object?> get props => [path, name, size, lastModified, detectedType, mimeType];
}
