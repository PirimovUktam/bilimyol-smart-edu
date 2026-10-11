import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/bilimyol_bottom_nav.dart';
import '../../core/widgets/yolchi_ai_mascot.dart';

class AITutorScreen extends ConsumerStatefulWidget {
  const AITutorScreen({super.key});

  @override
  ConsumerState<AITutorScreen> createState() => _AITutorScreenState();
}

class _AITutorScreenState extends ConsumerState<AITutorScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      isAI: true,
      text:
          'Salom, men Yo‘lchi AI! Savollaringizga javob beraman, xatolaringizni tushuntiraman va sizga mos tavsiyalar beraman. 🤖✨',
      time: '11:00',
    ),
    _ChatMessage(
      isAI: false,
      text: 'Men bu savolda xatoga yo‘l qo‘ydim. Nega noto‘g‘ri bo‘ldi?',
      time: '11:01',
    ),
    _ChatMessage(
      isAI: true,
      text:
          'Keling, birgalikda ko‘rib chiqaylik! Siz kasrlarni taqqoslashda surat va maxrajni to‘g‘ri hisoblagansiz, ammo bu yerda avval kasrlarni yagona maxrajga keltirish kerak edi.',
      hasVisualMath: true,
      time: '11:01',
    ),
  ];

  void _sendMessage([String? prompt]) {
    final query = prompt ?? _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          isAI: false,
          text: query,
          time: '11:02',
        ),
      );
    });
    _controller.clear();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            isAI: true,
            text:
                'Ajoyib savol! Matematik qoidaga binoan 1/2 kasri 2/4 ga teng, chunki ikkalasini ham 2 ga qisqartirish mumkin. Buni darsda amaliy sinab ko‘ramizmi?',
            time: '11:02',
          ),
        );
      });
    });
  }

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
                  'Online • Pedagogik yordamchi',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    color: const Color(0xFF10B981),
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
            // Chat Stream
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _MessageBubble(message: msg);
                },
              ),
            ),

            // Quick Prompts Chips
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
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () => _sendMessage(quickChips[i]),
                    );
                  },
                ),
              ),
            ),

            // Input pill
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
                          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textMuted),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendMessage(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
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
  final bool hasVisualMath;

  _ChatMessage({
    required this.isAI,
    required this.text,
    required this.time,
    this.hasVisualMath = false,
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAI ? Colors.white : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAI ? 4 : 20),
            bottomRight: Radius.circular(isAI ? 20 : 4),
          ),
          border: isAI ? Border.all(color: AppColors.cardBorder) : null,
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
                color: isAI ? AppColors.textPrimary : Colors.white,
                height: 1.35,
              ),
            ),
            if (message.hasVisualMath) ...[
              const SizedBox(height: 10),
              // Reference 2 visual fraction box: 1/2 = 2/4
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('1 / 2', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Container(color: AppColors.primary)),
                          Expanded(child: Container(color: Colors.white)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('=', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    const Text('2 / 4', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 20,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Container(color: AppColors.primary)),
                          Expanded(child: Container(color: AppColors.primary)),
                          Expanded(child: Container(color: Colors.white)),
                          Expanded(child: Container(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
