import 'package:flutter/material.dart';

import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_typography.dart';

void scrollToBottomSmart(ScrollController controller, {bool force = false}) {
  if (!controller.hasClients) return;

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
  final bool showHelpfulAction;
  final bool isHelpful;
  final VoidCallback? onToggleHelpful;
  final String uiLocale;

  const YolchiBubble({
    super.key,
    required this.id,
    required this.message,
    required this.isYolchi,
    this.isStreaming = false,
    this.isError = false,
    required this.time,
    this.showHelpfulAction = false,
    this.isHelpful = false,
    this.onToggleHelpful,
    this.uiLocale = 'uz',
  });

  @override
  Widget build(BuildContext context) {
    final c = AppSemanticColors.of(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final aiBg = isError ? Color.alphaBlend(c.errorSoft, c.paper) : c.paper;
    final aiBorder = isError ? c.error : c.hairline;
    final bubbleColor = isYolchi ? aiBg : c.ctaPrimary;
    final textColor =
        isYolchi ? (isError ? c.errorText : c.ink) : Colors.white;
    final timeColor =
        isYolchi ? c.slatefine : Colors.white.withValues(alpha: 0.88);
    final helpfulBg =
        isHelpful ? Color.alphaBlend(c.successSoft, c.paper) : c.subtle;
    final helpfulFg = isHelpful ? c.successText : c.slatefine;
    final helpfulBorder =
        isHelpful ? c.success.withValues(alpha: 0.5) : c.hairline;

    final bubbleContent = RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          mainAxisAlignment:
              isYolchi ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isYolchi) _buildAvatar(c, disableAnimations),
            if (isYolchi) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isYolchi ? 4 : 18),
                    bottomRight: Radius.circular(isYolchi ? 18 : 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isYolchi
                          ? Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.04)
                          : c.ctaPrimary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: isYolchi
                      ? Border.all(color: aiBorder, width: 1)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isYolchi
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: message,
                        style: AppTypography.ui(
                          color: textColor,
                          fontSize: 14.5,
                          height: 1.45,
                          letterSpacing: 0.1,
                        ),
                        children: [
                          if (isStreaming)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _StreamingCursor(color: c.brand),
                            ),
                        ],
                      ),
                    ),
                    if (showHelpfulAction &&
                        isYolchi &&
                        !isError &&
                        !isStreaming) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: onToggleHelpful,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: helpfulBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: helpfulBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHelpful
                                    ? Icons.thumb_up_alt_rounded
                                    : Icons.thumb_up_outlined,
                                size: 13,
                                color: helpfulFg,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  uiLocale == 'ru'
                                      ? (isHelpful
                                            ? 'Отмечено полезным'
                                            : 'Полезный ответ')
                                      : (isHelpful
                                            ? 'Foydali deb belgilandi'
                                            : 'Foydali javob'),
                                  style: AppTypography.ui(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: helpfulFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: AppTypography.mono(
                          fontSize: 10,
                          color: timeColor,
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

  Widget _buildAvatar(AppSemanticColors c, bool disableAnimations) {
    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.ctaPrimary, c.ctaPrimaryHover],
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
  final Color color;
  const _StreamingCursor({required this.color});

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
          color: widget.color,
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
    final c = AppSemanticColors.of(context);
    final locCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final platformCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final isRu = locCode == 'ru' || (locCode != 'uz' && platformCode == 'ru');
    return Semantics(
      container: true,
      label: isRu ? 'Yo‘lchi AI печатает...' : 'Yo‘lchi AI yozmoqda...',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: c.brandSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 14,
                color: c.isDark ? c.brandStrong : c.brand,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.subtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.hairline),
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
                              decoration: BoxDecoration(
                                color: c.brand,
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
