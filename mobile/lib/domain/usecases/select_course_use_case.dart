import '../repositories/i_course_repository.dart';
import '../repositories/i_learner_repository.dart';
import '../entities/course.dart';
import '../../core/errors/domain_error.dart';

class SelectCourseUseCase {
  final ICourseRepository courseRepository;
  final ILearnerRepository learnerRepository;

  const SelectCourseUseCase(this.courseRepository, this.learnerRepository);

  Future<Course> execute(String courseId) async {
    final course = await courseRepository.getCourseById(courseId);
    if (course == null) {
      throw EntityNotFoundError('Kurs', courseId);
    }

    final profile = await learnerRepository.getProfile();
    await learnerRepository.updateProfile(profile.copyWith(selectedCourseId: courseId));
    return course;
  }
}
