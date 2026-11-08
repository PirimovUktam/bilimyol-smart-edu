import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/supabase_config.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../data/services/i_ai_tutor_service.dart';
import '../../data/services/supabase_ai_tutor_service.dart';
import '../../domain/entities/lesson.dart';
import 'yolchi_bubble.dart';

class AITutorScreen extends ConsumerStatefulWidget {
  const AITutorScreen({super.key, this.lesson});

  final Lesson? lesson;

  @override
  ConsumerState<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends ConsumerState<AITutorScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _history = <({String sender, String text})>[];
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      id: 'welcome_0',
      isAI: true,
      text:
          'Salom, men Yo‘lchi AI! Tushunmagan joyingizni yozing yoki yana bir misol so‘rang.',
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

    try {
      final service = ref.read(aiTutorServiceProvider);
      final response = await service.askTutor(
        AskTutorRequest(
          message: query,
          courseId: widget.lesson?.courseId ?? course?.id,
          skillId: widget.lesson?.skillId,
          topic: widget.lesson?.title ?? course?.title,
          history: List.unmodifiable(_history),
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
            text:
                'Kechirasiz, javob berishda xatolik yuz berdi. Qayta urinib ko‘ring.',
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
    final quickChips = [
      'Qoidani sodda tushuntir',
      'Yana bitta misol ber',
      'Mashq savoli ber',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const YolchiAIMascot(size: 36, mood: YolchiMood.explaining),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yo‘lchi AI',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  !SupabaseConfig.hasRemoteConfiguration
                      ? 'Namuna rejimi'
                      : _serviceOnline == true
                      ? 'Pedagogik yordamchi'
                      : _serviceOnline == false
                      ? 'Offline • Qayta urinib ko‘ring'
                      : widget.lesson?.title ?? 'Savolingizni yozing',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: _serviceOnline == true
                        ? const Color(0xFF10B981)
                        : AppColors.textMuted,
                  ),
                ),
              ],
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
                    TextButton.icon(
                      onPressed: () {
                        final failed = _lastFailedPrompt;
                        if (failed != null) {
                          _sendMessage(prompt: failed, retry: true);
                        }
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        'Qayta urinish',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                height: 36,
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
                          color: AppColors.primary,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _controller,
                        maxLength: 4000,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Savol yozing...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                          border: InputBorder.none,
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
                        gradient: AppColors.brandGradient,
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
