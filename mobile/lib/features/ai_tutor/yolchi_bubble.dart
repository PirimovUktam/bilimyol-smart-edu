import 'package:flutter/material.dart';

void scrollToBottomSmart(ScrollController controller, {bool force = false}) {
  if (!controller.hasClients) return;

  // Agar foydalanuvchi eng pastdan 120px dan ortiq yuqorida bo'lmasa, pastga skroll qilinadi
  final maxScroll = controller.position.maxScrollExtent;
  final currentScroll = controller.position.pixels;

  if (force || maxScroll - currentScroll <= 120) {
    controller.animateTo(
      maxScroll,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
    );
  }
}

class YolchiBubble extends StatelessWidget {
  final String id;
  final String message;
  final bool isYolchi;
  final bool isStreaming;
  final bool isError;
  final String time;

  const YolchiBubble({
    super.key,
    required this.id,
    required this.message,
    required this.isYolchi,
    this.isStreaming = false,
    this.isError = false,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final bubbleContent = RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment: isYolchi
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isYolchi) _buildAvatar(disableAnimations),
            if (isYolchi) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isYolchi
                      ? (isError ? const Color(0xFFFEF2F2) : Colors.white)
                      : const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isYolchi ? 2 : 18),
                    bottomRight: Radius.circular(isYolchi ? 18 : 2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isYolchi
                          ? Colors.black.withValues(alpha: 0.04)
                          : const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: isYolchi
                      ? Border.all(
                          color: isError
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isYolchi
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: message,
                        style: TextStyle(
                          color: isYolchi
                              ? (isError
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF0F172A))
                              : Colors.white,
                          fontSize: 14.5,
                          height: 1.45,
                          letterSpacing: 0.1,
                        ),
                        children: [
                          if (isStreaming)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _StreamingCursor(),
                            ),
                        ],
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isYolchi
                              ? const Color(0xFF94A3B8)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (disableAnimations) {
      return KeyedSubtree(key: ValueKey(id), child: bubbleContent);
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey(id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: bubbleContent,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildAvatar(bool disableAnimations) {
    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
    );

    if (disableAnimations) return avatar;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: avatar,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _controller.value = 1.0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        width: 6,
        height: 13,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class YolchiTypingIndicator extends StatefulWidget {
  const YolchiTypingIndicator({super.key});

  @override
  State<YolchiTypingIndicator> createState() => _YolchiTypingIndicatorState();
}

class _YolchiTypingIndicatorState extends State<YolchiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yo‘lchi AI yozmoqda...',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  const delays = [0.0, 0.18, 0.36];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(delays.length, (i) {
                      final phase = (_controller.value - delays[i]) % 1.0;
                      final wave = phase < 0.5
                          ? (phase * 2)
                          : (1.0 - (phase - 0.5) * 2);
                      return Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        child: Transform.translate(
                          offset: Offset(0, -4 * wave),
                          child: Opacity(
                            opacity: (0.4 + 0.6 * wave).clamp(0.4, 1.0),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

