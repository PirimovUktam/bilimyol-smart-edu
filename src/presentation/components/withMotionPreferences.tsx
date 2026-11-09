import type { ComponentType } from 'react';
import { MotionConfig } from 'framer-motion';

export function withMotionPreferences<Props extends object>(View: ComponentType<Props>) {
  return function AnimatedRoute(props: Props) {
    return (
      <MotionConfig reducedMotion="user">
        <View {...props} />
      </MotionConfig>
    );
  };
}
