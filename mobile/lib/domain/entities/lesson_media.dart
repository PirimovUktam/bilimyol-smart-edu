enum LessonMediaKind { audio, video, image }

enum LessonMediaLanguage { en, uz, ru }

enum LessonMediaReviewStatus { approved, draft }

class LessonMedia {
  static final RegExp _canonicalPathRegex = RegExp(
    r'^/lesson-media/(?:[a-z0-9_-]+/)*[a-z0-9_-]+\.[a-z0-9]+$',
  );
  static final RegExp _flutterAssetRegex = RegExp(
    r'^assets/lesson_media/(?:[a-z0-9_-]+/)*[a-z0-9_-]+\.[a-z0-9]+$',
  );

  static const Set<String> _audioExtensions = {'.wav', '.mp3', '.m4a', '.ogg'};
  static const Set<String> _videoExtensions = {'.mp4', '.webm'};
  static const Set<String> _imageExtensions = {'.png', '.jpg', '.jpeg', '.webp'};

  final String id;
  final LessonMediaKind kind;
  final LessonMediaLanguage language;
  final String source;
  final String title;
  final String? titleUz;
  final String? titleRu;
  final String? transcript;
  final String? alt;
  final String? altUz;
  final String? altRu;
  final String? posterImage;
  final String? posterAlt;
  final String? posterAltUz;
  final String? posterAltRu;
  final String? captions;
  final double? durationSeconds;
  final LessonMediaReviewStatus reviewStatus;
  final String? attribution;
  final String? provenance;

  const LessonMedia({
    required this.id,
    required this.kind,
    required this.language,
    required this.source,
    required this.title,
    this.titleUz,
    this.titleRu,
    this.transcript,
    this.alt,
    this.altUz,
    this.altRu,
    this.posterImage,
    this.posterAlt,
    this.posterAltUz,
    this.posterAltRu,
    this.captions,
    this.durationSeconds,
    this.reviewStatus = LessonMediaReviewStatus.approved,
    this.attribution,
    this.provenance,
  });

  bool get isApproved => reviewStatus == LessonMediaReviewStatus.approved;

  String get languageCode {
    switch (language) {
      case LessonMediaLanguage.en:
        return 'en';
      case LessonMediaLanguage.uz:
        return 'uz';
      case LessonMediaLanguage.ru:
        return 'ru';
    }
  }

  String get languageDisplayLabel {
    switch (language) {
      case LessonMediaLanguage.en:
        return 'English';
      case LessonMediaLanguage.uz:
        return 'Özbekça';
      case LessonMediaLanguage.ru:
        return 'Русский';
    }
  }

  String? get resolvedSourceAssetPath => resolveAssetPath(source);

  String? get resolvedPosterAssetPath => resolveAssetPath(posterImage);

  String localizedTitle(String uiLocale) {
    if (uiLocale == 'ru') {
      final ru = titleRu?.trim();
      if (ru != null && ru.isNotEmpty) return ru;
    } else {
      final uz = titleUz?.trim();
      if (uz != null && uz.isNotEmpty) return uz;
    }
    return title;
  }

  String? localizedPosterAlt(String uiLocale) {
    final candidates = uiLocale == 'ru'
        ? [posterAltRu, altRu, posterAlt, alt]
        : [posterAltUz, altUz, posterAlt, alt];
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static String? resolveAssetPath(String? rawPath) {
    if (rawPath == null) return null;
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('..') ||
        trimmed.contains('?') ||
        trimmed.contains('#') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return null;
    }
    if (_canonicalPathRegex.hasMatch(trimmed)) {
      return 'assets/lesson_media/${trimmed.substring('/lesson-media/'.length)}';
    }
    if (_flutterAssetRegex.hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  static LessonMediaKind? _parseKind(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'audio':
        return LessonMediaKind.audio;
      case 'video':
        return LessonMediaKind.video;
      case 'image':
      case 'illustration':
        return LessonMediaKind.image;
      default:
        return null;
    }
  }

  static LessonMediaLanguage? _parseLanguage(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'en':
        return LessonMediaLanguage.en;
      case 'uz':
        return LessonMediaLanguage.uz;
      case 'ru':
        return LessonMediaLanguage.ru;
      default:
        return null;
    }
  }

  static LessonMediaReviewStatus? _parseReviewStatus(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'approved':
        return LessonMediaReviewStatus.approved;
      case 'draft':
        return LessonMediaReviewStatus.draft;
      default:
        return null;
    }
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _hasExtension(String path, Set<String> allowed) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0) return false;
    return allowed.contains(path.substring(dotIndex).toLowerCase());
  }

  static LessonMedia? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);

    final reviewStatus = _parseReviewStatus(
      json['reviewStatus'] ?? json['review_status'],
    );
    if (reviewStatus != LessonMediaReviewStatus.approved) {
      return null;
    }

    final kind = _parseKind(json['kind']);
    final language = _parseLanguage(json['language']);
    if (kind == null || language == null) {
      return null;
    }

    final id = _nonEmptyString(json['id']);
    final rawSource = _nonEmptyString(json['source'] ?? json['canonicalSource']);
    if (id == null || rawSource == null) {
      return null;
    }

    final resolvedSource = resolveAssetPath(rawSource);
    if (resolvedSource == null) {
      return null;
    }

    final titleUz = _nonEmptyString(json['titleUz'] ?? json['title_uz']);
    final titleRu = _nonEmptyString(json['titleRu'] ?? json['title_ru']);
    final title =
        _nonEmptyString(json['title']) ?? titleUz ?? titleRu ?? id;

    final transcript = _nonEmptyString(json['transcript']);
    final durationRaw = json['durationSeconds'] ?? json['duration_seconds'];
    final durationSeconds =
        durationRaw is num ? durationRaw.toDouble() : null;

    final alt = _nonEmptyString(json['alt']);
    final altUz = _nonEmptyString(json['altUz'] ?? json['alt_uz']);
    final altRu = _nonEmptyString(json['altRu'] ?? json['alt_ru']);

    final rawPoster = _nonEmptyString(
      json['posterImage'] ?? json['poster_image'],
    );
    String? validPoster;
    if (rawPoster != null) {
      if (resolveAssetPath(rawPoster) == null ||
          !_hasExtension(rawPoster, _imageExtensions)) {
        return null;
      }
      validPoster = rawPoster;
    }

    final posterAlt = _nonEmptyString(
      json['posterAlt'] ?? json['poster_alt'],
    );
    final posterAltUz = _nonEmptyString(
      json['posterAltUz'] ?? json['poster_alt_uz'],
    );
    final posterAltRu = _nonEmptyString(
      json['posterAltRu'] ?? json['poster_alt_ru'],
    );
    final captions = _nonEmptyString(json['captions']);

    switch (kind) {
      case LessonMediaKind.audio:
        if (!_hasExtension(resolvedSource, _audioExtensions)) return null;
        if (transcript == null || transcript.length > 16000) return null;
        if (durationSeconds == null ||
            !durationSeconds.isFinite ||
            durationSeconds <= 0) {
          return null;
        }
        break;
      case LessonMediaKind.video:
        if (!_hasExtension(resolvedSource, _videoExtensions)) return null;
        if (transcript == null || transcript.length > 16000) return null;
        if (durationSeconds == null ||
            !durationSeconds.isFinite ||
            durationSeconds <= 0) {
          return null;
        }
        if (captions == null ||
            resolveAssetPath(captions) == null ||
            !captions.toLowerCase().endsWith('.vtt')) {
          return null;
        }
        break;
      case LessonMediaKind.image:
        if (!_hasExtension(resolvedSource, _imageExtensions)) return null;
        if (alt == null && altUz == null && altRu == null) return null;
        break;
    }

    return LessonMedia(
      id: id,
      kind: kind,
      language: language,
      source: rawSource,
      title: title,
      titleUz: titleUz,
      titleRu: titleRu,
      transcript: transcript,
      alt: alt ?? altUz ?? altRu,
      altUz: altUz,
      altRu: altRu,
      posterImage: validPoster,
      posterAlt: posterAlt,
      posterAltUz: posterAltUz,
      posterAltRu: posterAltRu,
      captions: captions,
      durationSeconds: durationSeconds,
      reviewStatus: LessonMediaReviewStatus.approved,
      attribution: _nonEmptyString(json['attribution']),
      provenance: _nonEmptyString(json['provenance']),
    );
  }

  factory LessonMedia.fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw const FormatException(
        'Dars media ma’lumotlari tasdiqlanmagan yoki yaroqsiz.',
      );
    }
    return parsed;
  }
}
