import 'package:equatable/equatable.dart';

abstract class AppFailure extends Equatable {
  final String message;
  final dynamic cause;

  const AppFailure(this.message, [this.cause]);

  @override
  List<Object?> get props => [message, cause];
}

class FilePickerFailure extends AppFailure {
  const FilePickerFailure(super.message, [super.cause]);
}

class StorageFailure extends AppFailure {
  const StorageFailure(super.message, [super.cause]);
}

class CacheFailure extends AppFailure {
  const CacheFailure(super.message, [super.cause]);
}
