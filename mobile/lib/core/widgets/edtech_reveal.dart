import 'package:flutter/material.dart';

class EdTechReveal extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  const EdTechReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 400),
    this.offsetY = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) {
      return child;
    }

    final totalMs = duration.inMilliseconds + (index * 70).clamp(0, 350);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, currentChild) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * offsetY),
            child: currentChild,
          ),
        );
      },
      child: child,
    );
  }
}

