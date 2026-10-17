import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';
import '../../data/services/i_ai_tutor_service.dart';
import '../../data/services/supabase_ai_tutor_service.dart';

class AITutorScreen extends ConsumerStatefulWidget {
  const AITutorScreen({super.key});

  @override
  ConsumerState<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends ConsumerState<AITutorScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      isAI: true,
      text:
          'Salom, men Yo‘lchi AI! Savollaringizga javob beraman, xatolaringizni tushuntiraman va sizga mos tavsiyalar beraman. 🤖✨',
      time: '',
    ),
  ];
  bool _isSending = false;
  bool? _serviceOnline;
  int _requestGeneration = 0;

  @override
  void dispose() {
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? prompt]) async {
    final query = (prompt ?? _controller.text).trim();
    if (query.isEmpty || _isSending) return;
    final requestGeneration = ++_requestGeneration;

    setState(() {
      _messages.add(_ChatMessage(isAI: false, text: query, time: _now()));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final course = ref.read(courseStateNotifierProvider).activeCourse;

    try {
      final service = ref.read(aiTutorServiceProvider);
      final response = await service.askTutor(
        AskTutorRequest(
          message: query,
          courseId: course?.id,
          topic: course?.title,
        ),
      );
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _isSending = false;
        _lastFailedPrompt = null;
        _serviceOnline = response.isAiGenerated;
        _messages.add(
          _ChatMessage(isAI: true, text: response.answer, time: _now()),
        );
      });
    } on AITutorUnavailableException catch (e) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _isSending = false;
        _serviceOnline = false;
        _lastFailedPrompt = query;
        _messages.add(
          _ChatMessage(
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
            isAI: true,
            text:
                'Kechirasiz, javob berishda xatolik yuz berdi. Qayta urinib ko‘ring.',
            time: _now(),
            isError: true,
          ),
        );
      });
    }
    _scrollToBottom();
  }

  String? _lastFailedPrompt;

  @override
  Widget build(BuildContext context) {
    final quickChips = [
      'Qoidani sodda tushuntir 💡',
      'Yana bitta misol ber ✍️',
      'Test savoli ber 🎯',
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
                  _serviceOnline == true
                      ? 'Online • Pedagogik yordamchi'
                      : _serviceOnline == false
                      ? 'Offline • Qayta urinib ko‘ring'
                      : 'Ulanish tekshirilmoqda...',
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
      bottomNavigationBar: const BilimYolBottomNav(currentIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _MessageBubble(message: msg);
                },
              ),
            ),

            if (_isSending)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Yo‘lchi AI yozmoqda...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

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
                        setState(() => _lastFailedPrompt = null);
                        if (failed != null) _sendMessage(failed);
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
                          : () => _sendMessage(quickChips[i]),
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
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        decoration: InputDecoration(
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
  final bool isAI;
  final String text;
  final String time;
  final bool isError;

  _ChatMessage({
    required this.isAI,
    required this.text,
    required this.time,
    this.isError = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isAI = message.isAI;

    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAI
              ? (message.isError ? AppColors.errorLight : Colors.white)
              : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAI ? 4 : 20),
            bottomRight: Radius.circular(isAI ? 20 : 4),
          ),
          border: isAI
              ? Border.all(
                  color: message.isError
                      ? AppColors.error.withValues(alpha: 0.3)
                      : AppColors.cardBorder,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: isAI ? FontWeight.w600 : FontWeight.w700,
                color: isAI
                    ? (message.isError
                          ? AppColors.error
                          : AppColors.textPrimary)
                    : Colors.white,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
