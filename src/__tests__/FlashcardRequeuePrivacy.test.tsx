import React from 'react';
import { describe, expect, it, vi } from 'vitest';
import { message } from '@/core/locales/messages';
import type { LessonFlashcard } from '@/domain/entities/Lesson';

const hookSlots: unknown[] = [];
let hookIdx = 0;

function extractTextAndAttrs(node: React.ReactNode): string {
  if (node == null || typeof node === 'boolean') return '';
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  if (Array.isArray(node)) return node.map(extractTextAndAttrs).join(' ');
  if (React.isValidElement(node)) {
    const props = node.props as Record<string, unknown>;
    const chunks: string[] = [];
    if (typeof props['aria-label'] === 'string') chunks.push(props['aria-label']);
    if (typeof props.alt === 'string') chunks.push(props.alt);
    if (typeof props.children !== 'undefined') chunks.push(extractTextAndAttrs(props.children as React.ReactNode));
    return chunks.join(' ');
  }
  return '';
}

function findButtons(node: React.ReactNode, acc: Array<{ text: string; onClick?: () => void }> = []) {
  if (node == null || typeof node !== 'object') return acc;
  if (Array.isArray(node)) {
    node.forEach((child) => findButtons(child, acc));
    return acc;
  }
  if (React.isValidElement(node)) {
    const props = node.props as Record<string, unknown>;
    const isButtonTag = node.type === 'button' || (typeof node.type === 'function' && /Button/.test(node.type.name));
    if (isButtonTag && typeof props.onClick === 'function') {
      acc.push({ text: extractTextAndAttrs(node), onClick: props.onClick as () => void });
    }
    if (props.children) findButtons(props.children as React.ReactNode, acc);
  }
  return acc;
}

vi.mock('@/core/locales/useTranslation', () => ({
  useTranslation: () => ({
    language: 'uz' as const,
    t: (key: Parameters<typeof message>[1], values?: Record<string, string | number>) =>
      message('uz', key, values),
  }),
}));

vi.mock('react', async (importOriginal) => {
  const actual = await importOriginal<typeof import('react')>();
  return {
    ...actual,
    useState: <T,>(initial: T | (() => T)): [T, React.Dispatch<React.SetStateAction<T>>] => {
      const slot = hookIdx++;
      if (!(slot in hookSlots)) {
        hookSlots[slot] = typeof initial === 'function' ? (initial as () => T)() : initial;
      }
      const setState: React.Dispatch<React.SetStateAction<T>> = (next) => {
        hookSlots[slot] =
          typeof next === 'function'
            ? (next as (prev: T) => T)(hookSlots[slot] as T)
            : next;
      };
      return [hookSlots[slot] as T, setState];
    },
    useMemo: <T,>(fn: () => T) => fn(),
    useRef: <T,>(initial: T) => {
      const slot = hookIdx++;
      if (!(slot in hookSlots)) {
        hookSlots[slot] = { current: initial };
      }
      return hookSlots[slot] as React.MutableRefObject<T>;
    },
    useEffect: () => {},
  };
});

describe('FlashcardDeck single-card audio_to_word re-queue privacy', () => {
  it('does not leak card.front into aria-live statusMessage or DOM when re-queueing a single-card deck', async () => {
    const { FlashcardDeck } = await import('@/features/lesson/FlashcardDeck');
    const singleCard: LessonFlashcard[] = [
      {
        id: 'fc_single_desk',
        front: 'Desk',
        backUz: 'Parta',
        backRu: 'Парта',
        ipa: '/desk/',
        example: 'My notebook is on the desk.',
        exampleUz: 'Daftarim parta ustida.',
        exampleRu: 'Моя тетрадь на парте.',
        audioSrc: '/lesson-media/english/a1/a1-m2-classroom-desk.wav',
      },
    ];

    const renderDeck = () => {
      hookIdx = 0;
      return FlashcardDeck({ cards: singleCard, initialMode: 'audio_to_word' });
    };

    // 1. Initial unrevealed state in audio_to_word must not contain 'Desk'
    const initialTree = renderDeck();
    expect(extractTextAndAttrs(initialTree)).not.toContain('Desk');

    // 2. Click "Javobni köriş" -> reveals 'Desk'
    const showBtn = findButtons(initialTree).find((b) => b.text.includes('Javobni köriş'));
    expect(showBtn).toBeDefined();
    showBtn!.onClick!();

    const revealedTree = renderDeck();
    expect(extractTextAndAttrs(revealedTree)).toContain('Desk');

    // 3. Click "Yana maşq qilaman" -> single card returns unrevealed at queue[0] and MUST NOT leak 'Desk'
    const practiceBtn = findButtons(revealedTree).find((b) => b.text.includes('Yana maşq qilaman'));
    expect(practiceBtn).toBeDefined();
    practiceBtn!.onClick!();

    const requeuedTree = renderDeck();
    const requeuedText = extractTextAndAttrs(requeuedTree);
    expect(requeuedText).toContain('Javobni köriş');
    expect(requeuedText).toContain('Yana maşq qilaman');
    expect(requeuedText).not.toContain('Desk');
  });
});
