import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_badge.dart';
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
  final Set<String> _helpfulMessageIds = <String>{};
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      id: 'welcome_0',
      isAI: true,
      text: '',
      time: '',
    ),
  ];
  bool _isSending = false;
  bool? _serviceOnline;
  int _requestGeneration = 0;
  int _msgSequence = 1;
  String? _streamingMessageId;
  int _streamingVisibleLength = 0;
  Timer? _streamingTimer;
  String? _lastFailedPrompt;

  static AppStrings _resolveStrings(BuildContext context) {
    final registered = Localizations.of<AppStrings>(context, AppStrings);
    if (registered != null) return registered;
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    return isRu ? AppStrings.ru : AppStrings.uz;
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

    final s = _resolveStrings(context);
    final lang = s.isRu ? 'ru' : 'uz';
    final course = ref.read(courseStateNotifierProvider).activeCourse;
    final lessonState = ref.read(lessonSessionNotifierProvider);
    final roadmap = ref.read(roadmapStateNotifierProvider).valueOrNull;
    final profile = ref.read(learnerStateNotifierProvider).valueOrNull;

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
            text: s.aiTutorGenericError,
            time: _now(),
            isError: true,
          ),
        );
      });
    }
    _scrollToBottom(force: false);
  }

  String _historyText(String value) =>
      value.length > 800 ? value.substring(0, 800) : value;

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final s = _resolveStrings(context);
    final lang = s.isRu ? 'ru' : 'uz';
    final quickChips = s.aiTutorQuickPrompts;
    final course = ref.watch(courseStateNotifierProvider).activeCourse;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 100;
    final showChips = !keyboardOpen;
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.35;

    final String statusLabel;
    final AppBadgeVariant statusVariant;
    if (!SupabaseConfig.hasRemoteConfiguration) {
      statusLabel = s.aiTutorStatusDemo;
      statusVariant = AppBadgeVariant.blue;
    } else if (_serviceOnline == false) {
      statusLabel = s.aiTutorStatusOffline;
      statusVariant = AppBadgeVariant.rose;
    } else if (_serviceOnline == true) {
      statusLabel = s.aiTutorStatusOnline;
      statusVariant = AppBadgeVariant.emerald;
    } else {
      statusLabel = s.aiTutorStatusPrompt;
      statusVariant = AppBadgeVariant.slate;
    }

    final headerSubtitle = widget.lesson?.localizedTitle(lang) ??
        (course != null
            ? '${s.aiTutorSubtitle} · ${s.localizedCourseTitle(course)}'
            : s.aiTutorSubtitle);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        includeSemantics: false,
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: isLargeText
                ? (widget.lesson != null ? 156 : 84)
                : null,
            title: Row(
              children: [
                const YolchiAIMascot(size: 34, mood: YolchiMood.explaining),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.navAiTutor,
                        softWrap: true,
                        maxLines: isLargeText ? null : 1,
                        overflow: isLargeText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        headerSubtitle,
                        softWrap: true,
                        maxLines: isLargeText ? null : 1,
                        overflow: isLargeText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: AppTypography.ui(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: _serviceOnline == true
                              ? c.successText
                              : c.slatefine,
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                    final isUltraTight = constraints.maxHeight < 300;
                    final isCompactVertical =
                        constraints.maxHeight < 440 && textScale > 1.3;
                    final showStatusBadge =
                        !keyboardOpen && !isUltraTight && !isCompactVertical;
                    final useHorizontalChips =
                        constraints.maxHeight < 460 || textScale > 1.3;

                    Widget buildMessageList({required bool shrinkWrap}) {
                      return ListView.builder(
                        controller: shrinkWrap ? null : _scrollController,
                        shrinkWrap: shrinkWrap,
                        physics: shrinkWrap
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        padding: EdgeInsets.symmetric(
                          vertical: shrinkWrap ? 6 : 12,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final resolvedText = msg.id == 'welcome_0'
                              ? s.aiTutorWelcomeMessage
                              : msg.text;
                          final isStreaming = _streamingMessageId == msg.id;
                          final visibleText = isStreaming
                              ? resolvedText.substring(
                                  0,
                                  _streamingVisibleLength.clamp(
                                    0,
                                    resolvedText.length,
                                  ),
                                )
                              : resolvedText;
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
                      );
                    }

                    final retryButton = (!_isSending && _lastFailedPrompt != null)
                        ? Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isUltraTight ? 0 : 4,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  foregroundColor: c.isDark
                                      ? c.brandStrong
                                      : c.brand,
                                ),
                                onPressed: () {
                                  final failed = _lastFailedPrompt;
                                  if (failed != null) {
                                    _sendMessage(prompt: failed, retry: true);
                                  }
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 17),
                                label: Text(
                                  s.retry,
                                  style: AppTypography.ui(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: c.isDark ? c.brandStrong : c.brand,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : null;

                    final composer = Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isUltraTight ? 6 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.paper,
                        border: Border(top: BorderSide(color: c.hairline)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Semantics(
                              textField: true,
                              label: s.aiTutorInputHint,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: c.subtle,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: c.hairline),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  maxLength: 4000,
                                  minLines: 1,
                                  maxLines: isUltraTight
                                      ? 1
                                      : (keyboardOpen || isCompactVertical
                                            ? 2
                                            : 4),
                                  textInputAction: TextInputAction.send,
                                  style: AppTypography.ui(
                                    fontSize: 13.5,
                                    color: c.ink,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: false,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: isUltraTight ? 6 : 10,
                                    ),
                                    hintText: s.aiTutorInputHint,
                                    hintStyle: AppTypography.ui(
                                      fontSize: 13.5,
                                      color: c.slatefine,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Semantics(
                            button: true,
                            label: s.aiTutorSendTooltip,
                            child: Tooltip(
                              message: s.aiTutorSendTooltip,
                              child: Material(
                                type: MaterialType.transparency,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: _isSending
                                      ? null
                                      : () => _sendMessage(),
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: _isSending
                                            ? [
                                                c.ctaPrimary.withValues(
                                                  alpha: 0.55,
                                                ),
                                                c.ctaPrimaryHover.withValues(
                                                  alpha: 0.55,
                                                ),
                                              ]
                                            : [
                                                c.ctaPrimary,
                                                c.ctaPrimaryHover,
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    );

                    Widget buildQuickChip(String chip) {
                      return ActionChip(
                        label: Text(
                          chip,
                          style: AppTypography.ui(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.isDark ? c.brandStrong : c.brand,
                          ),
                        ),
                        backgroundColor: c.paper,
                        side: BorderSide(
                          color: c.isDark ? c.brandStrong : c.brand,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        onPressed: _isSending
                            ? null
                            : () => _sendMessage(prompt: chip),
                      );
                    }

                    final Widget? chipsStrip = !showChips
                        ? null
                        : useHorizontalChips
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  for (var i = 0; i < quickChips.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    buildQuickChip(quickChips[i]),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: quickChips.map(buildQuickChip).toList(),
                              ),
                            ),
                          );

                    if (isUltraTight) {
                      return SingleChildScrollView(
                        reverse: true,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              buildMessageList(shrinkWrap: true),
                              if (_isSending) const YolchiTypingIndicator(),
                              ?retryButton,
                              ?chipsStrip,
                              composer,
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        if (showStatusBadge)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: AppBadge(
                                text: statusLabel,
                                variant: statusVariant,
                              ),
                            ),
                          ),
                        Expanded(child: buildMessageList(shrinkWrap: false)),
                        if (_isSending) const YolchiTypingIndicator(),
                        ?retryButton,
                        ?chipsStrip,
                        composer,
                      ],
                    );
                  },
                ),
              ),
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
