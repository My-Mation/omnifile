import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/detect_file_type_usecase.dart';

final detectFileTypeUseCaseProvider = Provider<DetectFileTypeUseCase>((ref) {
  return DetectFileTypeUseCase();
});
