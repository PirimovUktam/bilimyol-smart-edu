import { translate as t } from '@/core/locales/useTranslation';
import { useTranslation } from '@/core/locales/useTranslation';
import { memo } from 'react';
import { motion } from 'framer-motion';
import { Bot, ThumbsDown, ThumbsUp, User } from 'lucide-react';
import { IconButton } from '@/presentation/components/IconButton';
import { LearningText } from '@/presentation/components/LearningText';

export interface MessageProps {
  id: string;
  sender: 'user' | 'yolchi' | 'ai';
  text: string;
  timestamp: string;
  isStreaming?: boolean;
  feedback?: 'helpful' | 'unhelpful';
  onFeedback?: (id: string, value: 'helpful' | 'unhelpful') => void;
}

export const YolchiMessageBubble = memo(({
  id,
  sender,
  text,
  timestamp,
  isStreaming = false,
  feedback,
  onFeedback,
}: MessageProps) => {
  const { t } = useTranslation();
  const isYolchi = sender === 'yolchi' || sender === 'ai';

  return (
    <motion.article
      initial={{ opacity: 0, y: 16, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{
        type: 'spring',
        stiffness: 400,
        damping: 30,
        mass: 0.8,
      }}
      className={`flex w-full gap-3 py-2 ${isYolchi ? 'justify-start' : 'justify-end'}`}
    >
      {isYolchi && (
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 0.05, type: 'spring', stiffness: 500, damping: 25 }}
          aria-hidden="true"
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-gradient-to-tr from-indigo-600 to-indigo-400 text-white shadow-md shadow-indigo-500/20"
        >
          <Bot size={18} />
        </motion.div>
      )}

      <div
        className={`relative max-w-[82%] sm:max-w-[70%] rounded-2xl px-4 py-3 shadow-md ${
          isYolchi
            ? 'bg-paper border border-hairline text-ink rounded-tl-sm'
            : 'bg-gradient-to-r from-[#7C3AED] to-[#EC4899] text-white rounded-tr-sm shadow-purple-600/20'
        }`}
      >
        <header className="mb-1 flex items-center justify-between gap-3 text-[11px] font-bold">
          <span className={isYolchi ? 'text-cyan-300' : 'text-purple-100'}>
            {isYolchi ? 'Yo‘lchi AI' : 'Siz'}
          </span>
        </header>

        {isYolchi && !isStreaming ? (
          <div className="text-sm leading-relaxed tracking-normal">
            <LearningText text={text} />
          </div>
        ) : (
          <p className="whitespace-pre-wrap break-words text-sm leading-relaxed tracking-normal">
            {text}
            {isStreaming && (
              <motion.span
                animate={{ opacity: [0, 1, 0] }}
                transition={{ repeat: Infinity, duration: 0.8, ease: 'easeInOut' }}
                className="ml-1 inline-block h-3.5 w-1.5 translate-y-[2px] rounded-full bg-indigo-500"
              />
            )}
          </p>
        )}

        <div className="mt-1.5 flex items-center justify-between gap-2">
          {isYolchi && onFeedback ? (
            <div aria-label={t('tutor.rate')} className="flex gap-1">
              <IconButton
                label={t('tutor.helpful')}
                aria-pressed={feedback === 'helpful'}
                className={feedback === 'helpful' ? 'bg-sand text-brand' : ''}
                onClick={() => onFeedback(id, 'helpful')}
              >
                <ThumbsUp aria-hidden="true" className="size-3.5" />
              </IconButton>
              <IconButton
                label={t('tutor.notHelpful')}
                aria-pressed={feedback === 'unhelpful'}
                className={feedback === 'unhelpful' ? 'bg-sand text-brand' : ''}
                onClick={() => onFeedback(id, 'unhelpful')}
              >
                <ThumbsDown aria-hidden="true" className="size-3.5" />
              </IconButton>
            </div>
          ) : (
            <span />
          )}

          <time
            className={`block text-[10px] ${
              isYolchi ? 'text-slate-400' : 'text-indigo-200'
            } text-right`}
          >
            {timestamp}
          </time>
        </div>
      </div>

      {!isYolchi && (
        <div
          aria-hidden="true"
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-slate-100 text-slate-600"
        >
          <User size={18} />
        </div>
      )}
    </motion.article>
  );
});

YolchiMessageBubble.displayName = 'YolchiMessageBubble';

export const YolchiTypingIndicator = () => (
  <motion.div
    role="status"
    aria-label={t('tutor.thinking')}
    initial={{ opacity: 0, y: 10 }}
    animate={{ opacity: 1, y: 0 }}
    exit={{ opacity: 0, scale: 0.9 }}
    className="flex items-center gap-2 p-2"
  >
    <div
      aria-hidden="true"
      className="flex h-7 w-7 items-center justify-center rounded-lg bg-indigo-50 text-indigo-600"
    >
      <Bot size={14} />
    </div>
    <div className="flex items-center gap-1.5 rounded-2xl bg-slate-100 px-3.5 py-2">
      {[0, 0.18, 0.36].map((delay, index) => (
        <motion.span
          key={index}
          animate={{ y: [0, -5, 0], opacity: [0.4, 1, 0.4] }}
          transition={{
            repeat: Infinity,
            duration: 1,
            delay,
            ease: 'easeInOut',
          }}
          className="h-1.5 w-1.5 rounded-full bg-indigo-500"
        />
      ))}
    </div>
    <span className="sr-only">{t('tutor.thinking')}</span>
  </motion.div>
);

