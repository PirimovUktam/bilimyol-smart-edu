import 'package:flutter_test/flutter_test.dart';
import 'package:bilimyol_mobile/domain/entities/monitoring_entities.dart';
import 'package:bilimyol_mobile/data/repositories/in_memory_monitoring_repository.dart';

void main() {
  group('Parent + Teacher Monitoring & Security Tests (Flutter)', () {
    late InMemoryMonitoringRepository monitoringRepo;

    setUp(() {
      monitoringRepo = InMemoryMonitoringRepository();
      monitoringRepo.resetAll();
    });

    test('rejects invalid teacher verification code and preserves student role', () async {
      expect(await monitoringRepo.getUserRole(), equals(UserRole.student));

      final invalidRes = await monitoringRepo.redeemTeacherInvitationCode('INVALID-CODE-99');
      expect(invalidRes['success'], isFalse);
      expect(invalidRes['message'], contains('yaroqsiz'));

      expect(await monitoringRepo.getUserRole(), equals(UserRole.student));
    });

    test('activates teacher role with valid dynamically created invitation code', () async {
      final created = await monitoringRepo.createTeacherInvitation(schoolName: 'Toshkent IDUM');
      final validRes = await monitoringRepo.redeemTeacherInvitationCode(created['plain_code']!);
      expect(validRes['success'], isTrue);
      expect(validRes['school_name'], equals('Toshkent IDUM'));

      expect(await monitoringRepo.getUserRole(), equals(UserRole.teacher));
    });

    test('creates parent link code and allows child to redeem', () async {
      final codeRes = await monitoringRepo.createParentLinkCode();
      expect(codeRes['link_code'], isNotNull);

      final redeemRes = await monitoringRepo.redeemParentLinkCode(codeRes['link_code']!);
      expect(redeemRes['success'], isTrue);
    });

    test('loads parent children summary with pedagogical metrics', () async {
      final children = await monitoringRepo.getParentChildren();
      expect(children.isNotEmpty, isTrue);

      final child = children.first;
      expect(child.todayActiveMinutes, equals(37));
      expect(child.overallScore, equals(76));
      expect(child.weakestSkillName, equals('Funksiyalar'));
    });

    test('teacher creates class and retrieves student roster', () async {
      final newClass = await monitoringRepo.createTeacherClass('7-A Sinf');
      expect(newClass.name, equals('7-A Sinf'));
      expect(newClass.classCode, isNotNull);
      expect(newClass.classCode.length, greaterThanOrEqualTo(4));

      final students = await monitoringRepo.getClassStudents(newClass.id);
      expect(students.length, equals(3));
      expect(students.any((s) => s.status == 'E’tibor'), isTrue);
    });

    test('student joins teacher class by unique code', () async {
      final newClass = await monitoringRepo.createTeacherClass('8-B Algebra');
      final joinRes = await monitoringRepo.joinClassByCode(newClass.classCode);
      expect(joinRes['success'], isTrue);
      expect(joinRes['class_name'], equals('8-B Algebra'));
    });
  });
}
