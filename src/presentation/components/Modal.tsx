import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useId, useRef, type ReactNode } from 'react';
import { X } from 'lucide-react';
import { IconButton } from './IconButton';

interface ModalProps {
  isOpen: boolean;
  onClose?: () => void;
  title?: ReactNode;
  children: ReactNode;
  maxWidth?: 'sm' | 'md' | 'lg' | 'xl';
  showClose?: boolean;
  labelledBy?: string;
  dismissable?: boolean;
}

const widths = { sm: 'max-w-sm', md: 'max-w-md', lg: 'max-w-2xl', xl: 'max-w-4xl' };

export function Modal({
  isOpen, onClose, title, children, maxWidth = 'lg', showClose = true, labelledBy, dismissable = true,
}: ModalProps) {
  const { t } = useTranslation();
  const dialog = useRef<HTMLDialogElement>(null);
  const id = useId();
  useEffect(() => {
    const node = dialog.current;
    if (!isOpen || !node) return;
    const overflow = document.body.style.overflow;
    node.showModal();
    document.body.style.overflow = 'hidden';
    return () => {
      node.close();
      document.body.style.overflow = overflow;
    };
  }, [isOpen]);

  return (
    <dialog
      ref={dialog}
      aria-labelledby={labelledBy ?? (title ? id : undefined)}
      aria-label={!labelledBy && !title ? t('shell.dialog') : undefined}
      className={'m-auto max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] overflow-y-auto rounded-panel border border-hairline bg-paper p-0 text-ink shadow-pop backdrop:bg-navy/65 ' + widths[maxWidth]}
      onCancel={(event) => { event.preventDefault(); if (dismissable) onClose?.(); }}
      onClick={(event) => { if (dismissable && event.target === event.currentTarget) onClose?.(); }}
      onKeyDown={(event) => {
        if (event.key !== 'Tab') return;
        const controls = Array.from(event.currentTarget.querySelectorAll<HTMLElement>(
          'button, a[href], input, select, textarea, [tabindex]',
        )).filter((control) => control.tabIndex >= 0 && !control.matches(':disabled') && control.getClientRects().length > 0);
        const first = controls[0];
        const last = controls.at(-1);
        if (!first || !last) return;
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }}
    >
      <div className="p-5 sm:p-6">
        {(title || (showClose && dismissable)) && (
          <div className="mb-3 flex items-start justify-between gap-3">
            {title ? <h2 id={id} className="font-display text-xl font-bold">{title}</h2> : <span />}
            {showClose && dismissable && <IconButton label={t('courses.close')} onClick={onClose}><X aria-hidden="true" className="size-5" /></IconButton>}
          </div>
        )}
        {children}
      </div>
    </dialog>
  );
}
