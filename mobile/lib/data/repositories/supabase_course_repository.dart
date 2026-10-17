import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/skill.dart';
import '../../domain/repositories/i_course_repository.dart';
import 'in_memory_course_repository.dart';

/// Online course/content repository.
///
/// The in-memory repository is used only when the app was intentionally built
/// without remote credentials. Once credentials are configured, every remote
/// failure is surfaced to the caller instead of silently showing seed content.
class SupabaseCourseRepository implements ICourseRepository {
  final InMemoryCourseRepository _fallback = InMemoryCourseRepository();

  SupabaseClient _requireClient() {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw StateError('Supabase ishga tushmadi. Qayta urinib ko‘ring.');
    }
    return client;
  }

  Future<void> _requireAuthenticated(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Autentifikatsiyadan o‘tilmagan.');
    }
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static SubjectType _subject(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'english':
      case 'ingliz':
      case 'english_language':
        return SubjectType.english;
      case 'it':
      case 'coding':
      case 'programming':
        return SubjectType.it;
      case 'logic':
      case 'mantiq':
        return SubjectType.logic;
      case 'mathematics':
      case 'math':
      case 'matematika':
      default:
        return SubjectType.mathematics;
    }
  }

  static QuestionDifficulty _difficulty(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'easy':
      case 'oson':
        return QuestionDifficulty.easy;
      case 'hard':
      case 'qiyin':
        return QuestionDifficulty.hard;
      case 'medium':
      case 'o‘rta':
      case "o'rta":
      default:
        return QuestionDifficulty.medium;
    }
  }

  static Course _course(Map<String, dynamic> row) {
    return Course(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      subject: _subject(row['subject']),
      description: row['description'] as String? ?? '',
      iconName: row['icon_name'] as String? ?? 'book',
      primaryColorHex: row['primary_color_hex'] as String? ?? '#2563EB',
      secondaryColorHex: row['secondary_color_hex'] as String? ?? '#3B82F6',
      skills: _strings(row['skills']),
      lessons: _strings(row['lessons']),
      totalStudentsEstimate:
          (row['total_students_estimate'] as num?)?.toInt() ?? 1000,
    );
  }

  static Skill _skill(Map<String, dynamic> row) {
    return Skill(
      id: row['id'] as String,
      courseId: row['course_id'] as String,
      name: row['name'] as String? ?? '',
      code: row['code'] as String? ?? '',
      description: row['description'] as String? ?? '',
      order: (row['order_index'] as num?)?.toInt() ?? 0,
      iconName: row['icon_name'] as String? ?? 'target',
    );
  }

  static Question _question(Map<String, dynamic> row) {
    return Question(
      id: row['id'] as String,
      courseId: row['course_id'] as String,
      skillId: row['skill_id'] as String,
      text: row['text'] as String? ?? '',
      contextSnippet: row['context_snippet'] as String?,
      options: _strings(row['options']),
      // learner_questions deliberately has no answer-key column. A negative
      // sentinel prevents accidental local scoring; the server RPC owns it.
      correctIndex: -1,
      difficulty: _difficulty(row['difficulty']),
      explanation: '',
      formulaLatex: row['formula_latex'] as String?,
      audioSimText: row['audio_sim_text'] as String?,
      audioSimSpeaker: row['audio_sim_speaker'] as String?,
    );
  }

  @override
  Future<List<Course>> getAllCourses() async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallback.getAllCourses();
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final rows = await client
        .from('courses')
        .select(
          'id, title, subject, description, icon_name, primary_color_hex, '
          'secondary_color_hex, total_students_estimate',
        )
        .eq('is_active', true)
        .order('created_at');
    return (rows as List)
        .whereType<Map>()
        .map((row) => _course(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<Course?> getCourseById(String courseId) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallback.getCourseById(courseId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final row = await client
        .from('courses')
        .select(
          'id, title, subject, description, icon_name, primary_color_hex, '
          'secondary_color_hex, total_students_estimate',
        )
        .eq('id', courseId)
        .eq('is_active', true)
        .maybeSingle();
    return row == null ? null : _course(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<Skill>> getSkillsByCourseId(String courseId) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallback.getSkillsByCourseId(courseId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final rows = await client
        .from('skills')
        .select('id, course_id, name, code, description, order_index, icon_name')
        .eq('course_id', courseId)
        .order('order_index');
    return (rows as List)
        .whereType<Map>()
        .map((row) => _skill(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<Question>> getPlacementQuestions(String courseId) async {
    if (!SupabaseConfig.hasRemoteConfiguration) {
      return _fallback.getPlacementQuestions(courseId);
    }
    final client = _requireClient();
    await _requireAuthenticated(client);
    final rows = await client
        .from('learner_questions')
        .select(
          'id, course_id, skill_id, text, context_snippet, options, '
          'difficulty, formula_latex, audio_sim_text, audio_sim_speaker',
        )
        .eq('course_id', courseId)
        .eq('is_placement', true)
        .order('created_at');
    return (rows as List)
        .whereType<Map>()
        .map((row) => _question(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
