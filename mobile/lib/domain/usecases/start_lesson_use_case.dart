import '../repositories/i_lesson_repository.dart';
import '../entities/lesson.dart';
import '../../core/errors/domain_error.dart';

class StartLessonUseCase {
  final ILessonRepository lessonRepository;

  const StartLessonUseCase(this.lessonRepository);

  Future<Lesson> execute(String lessonId) async {
    final lesson = await lessonRepository.getLessonById(lessonId);
    if (lesson == null) {
      throw EntityNotFoundError('Dars', lessonId);
    }
    return lesson;
  }
}
