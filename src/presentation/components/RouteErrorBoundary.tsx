import { translate as t } from '@/core/locales/useTranslation';
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
        <SectionState kind="error" title={t('shell.openFailed')}
          description={t('shell.reloadDescription')}
          onRetry={() => window.location.reload()} />
      </div>
    );
  }
}
