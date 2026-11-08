import { Component, type ReactNode } from 'react';
import { SectionState } from './SectionState';

export class RouteErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <div className="learning-page">
        <SectionState kind="error" title="Sahifani ochib bo‘lmadi"
          description="Sahifani qayta yuklab ko‘ring."
          onRetry={() => window.location.reload()} />
      </div>
    );
  }
}
