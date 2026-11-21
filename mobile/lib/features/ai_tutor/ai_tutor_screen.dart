import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/supabase_config.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../data/datasources/demo_ai_data.dart';
import '../../data/datasources/lessons_data.dart';
import '../../data/services/i_ai_tutor_service.dart';
import '../../data/services/supabase_ai_tutor_service.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/entities/question.dart';
import 'yolchi_bubble.dart';

class AITutorScreen extends ConsumerStatefulWidget {
  const AITutorScreen({super.key, this.lesson, this.activeQuestion});

  final Lesson? lesson;
  final Question? activeQuestion;

  @override
  ConsumerState<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends ConsumerState<AITutorScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _history = <({String sender, String text})>[];
  final List<_ChatMessage> _messages = [];
  final Set<String> _helpfulMessageIds = <String>{};
  bool _seededWelcome = false;
  bool _isSending = false;
  bool? _serviceOnline;
  int _requestGeneration = 0;
  int _msgSequence = 1;
  String? _streamingMessageId;
  int _streamingVisibleLength = 0;
  Timer? _streamingTimer;

  String _resolveUiLocale(BuildContext context) {
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru'))
        ? 'ru'
        : 'uz';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seededWelcome) {
      _seededWelcome = true;
      final lang = _resolveUiLocale(context);
      _messages.add(
        _ChatMessage(
          id: 'welcome_0',
          isAI: true,
          text: lang == 'ru'
              ? 'Привет, я Yo‘lchi AI! Напишите, что именно непонятно, или попросите ещё один пример.'
              : 'Salom, men Yo‘lchi AI! Tushunmagan joyingizni yozing yoki yana bir misol so‘rang.',
          time: '',
        ),
      );
    }
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _now() {
    final now = TimeOfDay.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        scrollToBottomSmart(_scrollController, force: force);
      }
    });
  }

  void _startStreamingReveal(String msgId, String fullText) {
    _streamingTimer?.cancel();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations || fullText.length <= 16) {
      setState(() {
        _streamingMessageId = null;
      });
      return;
    }

    setState(() {
      _streamingMessageId = msgId;
      _streamingVisibleLength = 12.clamp(0, fullText.length);
    });

    final step = ((fullText.length / 18).ceil()).clamp(4, 28);
    _streamingTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final nextLen = _streamingVisibleLength + step;
      if (nextLen >= fullText.length) {
        timer.cancel();
        setState(() {
          _streamingMessageId = null;
        });
      } else {
        setState(() {
          _streamingVisibleLength = nextLen;
        });
      }
      _scrollToBottom(force: false);
    });
  }

  Future<void> _sendMessage({String? prompt, bool retry = false}) async {
    final query = (prompt ?? _controller.text).trim();
    if (query.isEmpty || _isSending) return;
    final requestGeneration = ++_requestGeneration;

    setState(() {
      if (retry && _messages.length >= 2) {
        _messages.removeRange(_messages.length - 2, _messages.length);
      }
      _messages.add(
        _ChatMessage(
          id: 'msg_${_msgSequence++}',
          isAI: false,
          text: query,
          time: _now(),
        ),
      );
      _lastFailedPrompt = null;
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom(force: true);

    final course = ref.read(courseStateNotifierProvider).activeCourse;
    final lessonState = ref.read(lessonSessionNotifierProvider);
    final roadmap = ref.read(roadmapStateNotifierProvider).valueOrNull;
    final profile = ref.read(learnerStateNotifierProvider).valueOrNull;

    final lang = _resolveUiLocale(context);
    final effectiveCourseId =
        widget.lesson?.courseId ?? course?.id ?? lessonState.lesson?.courseId;
    final activeNode = (roadmap != null && roadmap.courseId == effectiveCourseId)
        ? roadmap.nodes.where((n) => n.id == roadmap.activeNodeId).firstOrNull
        : null;
    final effectiveLesson =
        widget.lesson ??
        (lessonState.lesson?.courseId == effectiveCourseId
            ? lessonState.lesson
            : null) ??
        (activeNode?.targetLessonId != null
            ? seedLessons[activeNode!.targetLessonId!]
            : null);
    final resolvedQuestion =
        widget.activeQuestion ??
        (lessonState.lesson != null &&
                lessonState.lesson!.id == effectiveLesson?.id &&
                lessonState.currentStepIndex >= 0 &&
                lessonState.currentStepIndex < lessonState.lesson!.steps.length
            ? lessonState
                  .lesson!
                  .steps[lessonState.currentStepIndex]
                  .interactiveQuestion
            : null);
    final effectiveSkillId =
        resolvedQuestion?.skillId ??
        effectiveLesson?.skillId ??
        activeNode?.skillId;
    final effectiveTopic =
        effectiveLesson?.localizedTitle(lang) ??
        activeNode?.localizedTitle(lang) ??
        course?.localizedTitle(lang);
    int? learnerScore;
    if (effectiveCourseId != null && effectiveSkillId != null) {
      learnerScore =
          profile?.scoresByCourse[effectiveCourseId]?[effectiveSkillId]?.score;
    }

    var recentMistakes = const <String>[];
    try {
      final attempts = await ref
          .read(learnerRepositoryProvider)
          .getAnswerAttempts(12);
      final mistakeLabels = <String>{};
      for (final attempt in attempts) {
        if (effectiveCourseId != null && attempt.courseId != effectiveCourseId) {
          continue;
        }
        if (!attempt.isCorrect) {
          final skillName = findSkillById(attempt.skillId)?.name;
          if (skillName != null && skillName.trim().isNotEmpty) {
            mistakeLabels.add(skillName);
          }
        }
      }
      recentMistakes = mistakeLabels.take(4).toList(growable: false);
    } catch (_) {
      recentMistakes = const [];
    }

    try {
      final service = ref.read(aiTutorServiceProvider);
      final response = await service.askTutor(
        AskTutorRequest(
          message: query,
          courseId: effectiveCourseId,
          skillId: effectiveSkillId,
          lessonId: effectiveLesson?.id,
          topic: effectiveTopic,
          language: lang,
          history: List.unmodifiable(_history),
          learnerScore: learnerScore,
          recentMistakes: recentMistakes,
          questionId: resolvedQuestion?.id,
          questionPrompt: resolvedQuestion?.localizedText(lang),
          questionSkillId: resolvedQuestion?.skillId,
        ),
      );
      if (!mounted || requestGeneration != _requestGeneration) return;
      final aiMsgId = 'msg_${_msgSequence++}';
      setState(() {
        _isSending = false;
        _serviceOnline = response.isAiGenerated;
        _history.addAll([
          (sender: 'user', text: _historyText(query)),
          (sender: 'ai', text: _historyText(response.answer)),
        ]);
        if (_history.length > 6) _history.removeRange(0, _history.length - 6);
        _messages.add(
          _ChatMessage(
            id: aiMsgId,
            isAI: true,
            text: response.answer,
            time: _now(),
          ),
        );
      });
      _startStreamingReveal(aiMsgId, response.answer);
    } on AITutorUnavailableException catch (e) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _isSending = false;
        _serviceOnline = false;
        _lastFailedPrompt = query;
        _messages.add(
          _ChatMessage(
            id: 'msg_${_msgSequence++}',
            isAI: true,
            text: e.message,
            time: _now(),
            isError: true,
          ),
        );
      });
    } catch (_) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _isSending = false;
        _serviceOnline = false;
        _lastFailedPrompt = query;
        _messages.add(
          _ChatMessage(
            id: 'msg_${_msgSequence++}',
            isAI: true,
            text: lang == 'ru'
                ? 'Извините, произошла ошибка при ответе. Попробуйте ещё раз.'
                : 'Kechirasiz, javob berishda xatolik yuz berdi. Qayta urinib ko‘ring.',
            time: _now(),
            isError: true,
          ),
        );
      });
    }
    _scrollToBottom(force: false);
  }

  String? _lastFailedPrompt;

  String _historyText(String value) =>
      value.length > 800 ? value.substring(0, 800) : value;

  @override
  Widget build(BuildContext context) {
    final lang = _resolveUiLocale(context);
    final quickChips = lang == 'ru'
        ? const [
            'Объясни правило проще',
            'Дай ещё один пример',
            'Дай тренировочный вопрос',
          ]
        : const [
            'Qoidani sodda tushuntir',
            'Yana bitta misol ber',
            'Mashq savoli ber',
          ];

    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.bg(context),
          appBar: AppBar(
            toolbarHeight: isLargeText
                ? ((_serviceOnline == null && widget.lesson != null) ? 212 : 112)
                : null,
            title: Row(
              children: [
                const YolchiAIMascot(size: 36, mood: YolchiMood.explaining),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yo‘lchi AI',
                        softWrap: true,
                        maxLines: isLargeText ? null : 1,
                        overflow: isLargeText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        !SupabaseConfig.hasRemoteConfiguration
                            ? (lang == 'ru' ? 'Демо-режим' : 'Namuna rejimi')
                            : _serviceOnline == true
                            ? (lang == 'ru'
                                  ? 'Педагогический помощник'
                                  : 'Pedagogik yordamchi')
                            : _serviceOnline == false
                            ? (lang == 'ru'
                                  ? 'Офлайн • Попробуйте снова'
                                  : 'Offline • Qayta urinib ko‘ring')
                            : widget.lesson?.localizedTitle(lang) ??
                                  (lang == 'ru'
                                      ? 'Введите ваш вопрос'
                                      : 'Savolingizni yozing'),
                        softWrap: true,
                        maxLines: isLargeText ? null : 1,
                        overflow: isLargeText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          color: _serviceOnline == true
                              ? AppColors.successTextOnTint(context)
                              : AppColors.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: widget.lesson == null
              ? const BilimYolBottomNav(currentIndex: 2)
              : null,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isStreaming = _streamingMessageId == msg.id;
                      final visibleText = isStreaming
                          ? msg.text.substring(
                              0,
                              _streamingVisibleLength.clamp(0, msg.text.length),
                            )
                          : msg.text;
                      return YolchiBubble(
                        key: ValueKey(msg.id),
                        id: msg.id,
                        message: visibleText,
                        isYolchi: msg.isAI,
                        isStreaming: isStreaming,
                        isError: msg.isError,
                        time: msg.time,
                        uiLocale: lang,
                        showHelpfulAction:
                            msg.isAI && !msg.isError && msg.id != 'welcome_0',
                        isHelpful: _helpfulMessageIds.contains(msg.id),
                        onToggleHelpful: () {
                          setState(() {
                            if (!_helpfulMessageIds.add(msg.id)) {
                              _helpfulMessageIds.remove(msg.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),

                if (_isSending) const YolchiTypingIndicator(),

                if (!_isSending && _lastFailedPrompt != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: TextButton.icon(
                            onPressed: () {
                              final failed = _lastFailedPrompt;
                              if (failed != null) {
                                _sendMessage(prompt: failed, retry: true);
                              }
                            },
                            icon: Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: AppColors.primaryAccentOnSurface(context),
                            ),
                            label: Text(
                              lang == 'ru' ? 'Повторить' : 'Qayta urinish',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryAccentOnSurface(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SizedBox(
                    height: isLargeText ? 52 : 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quickChips.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        return ActionChip(
                          label: Text(
                            quickChips[i],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryAccentOnSurface(context),
                            ),
                          ),
                          backgroundColor: AppColors.surfaceColor(context),
                          side: BorderSide(
                            color: AppColors.primaryAccentOnSurface(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onPressed: _isSending
                              ? null
                              : () => _sendMessage(prompt: quickChips[i]),
                        );
                      },
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.surfaceColor(context),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bg(context),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.borderColor(context),
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            maxLength: 4000,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textPrimaryColor(context),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: lang == 'ru'
                                  ? 'Введите ваш вопрос...'
                                  : 'Savol yozing...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textMutedColor(context),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _isSending ? null : () => _sendMessage(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryHover,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String id;
  final bool isAI;
  final String text;
  final String time;
  final bool isError;

  _ChatMessage({
    required this.id,
    required this.isAI,
    required this.text,
    required this.time,
    this.isError = false,
  });
}
