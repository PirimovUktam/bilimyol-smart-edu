import { createHash } from 'node:crypto';
import { existsSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { permuteQuestionOptions } from '@/core/utils/questionOptionOrder';
import { SEED_COURSES } from '@/data/datasources/courses';
import {
  ENGLISH_A1_CURRICULUM,
  ENGLISH_A1_LESSONS,
  ENGLISH_A1_QUESTIONS,
  ENGLISH_A1_ROADMAP_NODES,
} from '@/data/datasources/english/a1';
import {
  ENGLISH_A2_CURRICULUM,
  ENGLISH_A2_LESSONS,
  ENGLISH_A2_QUESTIONS,
  ENGLISH_A2_ROADMAP_NODES,
} from '@/data/datasources/english/a2';
import {
  ENGLISH_B1_CURRICULUM,
  ENGLISH_B1_LESSONS,
  ENGLISH_B1_QUESTIONS,
  ENGLISH_B1_ROADMAP_NODES,
} from '@/data/datasources/english/b1';
import {
  ENGLISH_CEFR_DISCLAIMERS,
  ENGLISH_CEFR_LEVELS,
  ENGLISH_CEFR_LEVEL_ORDER,
  ENGLISH_CEFR_SKELETON,
  ENGLISH_PRE_A1_ALIGNMENT,
} from '@/data/datasources/english/curriculum';
import {
  ENGLISH_A1_FLASHCARDS,
  ENGLISH_A2_FLASHCARDS,
  ENGLISH_ALL_FLASHCARDS,
  ENGLISH_B1_FLASHCARDS,
} from '@/data/datasources/english/flashcards';
import {
  ENGLISH_ALL_LESSONS,
  ENGLISH_ALL_LESSONS_ORDER,
  ENGLISH_ALL_QUESTIONS,
  ENGLISH_ALL_ROADMAP_NODES,
} from '@/data/datasources/english';
import {
  ENGLISH_ALL_AUDIO_ASSETS,
  ENGLISH_ALL_IMAGE_ASSETS,
} from '@/data/datasources/english/media';
import type {
  CanonicalCefrSkeleton,
  CanonicalLevelCurriculum,
  CanonicalMediaManifest,
} from '@/data/datasources/english/types';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { PLACEMENT_QUESTIONS } from '@/data/datasources/questions';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { STARTER_LESSONS } from '@/data/datasources/starterLessons';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';
import type { Lesson, LessonFlashcard, LessonStep } from '@/domain/entities/Lesson';
import { readApprovedLessonMedia } from '@/domain/entities/LessonMedia';
import type { Question } from '@/domain/entities/Question';

// ---------------------------------------------------------------------------
// Genuine Recursive-Descent Dart Lexer & Expression Parser
// ---------------------------------------------------------------------------

type DartTokenKind =
  | 'ident'
  | 'string'
  | 'number'
  | 'punct'
  | 'spread'
  | 'eof';

interface DartToken {
  kind: DartTokenKind;
  value: string;
  line: number;
  col: number;
}

type DartValue =
  | string
  | number
  | boolean
  | null
  | DartValue[]
  | DartObject
  | DartEnum
  | DartFunction
  | DartMapEntry;

interface DartEnum {
  __kind: 'enum';
  enumName: string;
  member: string;
}

interface DartObject {
  __kind: 'object';
  typeName?: string;
  props: Record<string, DartValue>;
}

interface DartScopeFrame {
  vars: Map<string, DartValue>;
  parent?: DartScopeFrame;
}

interface DartFunction {
  __kind: 'function';
  name?: string;
  params: string[];
  kind: 'arrow' | 'block' | 'native';
  tokens?: DartToken[];
  fileLabel?: string;
  closureScope?: DartScopeFrame;
  nativeImpl?: (
    positionalArgs: DartValue[],
    namedArgs: Record<string, DartValue>,
  ) => DartValue;
}

interface DartMapEntry {
  __kind: 'map_entry';
  key: DartValue;
  value: DartValue;
}

function isDartEnum(value: DartValue | undefined): value is DartEnum {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    '__kind' in value &&
    value.__kind === 'enum'
  );
}

function isDartObject(value: DartValue | undefined): value is DartObject {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    '__kind' in value &&
    value.__kind === 'object'
  );
}

function isDartFunction(value: DartValue | undefined): value is DartFunction {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    '__kind' in value &&
    value.__kind === 'function'
  );
}

function isDartMapEntry(value: DartValue | undefined): value is DartMapEntry {
  return (
    typeof value === 'object' &&
    value !== null &&
    !Array.isArray(value) &&
    '__kind' in value &&
    value.__kind === 'map_entry'
  );
}

const DART_ENTITY_DEFAULTS: Record<string, Record<string, DartValue>> = {
  Lesson: {
    prerequisites: [],
    requiresMastery: false,
  },
  Question: {
    evaluationMode: 'deterministic',
    mode: { __kind: 'enum', enumName: 'QuestionMode', member: 'multipleChoice' },
    isPlacement: false,
    options: [],
    correctIndex: 0,
    acceptedAnswers: [],
    dialogueContext: [],
    matchPairs: [],
    orderedTokens: [],
    rubricCriteria: [],
    mistakeFeedbackByOption: { __kind: 'object', props: {} },
  },
};

function dartEquals(a: DartValue, b: DartValue): boolean {
  if (a === b) return true;
  if (isDartEnum(a) && isDartEnum(b)) {
    return a.enumName === b.enumName && a.member === b.member;
  }
  return false;
}

function tokenizeDart(source: string, fileLabel: string): DartToken[] {
  const tokens: DartToken[] = [];
  let idx = 0;
  let line = 1;
  let col = 1;
  const len = source.length;

  const peek = (offset = 0): string => source[idx + offset] ?? '';
  const advance = (): string => {
    const ch = source[idx] ?? '';
    idx += 1;
    if (ch === '\n') {
      line += 1;
      col = 1;
    } else {
      col += 1;
    }
    return ch;
  };

  const readStringLiteral = (isRaw: boolean, startLine: number, startCol: number): string => {
    const quote = advance();
    const isTriple = peek() === quote && peek(1) === quote;
    if (isTriple) {
      advance();
      advance();
    }
    let out = '';
    while (idx < len) {
      if (isTriple) {
        if (peek() === quote && peek(1) === quote && peek(2) === quote) {
          advance();
          advance();
          advance();
          return out;
        }
      } else if (peek() === quote) {
        advance();
        return out;
      }

      const ch = advance();
      if (!isRaw && ch === '\\') {
        if (idx >= len) {
          throw new Error(`Unterminated escape in ${fileLabel}:${startLine}:${startCol}`);
        }
        const esc = advance();
        switch (esc) {
          case 'n':
            out += '\n';
            break;
          case 'r':
            out += '\r';
            break;
          case 't':
            out += '\t';
            break;
          case 'b':
            out += '\b';
            break;
          case 'f':
            out += '\f';
            break;
          case 'v':
            out += '\v';
            break;
          case '\\':
            out += '\\';
            break;
          case "'":
            out += "'";
            break;
          case '"':
            out += '"';
            break;
          case '$':
            out += '$';
            break;
          case 'x': {
            const hex = source.slice(idx, idx + 2);
            if (!/^[0-9a-fA-F]{2}$/.test(hex)) {
              throw new Error(`Invalid \\x escape in ${fileLabel}:${line}:${col}`);
            }
            advance();
            advance();
            out += String.fromCharCode(Number.parseInt(hex, 16));
            break;
          }
          case 'u': {
            if (peek() === '{') {
              advance();
              let hex = '';
              while (idx < len && peek() !== '}') {
                hex += advance();
              }
              if (peek() !== '}' || !/^[0-9a-fA-F]+$/.test(hex)) {
                throw new Error(`Invalid \\u{...} escape in ${fileLabel}:${line}:${col}`);
              }
              advance();
              out += String.fromCodePoint(Number.parseInt(hex, 16));
            } else {
              const hex = source.slice(idx, idx + 4);
              if (!/^[0-9a-fA-F]{4}$/.test(hex)) {
                throw new Error(`Invalid \\u escape in ${fileLabel}:${line}:${col}`);
              }
              for (let k = 0; k < 4; k += 1) advance();
              out += String.fromCharCode(Number.parseInt(hex, 16));
            }
            break;
          }
          default:
            out += esc;
            break;
        }
      } else {
        out += ch;
      }
    }
    throw new Error(`Unterminated string literal in ${fileLabel}:${startLine}:${startCol}`);
  };

  while (idx < len) {
    const ch = peek();
    if (/\s/.test(ch)) {
      advance();
      continue;
    }

    // Line comment
    if (ch === '/' && peek(1) === '/') {
      while (idx < len && peek() !== '\n') advance();
      continue;
    }

    // Block comment (Dart supports nested /* ... */ comments)
    if (ch === '/' && peek(1) === '*') {
      advance();
      advance();
      let depth = 1;
      while (idx < len && depth > 0) {
        if (peek() === '/' && peek(1) === '*') {
          advance();
          advance();
          depth += 1;
        } else if (peek() === '*' && peek(1) === '/') {
          advance();
          advance();
          depth -= 1;
        } else {
          advance();
        }
      }
      if (depth > 0) {
        throw new Error(`Unterminated block comment in ${fileLabel}:${line}:${col}`);
      }
      continue;
    }

    const startLine = line;
    const startCol = col;

    // Raw string r'...' or r"..."
    if (ch === 'r' && (peek(1) === "'" || peek(1) === '"')) {
      advance();
      tokens.push({
        kind: 'string',
        value: readStringLiteral(true, startLine, startCol),
        line: startLine,
        col: startCol,
      });
      continue;
    }

    if (ch === "'" || ch === '"') {
      tokens.push({
        kind: 'string',
        value: readStringLiteral(false, startLine, startCol),
        line: startLine,
        col: startCol,
      });
      continue;
    }

    // Spread ...
    if (ch === '.' && peek(1) === '.' && peek(2) === '.') {
      advance();
      advance();
      advance();
      tokens.push({ kind: 'spread', value: '...', line: startLine, col: startCol });
      continue;
    }

    // Number literal
    if (/[0-9]/.test(ch)) {
      let numStr = '';
      while (idx < len && /[0-9]/.test(peek())) {
        numStr += advance();
      }
      if (peek() === '.' && /[0-9]/.test(peek(1))) {
        numStr += advance();
        while (idx < len && /[0-9]/.test(peek())) {
          numStr += advance();
        }
      }
      tokens.push({ kind: 'number', value: numStr, line: startLine, col: startCol });
      continue;
    }

    // Identifier / keyword
    if (/[A-Za-z_$]/.test(ch)) {
      let ident = '';
      while (idx < len && /[A-Za-z0-9_$]/.test(peek())) {
        ident += advance();
      }
      tokens.push({ kind: 'ident', value: ident, line: startLine, col: startCol });
      continue;
    }

    // Two-character operators (keep < and > single-char for nested generics)
    if (
      (ch === '=' && peek(1) === '=') ||
      (ch === '!' && peek(1) === '=') ||
      (ch === '=' && peek(1) === '>')
    ) {
      const twoChar = advance() + advance();
      tokens.push({ kind: 'punct', value: twoChar, line: startLine, col: startCol });
      continue;
    }

    // Single-character punctuation
    if ('(){}[]:,.;=<>!-?'.includes(ch)) {
      advance();
      tokens.push({ kind: 'punct', value: ch, line: startLine, col: startCol });
      continue;
    }

    // Other symbols inside skipped class method bodies (e.g., ? & | =>)
    advance();
    tokens.push({ kind: 'punct', value: ch, line: startLine, col: startCol });
  }

  tokens.push({ kind: 'eof', value: '', line, col });
  return tokens;
}

class DartDatasourceParser {
  private readonly env = new Map<string, DartValue>();

  constructor() {
    this.env.set('MapEntry', {
      __kind: 'function',
      name: 'MapEntry',
      params: ['key', 'value'],
      kind: 'native',
      nativeImpl: (args) => ({
        __kind: 'map_entry',
        key: args[0] ?? null,
        value: args[1] ?? null,
      }),
    });

    this.env.set('permuteQuestionOptions', {
      __kind: 'function',
      name: 'permuteQuestionOptions',
      params: ['question'],
      kind: 'native',
      nativeImpl: (args) => {
        const q = args[0];
        if (!isDartObject(q)) {
          throw new Error('permuteQuestionOptions expected Question DartObject');
        }
        const modeVal = q.props.mode ?? DART_ENTITY_DEFAULTS.Question.mode;
        const modeMember = isDartEnum(modeVal) ? modeVal.member : 'multipleChoice';
        const usesOptionSelection =
          modeMember === 'multipleChoice' ||
          modeMember === 'errorCorrection' ||
          modeMember === 'conversationCompletion';
        if (!usesOptionSelection) return q;

        const options = Array.isArray(q.props.options) ? q.props.options : [];
        if (options.length < 2) return q;

        const current = typeof q.props.correctIndex === 'number' ? q.props.correctIndex : 0;
        if (current < 0 || current >= options.length) return q;

        const id = typeof q.props.id === 'string' ? q.props.id : '';
        let hash = 2166136261;
        for (let i = 0; i < id.length; i += 1) {
          hash ^= id.charCodeAt(i);
          hash = Math.imul(hash, 16777619) >>> 0;
        }
        const target = hash % options.length;
        if (target === current) return q;

        const correctOption = options[current];
        const remaining = options.filter((_, idx) => idx !== current);
        remaining.splice(target, 0, correctOption);

        return {
          __kind: 'object',
          typeName: q.typeName ?? 'Question',
          props: {
            ...q.props,
            options: remaining,
            correctIndex: target,
          },
        };
      },
    });
  }

  private resolveIdentifier(name: string, scope?: DartScopeFrame): DartValue | undefined {
    let frame = scope;
    while (frame) {
      if (frame.vars.has(name)) {
        return frame.vars.get(name);
      }
      frame = frame.parent;
    }
    if (this.env.has(name)) {
      return this.env.get(name);
    }
    return undefined;
  }

  private callDartFunction(
    fn: DartFunction,
    positionalArgs: DartValue[],
    namedArgs: Record<string, DartValue>,
  ): DartValue {
    if (fn.kind === 'native') {
      if (!fn.nativeImpl) {
        throw new Error(`Native Dart function '${fn.name ?? 'anonymous'}' missing implementation`);
      }
      return fn.nativeImpl(positionalArgs, namedArgs);
    }

    const fnScope: DartScopeFrame = {
      vars: new Map<string, DartValue>(),
      parent: fn.closureScope,
    };
    fn.params.forEach((paramName, index) => {
      if (index < positionalArgs.length) {
        fnScope.vars.set(paramName, positionalArgs[index] ?? null);
      } else if (Object.prototype.hasOwnProperty.call(namedArgs, paramName)) {
        fnScope.vars.set(paramName, namedArgs[paramName] ?? null);
      } else {
        fnScope.vars.set(paramName, null);
      }
    });

    const tokens = fn.tokens ?? [];
    const fileLabel = fn.fileLabel ?? '<fn>';
    if (fn.kind === 'arrow') {
      return this.evaluateTokenStream(tokens, fileLabel, 'expr', fnScope).value;
    }
    return this.evaluateTokenStream(tokens, fileLabel, 'block', fnScope).value;
  }

  private extractParamNames(paramTokens: DartToken[]): string[] {
    if (paramTokens.length === 0) return [];
    const params: string[] = [];
    let currentGroup: DartToken[] = [];
    let depth = 0;

    const flushGroup = (): void => {
      if (currentGroup.length === 0) return;
      let lastIdent: string | null = null;
      for (const t of currentGroup) {
        if (t.kind === 'punct' && t.value === '=') break;
        if (t.kind === 'ident') {
          lastIdent = t.value;
        }
      }
      if (lastIdent) params.push(lastIdent);
      currentGroup = [];
    };

    for (const tok of paramTokens) {
      if (tok.kind === 'punct' && ('(<[{'.includes(tok.value))) {
        if (depth === 0 && (tok.value === '{' || tok.value === '[')) {
          continue;
        }
        depth += 1;
        currentGroup.push(tok);
        continue;
      }
      if (tok.kind === 'punct' && (')>]}'.includes(tok.value))) {
        if (depth === 0 && (tok.value === '}' || tok.value === ']')) {
          continue;
        }
        depth -= 1;
        currentGroup.push(tok);
        continue;
      }
      if (depth === 0 && tok.kind === 'punct' && tok.value === ',') {
        flushGroup();
        continue;
      }
      currentGroup.push(tok);
    }
    flushGroup();
    return params;
  }

  private evaluateTokenStream(
    tokens: DartToken[],
    fileLabel: string,
    mode: 'file' | 'expr' | 'block',
    initialScope?: DartScopeFrame,
  ): { returned: boolean; value: DartValue } {
    let pos = 0;
    const eofTok: DartToken = { kind: 'eof', value: '', line: 0, col: 0 };
    const current = (): DartToken => tokens[pos] ?? eofTok;
    const next = (offset = 1): DartToken =>
      tokens[Math.min(pos + offset, tokens.length - 1)] ?? eofTok;
    const eat = (): DartToken => {
      const tok = current();
      pos += 1;
      return tok;
    };
    const expectPunct = (val: string): void => {
      const tok = eat();
      if (tok.kind !== 'punct' || tok.value !== val) {
        throw new Error(
          `Expected '${val}' but got '${tok.value}' (${tok.kind}) in ${fileLabel}:${tok.line}:${tok.col}`,
        );
      }
    };

    const skipBalanced = (open: string, close: string): void => {
      expectPunct(open);
      let depth = 1;
      while (current().kind !== 'eof' && depth > 0) {
        const tok = eat();
        if (tok.kind === 'punct' && tok.value === open) depth += 1;
        else if (tok.kind === 'punct' && tok.value === close) depth -= 1;
      }
      if (depth !== 0) {
        expectPunct(close);
      }
    };

    const captureBalanced = (open: string, close: string): DartToken[] => {
      expectPunct(open);
      const captured: DartToken[] = [];
      let depth = 1;
      while (current().kind !== 'eof' && depth > 0) {
        const tok = eat();
        if (tok.kind === 'punct' && tok.value === open) depth += 1;
        else if (tok.kind === 'punct' && tok.value === close) {
          depth -= 1;
          if (depth === 0) break;
        }
        captured.push(tok);
      }
      if (depth !== 0) {
        expectPunct(close);
      }
      return captured;
    };

    const skipGenericTypeArgs = (): void => {
      if (current().kind !== 'punct' || current().value !== '<') return;
      expectPunct('<');
      let depth = 1;
      while (current().kind !== 'eof' && depth > 0) {
        const tok = eat();
        if (tok.kind === 'punct' && tok.value === '<') depth += 1;
        else if (tok.kind === 'punct' && tok.value === '>') depth -= 1;
      }
      if (depth !== 0) {
        expectPunct('>');
      }
    };

    const findMatchingParenOffset = (startOffset: number): number => {
      let idx = startOffset + 1;
      let depth = 1;
      while (idx < tokens.length && depth > 0) {
        const t = tokens[idx];
        if (t.kind === 'punct' && t.value === '(') depth += 1;
        else if (t.kind === 'punct' && t.value === ')') depth -= 1;
        if (depth === 0) return idx;
        idx += 1;
      }
      return -1;
    };

    const parseArgList = (
      scope?: DartScopeFrame,
    ): { positional: DartValue[]; named: Record<string, DartValue> } => {
      expectPunct('(');
      const positional: DartValue[] = [];
      const named: Record<string, DartValue> = {};
      while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === ')')) {
        if (
          current().kind === 'ident' &&
          next().kind === 'punct' &&
          next().value === ':'
        ) {
          const argName = eat().value;
          expectPunct(':');
          named[argName] = parseExpr(scope);
        } else {
          positional.push(parseExpr(scope));
        }
        if (current().kind === 'punct' && current().value === ',') {
          eat();
        } else {
          break;
        }
      }
      expectPunct(')');
      return { positional, named };
    };

    const parseExpr = (scope?: DartScopeFrame): DartValue => {
      if (current().kind === 'ident' && current().value === 'const') {
        eat();
      }
      if (current().kind === 'punct' && current().value === '<') {
        skipGenericTypeArgs();
      }
      return parseConditional(scope);
    };

    const skipConditionalBranch = (): void => {
      let parenDepth = 0;
      let bracketDepth = 0;
      let braceDepth = 0;
      let ternaryDepth = 0;
      while (current().kind !== 'eof') {
        const t = current();
        if (parenDepth === 0 && bracketDepth === 0 && braceDepth === 0 && t.kind === 'punct') {
          if (t.value === '?') {
            ternaryDepth += 1;
            eat();
            continue;
          }
          if (t.value === ':') {
            if (ternaryDepth > 0) {
              ternaryDepth -= 1;
              eat();
              continue;
            }
            break;
          }
          if (',)]};'.includes(t.value)) {
            break;
          }
        }
        if (t.kind === 'punct') {
          if (t.value === '(') parenDepth += 1;
          else if (t.value === ')') parenDepth -= 1;
          else if (t.value === '[') bracketDepth += 1;
          else if (t.value === ']') bracketDepth -= 1;
          else if (t.value === '{') braceDepth += 1;
          else if (t.value === '}') braceDepth -= 1;
        }
        eat();
      }
    };

    const parseConditional = (scope?: DartScopeFrame): DartValue => {
      const cond = parseEquality(scope);
      if (current().kind === 'punct' && current().value === '?') {
        eat();
        if (cond) {
          const whenTrue = parseExpr(scope);
          expectPunct(':');
          skipConditionalBranch();
          return whenTrue;
        }
        skipConditionalBranch();
        expectPunct(':');
        return parseExpr(scope);
      }
      return cond;
    };

    const parseEquality = (scope?: DartScopeFrame): DartValue => {
      let left = parsePrimaryWithPostfix(scope);
      while (
        current().kind === 'punct' &&
        (current().value === '==' || current().value === '!=')
      ) {
        const op = eat().value;
        const right = parsePrimaryWithPostfix(scope);
        const eq = dartEquals(left, right);
        left = op === '==' ? eq : !eq;
      }
      return left;
    };

    const parsePrimaryWithPostfix = (scope?: DartScopeFrame): DartValue => {
      let value = parsePrimary(scope);

      while (true) {
        if (current().kind === 'punct' && current().value === '[') {
          eat();
          const key = parseExpr(scope);
          expectPunct(']');
          if (Array.isArray(value) && typeof key === 'number') {
            value = value[key] ?? null;
          } else if (isDartObject(value) && typeof key === 'string') {
            value = value.props[key] ?? null;
          } else {
            throw new Error(
              `Invalid subscript access in ${fileLabel}:${current().line}:${current().col}`,
            );
          }
          continue;
        }
        if (current().kind === 'punct' && current().value === '!') {
          eat();
          continue;
        }
        if (current().kind === 'punct' && current().value === '.') {
          eat();
          const memberTok = eat();
          if (memberTok.kind !== 'ident') {
            throw new Error(
              `Expected member identifier after '.' in ${fileLabel}:${memberTok.line}`,
            );
          }
          if (current().kind === 'punct' && current().value === '(') {
            const { positional } = parseArgList(scope);
            if (Array.isArray(value)) {
              if (memberTok.value === 'map') {
                const cb = positional[0];
                if (!isDartFunction(cb)) {
                  throw new Error(
                    `List.map expects a DartFunction in ${fileLabel}:${memberTok.line}`,
                  );
                }
                value = value.map((item) => this.callDartFunction(cb, [item], {}));
              } else if (memberTok.value === 'toList') {
                value = [...value];
              } else {
                throw new Error(
                  `Unsupported List method '${memberTok.value}' in ${fileLabel}:${memberTok.line}`,
                );
              }
            } else if (isDartObject(value)) {
              if (memberTok.value === 'map') {
                const cb = positional[0];
                if (!isDartFunction(cb)) {
                  throw new Error(
                    `Map.map expects a DartFunction in ${fileLabel}:${memberTok.line}`,
                  );
                }
                const mappedProps: Record<string, DartValue> = {};
                for (const [k, v] of Object.entries(value.props)) {
                  const entry = this.callDartFunction(cb, [k, v], {});
                  if (!isDartMapEntry(entry)) {
                    throw new Error(
                      `Map.map callback must return MapEntry in ${fileLabel}:${memberTok.line}`,
                    );
                  }
                  mappedProps[String(entry.key)] = entry.value;
                }
                value = { __kind: 'object', props: mappedProps };
              } else {
                throw new Error(
                  `Unsupported object method '${memberTok.value}' in ${fileLabel}:${memberTok.line}`,
                );
              }
            } else {
              throw new Error(
                `Cannot invoke method '${memberTok.value}' on non-object/non-list in ${fileLabel}:${memberTok.line}`,
              );
            }
          } else if (isDartObject(value)) {
            if (Object.prototype.hasOwnProperty.call(value.props, memberTok.value)) {
              value = value.props[memberTok.value] ?? null;
            } else {
              const typeDefaults = value.typeName
                ? DART_ENTITY_DEFAULTS[value.typeName]
                : undefined;
              value =
                typeDefaults &&
                Object.prototype.hasOwnProperty.call(typeDefaults, memberTok.value)
                  ? typeDefaults[memberTok.value]
                  : null;
            }
          } else if (
            (Array.isArray(value) || typeof value === 'string') &&
            memberTok.value === 'length'
          ) {
            value = value.length;
          } else {
            throw new Error(
              `Invalid member access '.${memberTok.value}' in ${fileLabel}:${memberTok.line}`,
            );
          }
          continue;
        }
        break;
      }

      return value;
    };

    const parsePrimary = (scope?: DartScopeFrame): DartValue => {
      const tok = current();

      // Unary minus on number
      if (tok.kind === 'punct' && tok.value === '-') {
        eat();
        const numTok = eat();
        if (numTok.kind !== 'number') {
          throw new Error(
            `Expected number after '-' in ${fileLabel}:${numTok.line}:${numTok.col}`,
          );
        }
        return -Number(numTok.value);
      }

      // Unary logical negation
      if (tok.kind === 'punct' && tok.value === '!') {
        eat();
        return !parsePrimaryWithPostfix(scope);
      }

      if (tok.kind === 'number') {
        eat();
        return Number(tok.value);
      }

      if (tok.kind === 'string') {
        let combined = eat().value;
        while (current().kind === 'string') {
          combined += eat().value;
        }
        return combined;
      }

      // Parenthesized expression or anonymous lambda: (...) => expr / (...) { ... }
      if (tok.kind === 'punct' && tok.value === '(') {
        const closeIdx = findMatchingParenOffset(pos);
        const afterClose = closeIdx >= 0 ? tokens[closeIdx + 1] : undefined;
        if (
          afterClose &&
          afterClose.kind === 'punct' &&
          (afterClose.value === '=>' || afterClose.value === '{')
        ) {
          const paramTokens = captureBalanced('(', ')');
          const params = this.extractParamNames(paramTokens);
          if (current().kind === 'punct' && current().value === '=>') {
            eat();
            const bodyTokens: DartToken[] = [];
            let parenDepth = 0;
            let bracketDepth = 0;
            let braceDepth = 0;
            while (current().kind !== 'eof') {
              const t = current();
              if (
                parenDepth === 0 &&
                bracketDepth === 0 &&
                braceDepth === 0 &&
                t.kind === 'punct' &&
                (',)]};'.includes(t.value))
              ) {
                break;
              }
              if (t.kind === 'punct') {
                if (t.value === '(') parenDepth += 1;
                else if (t.value === ')') parenDepth -= 1;
                else if (t.value === '[') bracketDepth += 1;
                else if (t.value === ']') bracketDepth -= 1;
                else if (t.value === '{') braceDepth += 1;
                else if (t.value === '}') braceDepth -= 1;
              }
              bodyTokens.push(eat());
            }
            return {
              __kind: 'function',
              params,
              kind: 'arrow',
              tokens: bodyTokens,
              fileLabel,
              closureScope: scope,
            };
          }
          const bodyTokens = captureBalanced('{', '}');
          return {
            __kind: 'function',
            params,
            kind: 'block',
            tokens: bodyTokens,
            fileLabel,
            closureScope: scope,
          };
        }

        expectPunct('(');
        const inner = parseExpr(scope);
        expectPunct(')');
        return inner;
      }

      // List literal
      if (tok.kind === 'punct' && tok.value === '[') {
        expectPunct('[');
        const items: DartValue[] = [];
        while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === ']')) {
          if (current().kind === 'spread') {
            eat();
            const spreadVal = parseExpr(scope);
            if (!Array.isArray(spreadVal)) {
              throw new Error(
                `Spread in list did not evaluate to array in ${fileLabel}:${tok.line}`,
              );
            }
            items.push(...spreadVal);
          } else {
            items.push(parseExpr(scope));
          }
          if (current().kind === 'punct' && current().value === ',') {
            eat();
          } else {
            break;
          }
        }
        expectPunct(']');
        return items;
      }

      // Map literal
      if (tok.kind === 'punct' && tok.value === '{') {
        expectPunct('{');
        const props: Record<string, DartValue> = {};
        while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === '}')) {
          if (current().kind === 'spread') {
            eat();
            const spreadVal = parseExpr(scope);
            if (!isDartObject(spreadVal)) {
              throw new Error(
                `Spread in map did not evaluate to map object in ${fileLabel}:${tok.line}`,
              );
            }
            Object.assign(props, spreadVal.props);
          } else {
            const keyVal = parseExpr(scope);
            expectPunct(':');
            const val = parseExpr(scope);
            props[String(keyVal)] = val;
          }
          if (current().kind === 'punct' && current().value === ',') {
            eat();
          } else {
            break;
          }
        }
        expectPunct('}');
        return { __kind: 'object', props };
      }

      if (tok.kind === 'ident') {
        eat();
        if (tok.value === 'true') return true;
        if (tok.value === 'false') return false;
        if (tok.value === 'null') return null;

        // Function call or constructor invocation: ident(...)
        if (current().kind === 'punct' && current().value === '(') {
          const { positional, named } = parseArgList(scope);
          const resolvedFn = this.resolveIdentifier(tok.value, scope);
          if (isDartFunction(resolvedFn)) {
            return this.callDartFunction(resolvedFn, positional, named);
          }
          return { __kind: 'object', typeName: tok.value, props: named };
        }

        // Resolve variable / function tear-off in scope BEFORE enum fallback
        const resolved = this.resolveIdentifier(tok.value, scope);
        if (resolved !== undefined) {
          return resolved;
        }

        // Enum member access: EnumName.member
        if (current().kind === 'punct' && current().value === '.') {
          eat();
          const memberTok = eat();
          if (memberTok.kind !== 'ident') {
            throw new Error(
              `Expected member identifier after '.' in ${fileLabel}:${memberTok.line}`,
            );
          }
          return { __kind: 'enum', enumName: tok.value, member: memberTok.value };
        }

        throw new Error(
          `Unresolved Dart identifier '${tok.value}' in ${fileLabel}:${tok.line}:${tok.col}`,
        );
      }

      throw new Error(
        `Unexpected token '${tok.value}' (${tok.kind}) in ${fileLabel}:${tok.line}:${tok.col}`,
      );
    };

    const skipStatement = (): void => {
      if (current().kind === 'punct' && current().value === '{') {
        skipBalanced('{', '}');
        return;
      }
      if (current().kind === 'ident' && current().value === 'if') {
        eat();
        skipBalanced('(', ')');
        skipStatement();
        if (current().kind === 'ident' && current().value === 'else') {
          eat();
          skipStatement();
        }
        return;
      }
      let parenDepth = 0;
      let bracketDepth = 0;
      let braceDepth = 0;
      while (current().kind !== 'eof') {
        const t = eat();
        if (t.kind === 'punct') {
          if (t.value === '(') parenDepth += 1;
          else if (t.value === ')') parenDepth -= 1;
          else if (t.value === '[') bracketDepth += 1;
          else if (t.value === ']') bracketDepth -= 1;
          else if (t.value === '{') braceDepth += 1;
          else if (t.value === '}') braceDepth -= 1;
          else if (t.value === ';' && parenDepth === 0 && bracketDepth === 0 && braceDepth === 0) {
            return;
          }
        }
      }
    };

    const execStatement = (
      scope: DartScopeFrame,
    ): { returned: boolean; value: DartValue } => {
      const tok = current();
      if (tok.kind === 'ident' && tok.value === 'return') {
        eat();
        if (current().kind === 'punct' && current().value === ';') {
          eat();
          return { returned: true, value: null };
        }
        const val = parseExpr(scope);
        expectPunct(';');
        return { returned: true, value: val };
      }

      if (tok.kind === 'ident' && tok.value === 'if') {
        eat();
        expectPunct('(');
        const cond = parseExpr(scope);
        expectPunct(')');
        if (cond) {
          const res = execStatement(scope);
          if (current().kind === 'ident' && current().value === 'else') {
            eat();
            skipStatement();
          }
          if (res.returned) return res;
        } else {
          skipStatement();
          if (current().kind === 'ident' && current().value === 'else') {
            eat();
            const res = execStatement(scope);
            if (res.returned) return res;
          }
        }
        return { returned: false, value: null };
      }

      if (tok.kind === 'punct' && tok.value === '{') {
        expectPunct('{');
        const innerScope: DartScopeFrame = { vars: new Map(), parent: scope };
        while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === '}')) {
          const res = execStatement(innerScope);
          if (res.returned) {
            let braceDepth = 1;
            while (current().kind !== 'eof' && braceDepth > 0) {
              const t = eat();
              if (t.kind === 'punct' && t.value === '{') braceDepth += 1;
              else if (t.kind === 'punct' && t.value === '}') braceDepth -= 1;
            }
            if (braceDepth !== 0) {
              expectPunct('}');
            }
            return res;
          }
        }
        expectPunct('}');
        return { returned: false, value: null };
      }

      // Check for local variable declaration: (final|const|var)? Type? name = expr;
      let scan = pos;
      let angleDepth = 0;
      let parenDepth = 0;
      let hasAssignBeforeSemi = false;
      while (scan < tokens.length) {
        const t = tokens[scan];
        if (t.kind === 'eof') break;
        if (t.kind === 'punct') {
          if (t.value === '<') angleDepth += 1;
          else if (t.value === '>' && angleDepth > 0) angleDepth -= 1;
          else if (t.value === '(') parenDepth += 1;
          else if (t.value === ')') parenDepth -= 1;
          else if (angleDepth === 0 && parenDepth === 0) {
            if (t.value === '=') {
              hasAssignBeforeSemi = true;
              break;
            }
            if (t.value === ';') break;
          }
        }
        scan += 1;
      }

      if (hasAssignBeforeSemi) {
        let varName: string | null = null;
        while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === '=')) {
          if (current().kind === 'punct' && current().value === '<') {
            skipGenericTypeArgs();
            continue;
          }
          const declTok = eat();
          if (declTok.kind === 'ident') {
            varName = declTok.value;
          }
        }
        expectPunct('=');
        if (!varName) {
          throw new Error(`Missing local variable identifier in ${fileLabel}:${tok.line}`);
        }
        const val = parseExpr(scope);
        expectPunct(';');
        scope.vars.set(varName, val);
        return { returned: false, value: null };
      }

      parseExpr(scope);
      expectPunct(';');
      return { returned: false, value: null };
    };

    if (mode === 'expr') {
      const value = parseExpr(initialScope);
      return { returned: true, value };
    }

    if (mode === 'block') {
      const scope = initialScope ?? { vars: new Map() };
      while (current().kind !== 'eof') {
        const res = execStatement(scope);
        if (res.returned) return res;
      }
      return { returned: false, value: null };
    }

    // Top-level file statements
    while (current().kind !== 'eof') {
      const tok = current();
      if (tok.kind === 'ident' && (tok.value === 'import' || tok.value === 'export')) {
        while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === ';')) {
          eat();
        }
        if (current().kind === 'punct' && current().value === ';') eat();
        continue;
      }

      if (tok.kind === 'ident' && (tok.value === 'class' || tok.value === 'enum')) {
        while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === '{')) {
          eat();
        }
        if (current().kind === 'punct' && current().value === '{') {
          skipBalanced('{', '}');
        }
        continue;
      }

      // Scan ahead to distinguish top-level function vs top-level variable declaration
      let scan = pos;
      let angleDepth = 0;
      let firstSpecial: string | null = null;
      while (scan < tokens.length) {
        const t = tokens[scan];
        if (t.kind === 'eof') break;
        if (t.kind === 'punct') {
          if (t.value === '<') angleDepth += 1;
          else if (t.value === '>' && angleDepth > 0) angleDepth -= 1;
          else if (angleDepth === 0 && (t.value === '(' || t.value === '=' || t.value === ';')) {
            firstSpecial = t.value;
            break;
          }
        }
        scan += 1;
      }

      if (firstSpecial === '(') {
        // Top-level function declaration: ReturnType<...>? funcName<...>?(params) { ... } | => expr;
        let funcName: string | null = null;
        while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === '(')) {
          if (current().kind === 'punct' && current().value === '<') {
            skipGenericTypeArgs();
            continue;
          }
          const fnTok = eat();
          if (fnTok.kind === 'ident') {
            funcName = fnTok.value;
          }
        }
        if (!funcName) {
          throw new Error(`Missing top-level function name in ${fileLabel}:${tok.line}`);
        }
        const paramTokens = captureBalanced('(', ')');
        const params = this.extractParamNames(paramTokens);
        if (current().kind === 'punct' && current().value === '=>') {
          eat();
          const bodyTokens: DartToken[] = [];
          while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === ';')) {
            bodyTokens.push(eat());
          }
          expectPunct(';');
          this.env.set(funcName, {
            __kind: 'function',
            name: funcName,
            params,
            kind: 'arrow',
            tokens: bodyTokens,
            fileLabel,
          });
        } else {
          const bodyTokens = captureBalanced('{', '}');
          this.env.set(funcName, {
            __kind: 'function',
            name: funcName,
            params,
            kind: 'block',
            tokens: bodyTokens,
            fileLabel,
          });
        }
        continue;
      }

      // Top-level variable declaration: (const|final|var)? Type<...>? varName = expr;
      let lastIdent: string | null = null;
      while (current().kind !== 'eof' && !(current().kind === 'punct' && current().value === '=')) {
        if (current().kind === 'punct' && current().value === '<') {
          skipGenericTypeArgs();
          continue;
        }
        const declTok = eat();
        if (declTok.kind === 'ident') {
          lastIdent = declTok.value;
        }
      }
      if (current().kind === 'eof') break;
      expectPunct('=');
      if (!lastIdent) {
        throw new Error(`Missing declaration identifier before '=' in ${fileLabel}:${tok.line}`);
      }
      const parsedVal = parseExpr(undefined);
      expectPunct(';');
      this.env.set(lastIdent, parsedVal);
    }

    return { returned: false, value: null };
  }

  parseSource(source: string, fileLabel = '<inline.dart>'): void {
    const tokens = tokenizeDart(source, fileLabel);
    this.evaluateTokenStream(tokens, fileLabel, 'file');
  }

  parseFile(repoRelativePath: string): void {
    const absPath = path.resolve(process.cwd(), repoRelativePath);
    const source = readFileSync(absPath, 'utf8');
    this.parseSource(source, repoRelativePath);
  }

  get(name: string): DartValue {
    if (!this.env.has(name)) {
      throw new Error(`Dart variable '${name}' not found in parsed environment`);
    }
    return this.env.get(name) ?? null;
  }
}

// ---------------------------------------------------------------------------
// Normalization Helpers (Dart AST -> Canonical Shape)
// ---------------------------------------------------------------------------

const QUESTION_MODE_MAP: Record<string, Question['questionType']> = {
  multipleChoice: 'multiple_choice',
  textInput: 'text_input',
  fillBlank: 'fill_blank',
  wordMatch: 'word_match',
  sentenceOrder: 'sentence_order',
  errorCorrection: 'error_correction',
  conversationCompletion: 'conversation_completion',
  speakingPrompt: 'speaking_prompt',
  writingPrompt: 'writing_prompt',
};

const STEP_TYPE_MAP: Record<string, LessonStep['type']> = {
  concept: 'concept',
  formula: 'formula',
  visualExample: 'visual_example',
  audioSimulation: 'audio_simulation',
  flashcard: 'flashcard',
  interactiveQuestion: 'interactive_question',
};

const NODE_KIND_MAP: Record<string, LearningPathNode['nodeKind']> = {
  lesson: 'lesson',
  unitCheckpoint: 'unit_checkpoint',
  levelAssessment: 'level_assessment',
};

const NODE_STATUS_MAP: Record<string, LearningPathNode['status']> = {
  locked: 'locked',
  available: 'available',
  inProgress: 'in_progress',
  completed: 'completed',
  reinforcement: 'reinforcement',
};

function asObj(val: DartValue | undefined, ctx: string): Record<string, DartValue> {
  if (!isDartObject(val)) {
    throw new Error(`Expected DartObject for ${ctx}`);
  }
  return val.props;
}

function asStr(val: DartValue | undefined): string | undefined {
  return typeof val === 'string' ? val : undefined;
}

function asNum(val: DartValue | undefined): number | undefined {
  return typeof val === 'number' ? val : undefined;
}

function asBool(val: DartValue | undefined): boolean | undefined {
  return typeof val === 'boolean' ? val : undefined;
}

function asStrList(val: DartValue | undefined): string[] {
  if (!Array.isArray(val)) return [];
  return val.map((item) => String(item));
}

function enumMember(val: DartValue | undefined, ctx: string): string {
  if (!isDartEnum(val)) {
    throw new Error(`Expected DartEnum for ${ctx}`);
  }
  return val.member;
}

interface NormalizedMedia {
  id?: string;
  kind: string;
  language: string;
  source: string;
  title?: string;
  titleUz?: string;
  titleRu?: string;
  transcript?: string;
  alt?: string;
  altUz?: string;
  altRu?: string;
  posterImage?: string;
  posterAlt?: string;
  posterAltUz?: string;
  posterAltRu?: string;
  durationSeconds?: number;
  reviewStatus: string;
  provenance?: string;
  attribution?: string;
}

function normalizeJsonOrWebMedia(raw: unknown): NormalizedMedia | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const m = raw as Record<string, unknown>;
  return {
    id: typeof m.id === 'string' ? m.id : undefined,
    kind: String(m.kind),
    language: String(m.language),
    source: String(m.source),
    title: typeof m.title === 'string' ? m.title : undefined,
    titleUz: typeof m.titleUz === 'string' ? m.titleUz : undefined,
    titleRu: typeof m.titleRu === 'string' ? m.titleRu : undefined,
    transcript: typeof m.transcript === 'string' ? m.transcript : undefined,
    alt: typeof m.alt === 'string' ? m.alt : undefined,
    altUz: typeof m.altUz === 'string' ? m.altUz : undefined,
    altRu: typeof m.altRu === 'string' ? m.altRu : undefined,
    posterImage: typeof m.posterImage === 'string' ? m.posterImage : undefined,
    posterAlt: typeof m.posterAlt === 'string' ? m.posterAlt : undefined,
    posterAltUz: typeof m.posterAltUz === 'string' ? m.posterAltUz : undefined,
    posterAltRu: typeof m.posterAltRu === 'string' ? m.posterAltRu : undefined,
    durationSeconds: typeof m.durationSeconds === 'number' ? m.durationSeconds : undefined,
    reviewStatus: typeof m.reviewStatus === 'string' ? m.reviewStatus : 'approved',
    provenance: typeof m.provenance === 'string' ? m.provenance : undefined,
    attribution: typeof m.attribution === 'string' ? m.attribution : undefined,
  };
}

function normalizeDartMedia(val: DartValue | undefined): NormalizedMedia | undefined {
  if (!val || val === null) return undefined;
  const p = asObj(val, 'LessonMedia');
  return {
    id: asStr(p.id),
    kind: enumMember(p.kind, 'LessonMedia.kind'),
    language: enumMember(p.language, 'LessonMedia.language'),
    source: asStr(p.source) ?? '',
    title: asStr(p.title),
    titleUz: asStr(p.titleUz),
    titleRu: asStr(p.titleRu),
    transcript: asStr(p.transcript),
    alt: asStr(p.alt),
    altUz: asStr(p.altUz),
    altRu: asStr(p.altRu),
    posterImage: asStr(p.posterImage),
    posterAlt: asStr(p.posterAlt),
    posterAltUz: asStr(p.posterAltUz),
    posterAltRu: asStr(p.posterAltRu),
    durationSeconds: asNum(p.durationSeconds),
    reviewStatus: p.reviewStatus ? enumMember(p.reviewStatus, 'LessonMedia.reviewStatus') : 'approved',
    provenance: asStr(p.provenance),
    attribution: asStr(p.attribution),
  };
}

interface NormalizedFlashcard {
  id: string;
  front: string;
  backUz: string;
  backRu: string;
  partOfSpeech?: string;
  ipa?: string;
  ipaAmE?: string;
  cefrLevel?: string;
  example: string;
  exampleUz: string;
  exampleRu: string;
  audioSrc?: string;
  imageSrc?: string;
  alt?: string;
  altRu?: string;
}

function normalizeJsonOrWebFlashcard(c: LessonFlashcard): NormalizedFlashcard {
  return {
    id: c.id,
    front: c.front,
    backUz: c.backUz,
    backRu: c.backRu ?? '',
    partOfSpeech: c.partOfSpeech,
    ipa: c.ipa,
    ipaAmE: c.ipaAmE,
    cefrLevel: c.cefrLevel,
    example: c.example,
    exampleUz: c.exampleUz ?? '',
    exampleRu: c.exampleRu ?? '',
    audioSrc: c.audioSrc,
    imageSrc: c.imageSrc,
    alt: c.alt,
    altRu: c.altRu,
  };
}

function normalizeDartFlashcard(val: DartValue): NormalizedFlashcard {
  const p = asObj(val, 'LessonFlashcard');
  return {
    id: asStr(p.id) ?? '',
    front: asStr(p.front) ?? '',
    backUz: asStr(p.backUz) ?? '',
    backRu: asStr(p.backRu) ?? '',
    partOfSpeech: asStr(p.partOfSpeech),
    ipa: asStr(p.ipa),
    ipaAmE: asStr(p.ipaAmE),
    cefrLevel: asStr(p.cefrLevel),
    example: asStr(p.example) ?? '',
    exampleUz: asStr(p.exampleUz) ?? '',
    exampleRu: asStr(p.exampleRu) ?? '',
    audioSrc: asStr(p.audioSrc),
    imageSrc: asStr(p.imageSrc),
    alt: asStr(p.alt),
    altRu: asStr(p.altRu),
  };
}

interface NormalizedQuestion {
  id: string;
  courseId: string;
  skillId: string;
  skillDomain?: string;
  cefrLevel?: string;
  topic?: string;
  difficulty: string;
  questionType: string;
  evaluationMode: string;
  isPlacement: boolean;
  text: string;
  textRu?: string;
  contextSnippet?: string;
  blankTemplate?: string;
  sentenceWithError?: string;
  dialogueContext: string[];
  options: string[];
  correctIndex?: number;
  acceptedAnswers: string[];
  matchPairs: Array<{ id: string; left: string; right: string }>;
  orderedTokens: string[];
  sampleResponse?: string;
  rubricCriteria: Array<{ id: string; labelUz: string; labelRu: string }>;
  selfAssessmentNoticeUz?: string;
  selfAssessmentNoticeRu?: string;
  mistakeFeedbackByOption: Record<string, { uz: string; ru: string }>;
  explanation: string;
  explanationRu?: string;
  wrongFeedback?: string;
  wrongFeedbackRu?: string;
  audioSimText?: string;
  audioSimSpeaker?: string;
  media?: NormalizedMedia;
}

const OPTION_MODES = new Set([
  'multiple_choice',
  'error_correction',
  'conversation_completion',
]);

function normalizeJsonOrWebQuestion(q: Question): NormalizedQuestion {
  const qType = q.questionType ?? 'multiple_choice';
  const mistakeFeedback: Record<string, { uz: string; ru: string }> = {};
  if (q.mistakeFeedbackByOption) {
    for (const [k, v] of Object.entries(q.mistakeFeedbackByOption)) {
      mistakeFeedback[k] = { uz: v.uz, ru: v.ru };
    }
  }
  return {
    id: q.id,
    courseId: q.courseId,
    skillId: q.skillId,
    skillDomain: q.skillDomain,
    cefrLevel: q.cefrLevel,
    topic: q.topic,
    difficulty: q.difficulty,
    questionType: qType,
    evaluationMode: q.evaluationMode ?? 'deterministic',
    isPlacement: Boolean(q.isPlacement),
    text: q.text,
    textRu: q.textRu,
    contextSnippet: q.contextSnippet,
    blankTemplate: q.blankTemplate,
    sentenceWithError: q.sentenceWithError,
    dialogueContext: q.dialogueContext ?? [],
    options: q.options ?? [],
    correctIndex: OPTION_MODES.has(qType) ? q.correctIndex : undefined,
    acceptedAnswers: q.acceptedAnswers ?? [],
    matchPairs: q.matchPairs ?? [],
    orderedTokens: q.orderedTokens ?? [],
    sampleResponse: q.sampleResponse,
    rubricCriteria: q.rubricCriteria ?? [],
    selfAssessmentNoticeUz: q.selfAssessmentNoticeUz,
    selfAssessmentNoticeRu: q.selfAssessmentNoticeRu,
    mistakeFeedbackByOption: mistakeFeedback,
    explanation: q.explanation,
    explanationRu: q.explanationRu,
    wrongFeedback: q.wrongFeedback,
    wrongFeedbackRu: q.wrongFeedbackRu,
    audioSimText: q.audioSimText,
    audioSimSpeaker: q.audioSimSpeaker,
    media: normalizeJsonOrWebMedia(q.media),
  };
}

function normalizeDartQuestion(val: DartValue): NormalizedQuestion {
  const p = asObj(val, 'Question');
  const modeMember = p.mode ? enumMember(p.mode, 'Question.mode') : 'multipleChoice';
  const qType = QUESTION_MODE_MAP[modeMember];
  if (!qType) {
    throw new Error(`Unknown Dart QuestionMode: ${modeMember}`);
  }

  const mistakeFeedback: Record<string, { uz: string; ru: string }> = {};
  if (p.mistakeFeedbackByOption && isDartObject(p.mistakeFeedbackByOption)) {
    for (const [opt, fbVal] of Object.entries(p.mistakeFeedbackByOption.props)) {
      const fb = asObj(fbVal, 'LocalizedFeedback');
      mistakeFeedback[opt] = {
        uz: asStr(fb.uz) ?? '',
        ru: asStr(fb.ru) ?? '',
      };
    }
  }

  const matchPairs = Array.isArray(p.matchPairs)
    ? p.matchPairs.map((item) => {
        const pair = asObj(item, 'WordMatchPair');
        return {
          id: asStr(pair.id) ?? '',
          left: asStr(pair.left) ?? '',
          right: asStr(pair.right) ?? '',
        };
      })
    : [];

  const rubricCriteria = Array.isArray(p.rubricCriteria)
    ? p.rubricCriteria.map((item) => {
        const crit = asObj(item, 'RubricCriterion');
        return {
          id: asStr(crit.id) ?? '',
          labelUz: asStr(crit.labelUz) ?? '',
          labelRu: asStr(crit.labelRu) ?? '',
        };
      })
    : [];

  return {
    id: asStr(p.id) ?? '',
    courseId: asStr(p.courseId) ?? '',
    skillId: asStr(p.skillId) ?? '',
    skillDomain: asStr(p.skillDomain),
    cefrLevel: asStr(p.cefrLevel),
    topic: asStr(p.topic),
    difficulty: enumMember(p.difficulty, 'Question.difficulty'),
    questionType: qType,
    evaluationMode: asStr(p.evaluationMode) ?? 'deterministic',
    isPlacement: asBool(p.isPlacement) ?? false,
    text: asStr(p.text) ?? '',
    textRu: asStr(p.textRu),
    contextSnippet: asStr(p.contextSnippet),
    blankTemplate: asStr(p.blankTemplate),
    sentenceWithError: asStr(p.sentenceWithError),
    dialogueContext: asStrList(p.dialogueContext),
    options: asStrList(p.options),
    correctIndex: OPTION_MODES.has(qType) ? (asNum(p.correctIndex) ?? 0) : undefined,
    acceptedAnswers: asStrList(p.acceptedAnswers),
    matchPairs,
    orderedTokens: asStrList(p.orderedTokens),
    sampleResponse: asStr(p.sampleResponse),
    rubricCriteria,
    selfAssessmentNoticeUz: asStr(p.selfAssessmentNoticeUz),
    selfAssessmentNoticeRu: asStr(p.selfAssessmentNoticeRu),
    mistakeFeedbackByOption: mistakeFeedback,
    explanation: asStr(p.explanation) ?? '',
    explanationRu: asStr(p.explanationRu),
    wrongFeedback: asStr(p.wrongFeedback),
    wrongFeedbackRu: asStr(p.wrongFeedbackRu),
    audioSimText: asStr(p.audioSimText),
    audioSimSpeaker: asStr(p.audioSimSpeaker),
    media: normalizeDartMedia(p.media),
  };
}

interface NormalizedVisualModelPoint {
  x: number;
  y: number;
  label?: string;
}

interface NormalizedVisualModelData {
  type: string;
  functionExpr?: string;
  points?: NormalizedVisualModelPoint[];
  audioTranscript?: string;
  speakerName?: string;
}

function normalizeJsonOrWebVisualModelData(
  raw: LessonStep['visualModelData'],
): NormalizedVisualModelData | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  return {
    type: String(raw.type),
    functionExpr: typeof raw.functionExpr === 'string' ? raw.functionExpr : undefined,
    points: Array.isArray(raw.points)
      ? raw.points.map((pt) => ({
          x: Number(pt.x),
          y: Number(pt.y),
          label: typeof pt.label === 'string' ? pt.label : undefined,
        }))
      : undefined,
    audioTranscript: typeof raw.audioTranscript === 'string' ? raw.audioTranscript : undefined,
    speakerName: typeof raw.speakerName === 'string' ? raw.speakerName : undefined,
  };
}

function normalizeDartVisualModelData(
  val: DartValue | undefined,
): NormalizedVisualModelData | undefined {
  if (!val || val === null) return undefined;
  const p = asObj(val, 'LessonVisualModelData');
  let points: NormalizedVisualModelPoint[] | undefined;
  if (Array.isArray(p.points)) {
    points = p.points.map((item) => {
      const pt = asObj(item, 'LessonVisualModelData.point');
      return {
        x: asNum(pt.x) ?? 0,
        y: asNum(pt.y) ?? 0,
        label: asStr(pt.label),
      };
    });
  }
  return {
    type: asStr(p.type) ?? '',
    functionExpr: asStr(p.functionExpr),
    points,
    audioTranscript: asStr(p.audioTranscript),
    speakerName: asStr(p.speakerName),
  };
}

interface NormalizedStep {
  id: string;
  stepNumber: number;
  type: string;
  title: string;
  titleRu?: string;
  subtitle?: string;
  subtitleRu?: string;
  content: string;
  contentRu?: string;
  highlightNotes?: string[];
  highlightNotesRu?: string[];
  masteryCheckpoint?: string;
  visualModelData?: NormalizedVisualModelData;
  media?: NormalizedMedia;
  flashcards?: NormalizedFlashcard[];
  interactiveQuestion?: NormalizedQuestion;
}

function normalizeJsonOrWebStep(step: LessonStep): NormalizedStep {
  return {
    id: step.id,
    stepNumber: step.stepNumber,
    type: step.type,
    title: step.title,
    titleRu: step.titleRu,
    subtitle: step.subtitle,
    subtitleRu: step.subtitleRu,
    content: step.content,
    contentRu: step.contentRu,
    highlightNotes: step.highlightNotes,
    highlightNotesRu: step.highlightNotesRu,
    masteryCheckpoint: step.masteryCheckpoint,
    visualModelData: normalizeJsonOrWebVisualModelData(step.visualModelData),
    media: normalizeJsonOrWebMedia(step.media),
    flashcards: step.flashcards?.map(normalizeJsonOrWebFlashcard),
    interactiveQuestion: step.interactiveQuestion
      ? normalizeJsonOrWebQuestion(step.interactiveQuestion)
      : undefined,
  };
}

function normalizeDartStep(val: DartValue): NormalizedStep {
  const p = asObj(val, 'LessonStep');
  const typeMember = enumMember(p.type, 'LessonStep.type');
  const type = STEP_TYPE_MAP[typeMember];
  if (!type) {
    throw new Error(`Unknown Dart LessonStepType: ${typeMember}`);
  }
  return {
    id: asStr(p.id) ?? '',
    stepNumber: asNum(p.stepNumber) ?? 0,
    type,
    title: asStr(p.title) ?? '',
    titleRu: asStr(p.titleRu),
    subtitle: asStr(p.subtitle),
    subtitleRu: asStr(p.subtitleRu),
    content: asStr(p.content) ?? '',
    contentRu: asStr(p.contentRu),
    highlightNotes: Array.isArray(p.highlightNotes) ? asStrList(p.highlightNotes) : undefined,
    highlightNotesRu: Array.isArray(p.highlightNotesRu) ? asStrList(p.highlightNotesRu) : undefined,
    masteryCheckpoint: asStr(p.masteryCheckpoint),
    visualModelData: normalizeDartVisualModelData(p.visualModelData),
    media: normalizeDartMedia(p.media),
    flashcards: Array.isArray(p.flashcards)
      ? p.flashcards.map(normalizeDartFlashcard)
      : undefined,
    interactiveQuestion:
      p.interactiveQuestion && p.interactiveQuestion !== null
        ? normalizeDartQuestion(p.interactiveQuestion)
        : undefined,
  };
}

interface NormalizedLesson {
  id: string;
  courseId: string;
  skillId: string;
  skillDomain?: string;
  communicativeFocus?: string;
  cefrLevel?: string;
  moduleId?: string;
  unitId?: string;
  canDoObjective?: string;
  canDoObjectiveRu?: string;
  prerequisites: string[];
  title: string;
  titleRu?: string;
  estimatedMinutes: number;
  summary: string;
  summaryRu?: string;
  requiresMastery: boolean;
  officialCefrDisclaimerUz?: string;
  officialCefrDisclaimerRu?: string;
  steps: NormalizedStep[];
  reinforcementExercise: NormalizedQuestion;
  alternateExercise?: NormalizedQuestion;
}

function normalizeJsonOrWebLesson(lesson: Lesson): NormalizedLesson {
  return {
    id: lesson.id,
    courseId: lesson.courseId,
    skillId: lesson.skillId,
    skillDomain: lesson.skillDomain,
    communicativeFocus: lesson.communicativeFocus,
    cefrLevel: lesson.cefrLevel,
    moduleId: lesson.moduleId,
    unitId: lesson.unitId,
    canDoObjective: lesson.canDoObjective,
    canDoObjectiveRu: lesson.canDoObjectiveRu,
    prerequisites: lesson.prerequisites ?? [],
    title: lesson.title,
    titleRu: lesson.titleRu,
    estimatedMinutes: lesson.estimatedMinutes,
    summary: lesson.summary,
    summaryRu: lesson.summaryRu,
    requiresMastery: lesson.requiresMastery ?? false,
    officialCefrDisclaimerUz: lesson.officialCefrDisclaimerUz,
    officialCefrDisclaimerRu: lesson.officialCefrDisclaimerRu,
    steps: lesson.steps.map(normalizeJsonOrWebStep),
    reinforcementExercise: normalizeJsonOrWebQuestion(lesson.reinforcementExercise),
    alternateExercise: lesson.alternateExercise
      ? normalizeJsonOrWebQuestion(lesson.alternateExercise)
      : undefined,
  };
}

function normalizeDartLesson(val: DartValue): NormalizedLesson {
  const p = asObj(val, 'Lesson');
  const stepsArr = Array.isArray(p.steps) ? p.steps : [];
  return {
    id: asStr(p.id) ?? '',
    courseId: asStr(p.courseId) ?? '',
    skillId: asStr(p.skillId) ?? '',
    skillDomain: asStr(p.skillDomain),
    communicativeFocus: asStr(p.communicativeFocus),
    cefrLevel: asStr(p.cefrLevel),
    moduleId: asStr(p.moduleId),
    unitId: asStr(p.unitId),
    canDoObjective: asStr(p.canDoObjective),
    canDoObjectiveRu: asStr(p.canDoObjectiveRu),
    prerequisites: asStrList(p.prerequisites),
    title: asStr(p.title) ?? '',
    titleRu: asStr(p.titleRu),
    estimatedMinutes: asNum(p.estimatedMinutes) ?? 0,
    summary: asStr(p.summary) ?? '',
    summaryRu: asStr(p.summaryRu),
    requiresMastery: asBool(p.requiresMastery) ?? false,
    officialCefrDisclaimerUz: asStr(p.officialCefrDisclaimerUz),
    officialCefrDisclaimerRu: asStr(p.officialCefrDisclaimerRu),
    steps: stepsArr.map(normalizeDartStep),
    reinforcementExercise: normalizeDartQuestion(p.reinforcementExercise),
    alternateExercise:
      p.alternateExercise && p.alternateExercise !== null
        ? normalizeDartQuestion(p.alternateExercise)
        : undefined,
  };
}

interface NormalizedRoadmapNode {
  id: string;
  courseId: string;
  skillId: string;
  skillDomain?: string;
  cefrLevel?: string;
  moduleId?: string;
  moduleTitle?: string;
  moduleTitleRu?: string;
  unitId?: string;
  canDoObjective?: string;
  canDoObjectiveRu?: string;
  nodeKind: string;
  isCheckpoint: boolean;
  hasRichExercise: boolean;
  taskKind?: string;
  title: string;
  titleRu?: string;
  description: string;
  descriptionRu?: string;
  prerequisites: string[];
  requiredScore: number;
  status: string;
  isReinforcement: boolean;
  targetLessonId?: string;
  estimatedMinutes: number;
  order: number;
}

function normalizeJsonOrWebNode(n: LearningPathNode): NormalizedRoadmapNode {
  return {
    id: n.id,
    courseId: n.courseId,
    skillId: n.skillId,
    skillDomain: n.skillDomain,
    cefrLevel: n.cefrLevel,
    moduleId: n.moduleId,
    moduleTitle: n.moduleTitle,
    moduleTitleRu: n.moduleTitleRu,
    unitId: n.unitId,
    canDoObjective: n.canDoObjective,
    canDoObjectiveRu: n.canDoObjectiveRu,
    nodeKind: n.nodeKind ?? 'lesson',
    isCheckpoint: n.isCheckpoint ?? false,
    hasRichExercise: n.hasRichExercise ?? false,
    taskKind: n.taskKind,
    title: n.title,
    titleRu: n.titleRu,
    description: n.description,
    descriptionRu: n.descriptionRu,
    prerequisites: n.prerequisites ?? [],
    requiredScore: n.requiredScore,
    status: n.status,
    isReinforcement: n.isReinforcement,
    targetLessonId: n.targetLessonId,
    estimatedMinutes: n.estimatedMinutes,
    order: n.order,
  };
}

function normalizeDartNode(val: DartValue): NormalizedRoadmapNode {
  const p = asObj(val, 'LearningPathNode');
  const nodeKindMember = p.nodeKind
    ? enumMember(p.nodeKind, 'LearningPathNode.nodeKind')
    : 'lesson';
  const statusMember = enumMember(p.status, 'LearningPathNode.status');
  return {
    id: asStr(p.id) ?? '',
    courseId: asStr(p.courseId) ?? '',
    skillId: asStr(p.skillId) ?? '',
    skillDomain: asStr(p.skillDomain),
    cefrLevel: asStr(p.cefrLevel),
    moduleId: asStr(p.moduleId),
    moduleTitle: asStr(p.moduleTitle),
    moduleTitleRu: asStr(p.moduleTitleRu),
    unitId: asStr(p.unitId),
    canDoObjective: asStr(p.canDoObjective),
    canDoObjectiveRu: asStr(p.canDoObjectiveRu),
    nodeKind: NODE_KIND_MAP[nodeKindMember] ?? nodeKindMember,
    isCheckpoint: asBool(p.isCheckpoint) ?? false,
    hasRichExercise: asBool(p.hasRichExercise) ?? false,
    taskKind: asStr(p.taskKind),
    title: asStr(p.title) ?? '',
    titleRu: asStr(p.titleRu),
    description: asStr(p.description) ?? '',
    descriptionRu: asStr(p.descriptionRu),
    prerequisites: asStrList(p.prerequisites),
    requiredScore: asNum(p.requiredScore) ?? 0,
    status: NODE_STATUS_MAP[statusMember] ?? statusMember,
    isReinforcement: asBool(p.isReinforcement) ?? false,
    targetLessonId: asStr(p.targetLessonId),
    estimatedMinutes: asNum(p.estimatedMinutes) ?? 0,
    order: asNum(p.order) ?? 0,
  };
}

function collectQuestions(lesson: NormalizedLesson): NormalizedQuestion[] {
  const list: NormalizedQuestion[] = [];
  for (const step of lesson.steps) {
    if (step.interactiveQuestion) {
      list.push(step.interactiveQuestion);
    }
  }
  list.push(lesson.reinforcementExercise);
  if (lesson.alternateExercise) {
    list.push(lesson.alternateExercise);
  }
  return list;
}

// ---------------------------------------------------------------------------
// Load Canonical JSON + Parse Flutter Dart Datasources Once
// ---------------------------------------------------------------------------

function extractPubspecFlutterAssets(pubspecContent: string): Set<string> {
  const assets = new Set<string>();
  const lines = pubspecContent.split(/\r?\n/);
  let inFlutter = false;
  let inAssets = false;
  let assetsIndent = -1;

  for (const rawLine of lines) {
    const trimmed = rawLine.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const indent = rawLine.length - rawLine.trimStart().length;

    if (indent === 0) {
      inFlutter = /^flutter\s*:(?:\s*(?:#.*)?)?$/.test(trimmed);
      inAssets = false;
      assetsIndent = -1;
      continue;
    }

    if (!inFlutter) continue;

    if (inAssets && (indent < assetsIndent || (indent === assetsIndent && !trimmed.startsWith('-')))) {
      inAssets = false;
      assetsIndent = -1;
    }

    if (!inAssets) {
      if (/^assets\s*:(?:\s*(?:#.*)?)?$/.test(trimmed)) {
        inAssets = true;
        assetsIndent = indent;
      }
      continue;
    }

    if (trimmed.startsWith('-')) {
      const itemBody = trimmed.slice(1).trim();
      if (!itemBody || itemBody.startsWith('#')) continue;

      let value = '';
      if (itemBody.startsWith("'") || itemBody.startsWith('"')) {
        const quote = itemBody[0];
        const endIdx = itemBody.indexOf(quote, 1);
        value = endIdx > 0 ? itemBody.slice(1, endIdx) : itemBody.slice(1);
      } else {
        const commentIdx = itemBody.indexOf('#');
        value = (commentIdx >= 0 ? itemBody.slice(0, commentIdx) : itemBody).trim();
      }
      if (value) assets.add(value);
    }
  }

  return assets;
}

function readJson<T>(repoRelativePath: string): T {
  return JSON.parse(readFileSync(path.resolve(process.cwd(), repoRelativePath), 'utf8')) as T;
}

interface CanonicalPlacementDocument {
  schemaVersion: number;
  documentType: string;
  courseId: string;
  cefrRange: string[];
  questions: Question[];
}

const canonicalSkeleton = readJson<CanonicalCefrSkeleton>('content/english/cefr-skeleton.json');
const canonicalA1 = readJson<CanonicalLevelCurriculum>('content/english/a1-curriculum.json');
const canonicalA2 = readJson<CanonicalLevelCurriculum>('content/english/a2-curriculum.json');
const canonicalB1 = readJson<CanonicalLevelCurriculum>('content/english/b1-curriculum.json');
const canonicalPlacement = readJson<CanonicalPlacementDocument>('content/english/placement-questions.json');
const canonicalStarterMedia = readJson<CanonicalMediaManifest>('content/english/starter-media.json');
const canonicalA1Media = readJson<CanonicalMediaManifest>('content/english/a1-media.json');
const canonicalA2Media = readJson<CanonicalMediaManifest>('content/english/a2-media.json');
const canonicalB1Media = readJson<CanonicalMediaManifest>('content/english/b1-media.json');
const canonicalPlacementMedia = readJson<CanonicalMediaManifest>('content/english/placement-media.json');

const dartParser = new DartDatasourceParser();
dartParser.parseFile('mobile/lib/data/datasources/english/cefr_skeleton_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/english/a1_lessons_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/english/a1_roadmap_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/english/a2_lessons_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/english/a2_roadmap_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/english/b1_lessons_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/english/b1_roadmap_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/english/placement_questions_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/questions_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/starter_lessons_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/logic_curriculum.dart');
dartParser.parseFile('mobile/lib/data/datasources/lessons_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/roadmaps_data.dart');
dartParser.parseFile('mobile/lib/data/datasources/courses_data.dart');

// ---------------------------------------------------------------------------
// 3-Way Parity Assertions (Canonical JSON <-> Web <-> Flutter)
// ---------------------------------------------------------------------------

describe('EnglishCurriculumParity — 3-way Canonical JSON <-> Web <-> Flutter parity', () => {
  it('enforces CEFR skeleton parity across Pre-A1 alignment, 6 levels, 22 modules, units, and disclaimers', () => {
    // Web vs Canonical JSON
    expect(ENGLISH_CEFR_SKELETON).toEqual(canonicalSkeleton);
    expect(ENGLISH_PRE_A1_ALIGNMENT).toEqual(canonicalSkeleton.preA1FoundationAlignment);
    expect(ENGLISH_CEFR_DISCLAIMERS.uz).toBe(canonicalSkeleton.officialCefrDisclaimerUz);
    expect(ENGLISH_CEFR_DISCLAIMERS.ru).toBe(canonicalSkeleton.officialCefrDisclaimerRu);
    expect(ENGLISH_CEFR_LEVEL_ORDER).toEqual(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
    expect(ENGLISH_CEFR_LEVELS).toHaveLength(6);

    // Flutter vs Canonical JSON
    expect(dartParser.get('cefrPreA1TargetLevel')).toBe('Pre-A1');
    expect(dartParser.get('cefrPreA1TargetLevel')).toBe(
      canonicalSkeleton.preA1FoundationAlignment.cefrLevel,
    );
    expect(dartParser.get('cefrPreA1TitleUz')).toBe(
      canonicalSkeleton.preA1FoundationAlignment.titleUz,
    );
    expect(dartParser.get('cefrPreA1TitleRu')).toBe(
      canonicalSkeleton.preA1FoundationAlignment.titleRu,
    );
    expect(dartParser.get('cefrPreA1RationaleUz')).toBe(
      canonicalSkeleton.preA1FoundationAlignment.noteUz,
    );
    expect(dartParser.get('cefrPreA1RationaleRu')).toBe(
      canonicalSkeleton.preA1FoundationAlignment.noteRu,
    );
    expect(dartParser.get('cefrPreA1LessonIds')).toEqual(
      canonicalSkeleton.preA1FoundationAlignment.foundationLessonIds,
    );
    expect(dartParser.get('cefrOfficialDisclaimerUz')).toBe(
      canonicalSkeleton.officialCefrDisclaimerUz,
    );
    expect(dartParser.get('cefrOfficialDisclaimerRu')).toBe(
      canonicalSkeleton.officialCefrDisclaimerRu,
    );

    const dartLevels = dartParser.get('cefrSkeletonLevels');
    expect(Array.isArray(dartLevels)).toBe(true);
    if (!Array.isArray(dartLevels)) return;
    expect(dartLevels).toHaveLength(6);

    const expectedModuleCounts = [4, 4, 4, 4, 3, 3];
    const expectedUnitCounts = [4, 4, 4, 4, 3, 3];
    let totalModules = 0;
    let totalUnits = 0;

    canonicalSkeleton.levels.forEach((canonLvl, idx) => {
      const webLvl = ENGLISH_CEFR_LEVELS[idx];
      const dartLvl = asObj(dartLevels[idx], `cefrSkeletonLevels[${idx}]`);

      expect(canonLvl.order).toBe(idx + 1);
      expect(webLvl.cefrLevel).toBe(canonLvl.cefrLevel);
      expect(webLvl.order).toBe(canonLvl.order);
      expect(webLvl.modules).toHaveLength(expectedModuleCounts[idx]);
      expect(webLvl.units).toHaveLength(expectedUnitCounts[idx]);

      expect(dartLvl.cefrLevel).toBe(canonLvl.cefrLevel);
      expect(dartLvl.order).toBe(canonLvl.order);
      expect(dartLvl.titleUz).toBe(canonLvl.titleUz);
      expect(dartLvl.titleRu).toBe(canonLvl.titleRu);
      expect(asStrList(dartLvl.canDoObjectivesUz)).toEqual(canonLvl.canDoObjectivesUz);
      expect(asStrList(dartLvl.canDoObjectivesRu)).toEqual(canonLvl.canDoObjectivesRu);
      expect(asStrList(dartLvl.prerequisites)).toEqual(canonLvl.prerequisites);
      expect(asStrList(dartLvl.grammarScope)).toEqual(canonLvl.grammarScope);
      expect(asStrList(dartLvl.vocabularyThemes)).toEqual(canonLvl.vocabularyThemes);
      expect(asStrList(dartLvl.plannedLessonIds)).toEqual(canonLvl.plannedLessonIds);
      expect(dartLvl.exitAssessmentNodeId).toBe(canonLvl.exitAssessmentNodeId);

      const dartModules = dartLvl.modules;
      expect(Array.isArray(dartModules)).toBe(true);
      if (!Array.isArray(dartModules)) return;
      expect(dartModules).toHaveLength(expectedModuleCounts[idx]);

      totalModules += canonLvl.modules.length;
      totalUnits += canonLvl.units.length;

      canonLvl.modules.forEach((canonMod, mIdx) => {
        const webMod = webLvl.modules[mIdx];
        const dartMod = asObj(dartModules[mIdx], `cefrSkeletonLevels[${idx}].modules[${mIdx}]`);

        expect(webMod).toEqual(canonMod);
        expect(dartMod.id).toBe(canonMod.id);
        expect(dartMod.cefrLevel).toBe(canonMod.cefrLevel);
        expect(dartMod.order).toBe(canonMod.order);
        expect(dartMod.titleUz).toBe(canonMod.titleUz);
        expect(dartMod.titleRu).toBe(canonMod.titleRu);
        expect(dartMod.canDoObjectiveUz).toBe(canonMod.canDoObjectiveUz);
        expect(dartMod.canDoObjectiveRu).toBe(canonMod.canDoObjectiveRu);
        expect(asStrList(dartMod.prerequisites)).toEqual(canonMod.prerequisites);
        expect(asStrList(dartMod.grammarScope)).toEqual(canonMod.grammarScope);
        expect(asStrList(dartMod.vocabularyThemes)).toEqual(canonMod.vocabularyThemes);
        expect(asStrList(dartMod.plannedLessonIds)).toEqual(canonMod.plannedLessonIds);
        expect(dartMod.checkpointNodeId).toBe(canonMod.checkpointNodeId);
      });
    });

    expect(totalModules).toBe(22);
    expect(totalUnits).toBe(22);

    // Cross-check A1, A2, and B1 skeletons against a1/a2/b1-curriculum.json
    const levelSkeletonPairs: Array<{
      skel: CanonicalCefrSkeleton['levels'][number];
      canon: CanonicalLevelCurriculum;
      exactOrder: boolean;
    }> = [
      { skel: canonicalSkeleton.levels[0], canon: canonicalA1, exactOrder: false },
      { skel: canonicalSkeleton.levels[1], canon: canonicalA2, exactOrder: true },
      { skel: canonicalSkeleton.levels[2], canon: canonicalB1, exactOrder: true },
    ];

    for (const { skel, canon, exactOrder } of levelSkeletonPairs) {
      if (exactOrder) {
        expect(skel.plannedLessonIds).toEqual(canon.lessonsOrder);
        expect(canon.lessons.map((l) => l.id)).toEqual(skel.plannedLessonIds);
      } else {
        expect(new Set(skel.plannedLessonIds)).toEqual(new Set(canon.lessonsOrder));
        expect(new Set(canon.lessons.map((l) => l.id))).toEqual(new Set(skel.plannedLessonIds));
      }
      expect(
        canon.modules.map((m) => ({
          id: m.id,
          cefrLevel: m.cefrLevel,
          order: m.order,
          titleUz: m.titleUz,
          titleRu: m.titleRu,
          prerequisites: m.prerequisites,
          plannedLessonIds: m.plannedLessonIds,
          checkpointNodeId: m.checkpointNodeId,
        })),
      ).toEqual(
        skel.modules.map((m) => ({
          id: m.id,
          cefrLevel: m.cefrLevel,
          order: m.order,
          titleUz: m.titleUz,
          titleRu: m.titleRu,
          prerequisites: m.prerequisites,
          plannedLessonIds: m.plannedLessonIds,
          checkpointNodeId: m.checkpointNodeId,
        })),
      );
    }
  });

  it('enforces course_eng_01 combined A1+A2+B1 lesson IDs (length 33, listening_01 first), skills, and starter/foundation IDs', () => {
    expect(ENGLISH_A1_CURRICULUM).toEqual(canonicalA1);
    expect(ENGLISH_A2_CURRICULUM).toEqual(canonicalA2);
    expect(ENGLISH_B1_CURRICULUM).toEqual(canonicalB1);

    const webCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01');
    expect(webCourse).toBeDefined();
    if (!webCourse) return;

    const dartCourses = dartParser.get('seedCourses');
    expect(Array.isArray(dartCourses)).toBe(true);
    if (!Array.isArray(dartCourses)) return;
    const dartCourseVal = dartCourses.find(
      (item) => isDartObject(item) && item.props.id === 'course_eng_01',
    );
    expect(dartCourseVal).toBeDefined();
    const dartCourse = asObj(dartCourseVal, 'seedCourses[course_eng_01]');

    expect(canonicalA1.lessonsOrder).toHaveLength(17);
    expect(canonicalA2.lessonsOrder).toHaveLength(8);
    expect(canonicalB1.lessonsOrder).toHaveLength(8);

    const expectedAllLessonsOrder = [
      ...canonicalA1.lessonsOrder,
      ...canonicalA2.lessonsOrder,
      ...canonicalB1.lessonsOrder,
    ];
    expect(expectedAllLessonsOrder).toHaveLength(33);
    expect(new Set(expectedAllLessonsOrder).size).toBe(33);
    expect(expectedAllLessonsOrder[0]).toBe('lesson_eng_listening_01');

    expect(ENGLISH_ALL_LESSONS_ORDER).toEqual(expectedAllLessonsOrder);
    expect(webCourse.lessons).toEqual(expectedAllLessonsOrder);
    expect(asStrList(dartCourse.lessons)).toEqual(expectedAllLessonsOrder);

    for (const canonLevel of [canonicalA1, canonicalA2, canonicalB1]) {
      expect(webCourse.skills).toEqual(canonLevel.skills);
      expect(asStrList(dartCourse.skills)).toEqual(canonLevel.skills);

      expect(webCourse.starterLessonId).toBe(canonLevel.starterLessonId);
      expect(dartCourse.starterLessonId).toBe(canonLevel.starterLessonId);

      expect(webCourse.foundationLessonIds).toEqual(canonLevel.foundationLessonIds);
      expect(asStrList(dartCourse.foundationLessonIds)).toEqual(canonLevel.foundationLessonIds);
    }
  });

  it('enforces 1:1 parity across all 31 A1+A2+B1 roadmap nodes (order 1..31) & chains on Canonical JSON, Web, and Flutter', () => {
    const canonA1Nodes = canonicalA1.roadmapNodes.map(normalizeJsonOrWebNode);
    const canonA2Nodes = canonicalA2.roadmapNodes.map(normalizeJsonOrWebNode);
    const canonB1Nodes = canonicalB1.roadmapNodes.map(normalizeJsonOrWebNode);
    const canonAllNodes = [...canonA1Nodes, ...canonA2Nodes, ...canonB1Nodes];

    const webA1Nodes = ENGLISH_A1_ROADMAP_NODES.map(normalizeJsonOrWebNode);
    const webA2Nodes = ENGLISH_A2_ROADMAP_NODES.map(normalizeJsonOrWebNode);
    const webB1Nodes = ENGLISH_B1_ROADMAP_NODES.map(normalizeJsonOrWebNode);
    const webAllNodes = ENGLISH_ALL_ROADMAP_NODES.map(normalizeJsonOrWebNode);
    const webSeedNodes = (SEED_ROADMAP_NODES.course_eng_01 ?? []).map(normalizeJsonOrWebNode);

    const dartA1Raw = dartParser.get('a1RoadmapNodes');
    const dartA2Raw = dartParser.get('a2RoadmapNodes');
    const dartB1Raw = dartParser.get('b1RoadmapNodes');
    expect(Array.isArray(dartA1Raw)).toBe(true);
    expect(Array.isArray(dartA2Raw)).toBe(true);
    expect(Array.isArray(dartB1Raw)).toBe(true);
    if (!Array.isArray(dartA1Raw) || !Array.isArray(dartA2Raw) || !Array.isArray(dartB1Raw)) {
      return;
    }
    const dartA1Nodes = dartA1Raw.map(normalizeDartNode);
    const dartA2Nodes = dartA2Raw.map(normalizeDartNode);
    const dartB1Nodes = dartB1Raw.map(normalizeDartNode);

    const dartSeedMap = asObj(dartParser.get('seedRoadmapNodes'), 'seedRoadmapNodes');
    const dartSeedEngRaw = dartSeedMap.course_eng_01;
    expect(Array.isArray(dartSeedEngRaw)).toBe(true);
    if (!Array.isArray(dartSeedEngRaw)) return;
    const dartSeedNodes = dartSeedEngRaw.map(normalizeDartNode);

    expect(canonA1Nodes).toHaveLength(15);
    expect(canonA2Nodes).toHaveLength(8);
    expect(canonB1Nodes).toHaveLength(8);
    expect(canonAllNodes).toHaveLength(31);
    expect(canonAllNodes.map((n) => n.order)).toEqual(
      Array.from({ length: 31 }, (_, i) => i + 1),
    );

    expect(webA1Nodes).toEqual(canonA1Nodes);
    expect(webA2Nodes).toEqual(canonA2Nodes);
    expect(webB1Nodes).toEqual(canonB1Nodes);
    expect(webAllNodes).toEqual(canonAllNodes);
    expect(webSeedNodes).toEqual(canonAllNodes);

    expect(dartA1Nodes).toEqual(canonA1Nodes);
    expect(dartA2Nodes).toEqual(canonA2Nodes);
    expect(dartB1Nodes).toEqual(canonB1Nodes);
    expect(dartSeedNodes).toEqual(canonAllNodes);

    // Cross-level chains & exit node IDs match cefr-skeleton.json
    expect(canonA1Nodes[canonA1Nodes.length - 1].id).toBe(
      canonicalSkeleton.levels[0].exitAssessmentNodeId,
    );
    expect(canonA2Nodes[0].prerequisites).toEqual(['node_eng_a1_exit']);
    expect(canonA2Nodes[canonA2Nodes.length - 1].id).toBe(
      canonicalSkeleton.levels[1].exitAssessmentNodeId,
    );
    expect(canonB1Nodes[0].prerequisites).toEqual(['node_eng_a2_exit']);
    expect(canonB1Nodes[canonB1Nodes.length - 1].id).toBe(
      canonicalSkeleton.levels[2].exitAssessmentNodeId,
    );

    // Structural referential integrity across all 31 nodes & 33 lessons
    const nodeIds = new Set(canonAllNodes.map((n) => n.id));
    const allCanonLessons = [...canonicalA1.lessons, ...canonicalA2.lessons, ...canonicalB1.lessons];
    const lessonById = new Map(allCanonLessons.map((l) => [l.id, l]));
    for (const node of canonAllNodes) {
      expect(node.targetLessonId).toBeDefined();
      const targetLesson = lessonById.get(node.targetLessonId ?? '');
      expect(targetLesson).toBeDefined();
      expect(targetLesson?.cefrLevel).toBe(node.cefrLevel);
      expect(targetLesson?.moduleId).toBe(node.moduleId);
      expect(targetLesson?.unitId).toBe(node.unitId);
      for (const prereq of node.prerequisites) {
        expect(nodeIds.has(prereq)).toBe(true);
      }
    }
  });

  it('enforces 1:1 parity across all 33 A1+A2+B1 lessons, 25 step media, 83 disk assets, pubspec.yaml, and 49 flashcards', () => {
    const dartA1LessonsMap = asObj(dartParser.get('a1LessonsData'), 'a1LessonsData');
    const dartA2LessonsMap = asObj(dartParser.get('a2LessonsData'), 'a2LessonsData');
    const dartB1LessonsMap = asObj(dartParser.get('b1LessonsData'), 'b1LessonsData');
    const dartSeedLessonsMap = asObj(dartParser.get('seedLessons'), 'seedLessons');
    const dartStarterLessonsMap = asObj(dartParser.get('starterLessons'), 'starterLessons');
    const dartA1FlashcardsRaw = dartParser.get('a1AllFlashcards');
    const dartA2FlashcardsRaw = dartParser.get('a2AllFlashcards');
    const dartB1FlashcardsRaw = dartParser.get('b1AllFlashcards');
    expect(Array.isArray(dartA1FlashcardsRaw)).toBe(true);
    expect(Array.isArray(dartA2FlashcardsRaw)).toBe(true);
    expect(Array.isArray(dartB1FlashcardsRaw)).toBe(true);
    if (
      !Array.isArray(dartA1FlashcardsRaw) ||
      !Array.isArray(dartA2FlashcardsRaw) ||
      !Array.isArray(dartB1FlashcardsRaw)
    ) {
      return;
    }

    const pubspecContent = readFileSync(
      path.resolve(process.cwd(), 'mobile/pubspec.yaml'),
      'utf8',
    );
    const flutterAssets = extractPubspecFlutterAssets(pubspecContent);
    expect(flutterAssets.has('assets/lesson_media/english/')).toBe(true);
    expect(flutterAssets.has('assets/lesson_media/english/a1/')).toBe(true);
    expect(flutterAssets.has('assets/lesson_media/english/a2/')).toBe(true);
    expect(flutterAssets.has('assets/lesson_media/english/b1/')).toBe(true);
    expect(flutterAssets.has('assets/lesson_media/english/placement/')).toBe(true);
    expect(flutterAssets.has('assets/lesson_media/english/b2/')).toBe(false);
    expect(flutterAssets.has('assets/lesson_media/english/c1/')).toBe(false);
    expect(flutterAssets.has('assets/lesson_media/english/c2/')).toBe(false);

    for (const deletedPath of [
      'content/english/b2-media.json',
      'content/english/svg/b2',
      'public/lesson-media/english/b2',
      'mobile/assets/lesson_media/english/b2',
    ]) {
      expect(
        existsSync(path.resolve(process.cwd(), deletedPath)),
        `Deleted B2 path should not exist: ${deletedPath}`,
      ).toBe(false);
    }

    const manifestAudioBySource = new Map(
      [
        ...canonicalStarterMedia.audio,
        ...canonicalA1Media.audio,
        ...canonicalA2Media.audio,
        ...canonicalB1Media.audio,
      ].map((a) => [a.canonicalSource, a]),
    );
    const manifestImageBySource = new Map(
      [
        ...canonicalStarterMedia.images,
        ...canonicalA1Media.images,
        ...canonicalA2Media.images,
        ...canonicalB1Media.images,
      ].map((i) => [i.canonicalSource, i]),
    );
    expect(manifestAudioBySource.size).toBe(68);
    expect(manifestImageBySource.size).toBe(15);
    expect(manifestAudioBySource.size).toBe(ENGLISH_ALL_AUDIO_ASSETS.length);
    expect(manifestImageBySource.size).toBe(ENGLISH_ALL_IMAGE_ASSETS.length);

    expect(canonicalA1.lessons).toHaveLength(17);
    expect(canonicalA2.lessons).toHaveLength(8);
    expect(canonicalB1.lessons).toHaveLength(8);
    expect(Object.keys(ENGLISH_A1_LESSONS)).toHaveLength(17);
    expect(Object.keys(ENGLISH_A2_LESSONS)).toHaveLength(8);
    expect(Object.keys(ENGLISH_B1_LESSONS)).toHaveLength(8);
    expect(Object.keys(ENGLISH_ALL_LESSONS)).toHaveLength(33);
    expect(Object.keys(dartA1LessonsMap)).toHaveLength(17);
    expect(Object.keys(dartA2LessonsMap)).toHaveLength(8);
    expect(Object.keys(dartB1LessonsMap)).toHaveLength(8);

    const levelBuckets = [
      {
        level: 'A1',
        canonLessons: canonicalA1.lessons,
        webRawMap: ENGLISH_A1_LESSONS,
        dartRawMap: dartA1LessonsMap,
        seedPermutedInDart: false,
      },
      {
        level: 'A2',
        canonLessons: canonicalA2.lessons,
        webRawMap: ENGLISH_A2_LESSONS,
        dartRawMap: dartA2LessonsMap,
        seedPermutedInDart: true,
      },
      {
        level: 'B1',
        canonLessons: canonicalB1.lessons,
        webRawMap: ENGLISH_B1_LESSONS,
        dartRawMap: dartB1LessonsMap,
        seedPermutedInDart: true,
      },
    ];

    let totalLessonsChecked = 0;
    let stepMediaCount = 0;
    const canonFlashcardsByLevel: Record<string, NormalizedFlashcard[]> = {
      A1: [],
      A2: [],
      B1: [],
    };
    const canonFlashcards: NormalizedFlashcard[] = [];

    for (const bucket of levelBuckets) {
      for (const rawCanonLesson of bucket.canonLessons) {
        totalLessonsChecked += 1;
        const canonLesson = normalizeJsonOrWebLesson(rawCanonLesson);
        const webRawLesson = bucket.webRawMap[canonLesson.id];
        expect(webRawLesson).toBeDefined();
        expect(ENGLISH_ALL_LESSONS[canonLesson.id]).toEqual(webRawLesson);
        const webLesson = normalizeJsonOrWebLesson(webRawLesson);
        const webSeedLesson = SEED_LESSONS[canonLesson.id];
        expect(webSeedLesson).toBeDefined();
        const normWebSeed = normalizeJsonOrWebLesson(webSeedLesson);
        const dartRawLesson = normalizeDartLesson(bucket.dartRawMap[canonLesson.id]);
        const dartSeedLesson = normalizeDartLesson(dartSeedLessonsMap[canonLesson.id]);

        // Exact raw lesson & step parity between Canonical, Web raw, and Flutter raw
        expect(webLesson).toEqual(canonLesson);
        expect(dartRawLesson).toEqual(canonLesson);

        // Runtime seedLessons parity: A1 unpermuted on Dart; A2/B1 identically permuted on Web & Dart
        if (bucket.seedPermutedInDart) {
          expect(dartSeedLesson).toEqual(normWebSeed);
        } else {
          expect(dartSeedLesson).toEqual(canonLesson);
        }

        // Starter lessons parity
        if (
          canonLesson.id === 'lesson_eng_starter' ||
          canonLesson.id === 'lesson_eng_foundation_02'
        ) {
          const webStarter = normalizeJsonOrWebLesson(STARTER_LESSONS[canonLesson.id]);
          const dartStarter = normalizeDartLesson(dartStarterLessonsMap[canonLesson.id]);
          expect(webStarter).toEqual(canonLesson);
          expect(dartStarter).toEqual(canonLesson);
        }

        // SEED_LESSONS non-question metadata parity
        expect({
          ...normWebSeed,
          steps: normWebSeed.steps.map((s) => ({ ...s, interactiveQuestion: undefined })),
          reinforcementExercise: undefined,
          alternateExercise: undefined,
        }).toEqual({
          ...canonLesson,
          steps: canonLesson.steps.map((s) => ({ ...s, interactiveQuestion: undefined })),
          reinforcementExercise: undefined,
          alternateExercise: undefined,
        });

        // Step media & flashcard asset checks
        for (const step of canonLesson.steps) {
          if (step.media) {
            stepMediaCount += 1;
            expect(step.media.reviewStatus).toBe('approved');
            expect(step.media.language).toBe('en');

            const canonRawStep = rawCanonLesson.steps.find((s) => s.id === step.id);
            const webRawStep = webRawLesson.steps.find((s) => s.id === step.id);
            expect(readApprovedLessonMedia(webRawStep?.media)).toBeDefined();

            if (step.media.kind === 'image') {
              expect(
                canonRawStep?.media?.transcript === undefined ||
                  canonRawStep?.media?.transcript === null,
              ).toBe(true);
              expect(
                webRawStep?.media?.transcript === undefined ||
                  webRawStep?.media?.transcript === null,
              ).toBe(true);
              expect(step.media.transcript).toBeUndefined();
              expect(manifestImageBySource.has(step.media.source)).toBe(true);
            } else {
              expect(step.media.kind).toBe('audio');
              expect(step.media.transcript?.trim().length).toBeGreaterThan(0);
              expect(step.media.durationSeconds).toBeGreaterThan(0);
              expect(manifestAudioBySource.has(step.media.source)).toBe(true);
              if (step.media.posterImage) {
                expect(manifestImageBySource.has(step.media.posterImage)).toBe(true);
              }
            }
          }

          if (step.flashcards) {
            for (const card of step.flashcards) {
              if (card.audioSrc) {
                expect(manifestAudioBySource.has(card.audioSrc)).toBe(true);
              }
              if (card.imageSrc) {
                expect(manifestImageBySource.has(card.imageSrc)).toBe(true);
              }
              canonFlashcardsByLevel[bucket.level].push(card);
              canonFlashcards.push(card);
            }
          }
        }
      }
    }

    expect(totalLessonsChecked).toBe(33);
    expect(stepMediaCount).toBe(25);
    expect(canonFlashcardsByLevel.A1).toHaveLength(17);
    expect(canonFlashcardsByLevel.A2).toHaveLength(16);
    expect(canonFlashcardsByLevel.B1).toHaveLength(16);
    expect(canonFlashcards).toHaveLength(49);

    const webA1Flashcards = ENGLISH_A1_FLASHCARDS.map(normalizeJsonOrWebFlashcard);
    const webA2Flashcards = ENGLISH_A2_FLASHCARDS.map(normalizeJsonOrWebFlashcard);
    const webB1Flashcards = ENGLISH_B1_FLASHCARDS.map(normalizeJsonOrWebFlashcard);
    const webAllFlashcards = ENGLISH_ALL_FLASHCARDS.map(normalizeJsonOrWebFlashcard);

    const dartA1Flashcards = dartA1FlashcardsRaw.map(normalizeDartFlashcard);
    const dartA2Flashcards = dartA2FlashcardsRaw.map(normalizeDartFlashcard);
    const dartB1Flashcards = dartB1FlashcardsRaw.map(normalizeDartFlashcard);
    const dartAllFlashcards = [
      ...dartA1Flashcards,
      ...dartA2Flashcards,
      ...dartB1Flashcards,
    ];

    expect(webA1Flashcards).toEqual(canonFlashcardsByLevel.A1);
    expect(webA2Flashcards).toEqual(canonFlashcardsByLevel.A2);
    expect(webB1Flashcards).toEqual(canonFlashcardsByLevel.B1);
    expect(webAllFlashcards).toEqual(canonFlashcards);

    expect(dartA1Flashcards).toEqual(canonFlashcardsByLevel.A1);
    expect(dartA2Flashcards).toEqual(canonFlashcardsByLevel.A2);
    expect(dartB1Flashcards).toEqual(canonFlashcardsByLevel.B1);
    expect(dartAllFlashcards).toEqual(canonFlashcards);

    // Every approved manifest asset (83 lesson + 3 placement = 86 total) exists on disk
    // in BOTH Web public/ and Flutter mobile/assets/ with identical SHA-256 bytes and headers
    const allCanonicalSources = new Set<string>([
      ...manifestAudioBySource.keys(),
      ...manifestImageBySource.keys(),
    ]);
    expect(allCanonicalSources.size).toBe(83);

    const placementAudioSources = canonicalPlacementMedia.audio.map((a) => a.canonicalSource);
    expect(placementAudioSources).toHaveLength(3);
    const allDiskSources = new Set<string>([...allCanonicalSources, ...placementAudioSources]);
    expect(allDiskSources.size).toBe(86);

    const pngMagic = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    let verifiedWavs = 0;
    let verifiedPngs = 0;

    for (const source of allDiskSources) {
      expect(source.startsWith('/lesson-media/english/')).toBe(true);
      const rel = source.slice('/lesson-media/'.length);
      const webFile = path.resolve(process.cwd(), 'public/lesson-media', rel);
      const flutterFile = path.resolve(process.cwd(), 'mobile/assets/lesson_media', rel);
      expect(existsSync(webFile), `Missing Web asset: ${webFile}`).toBe(true);
      expect(existsSync(flutterFile), `Missing Flutter asset: ${flutterFile}`).toBe(true);
      expect(statSync(webFile).size).toBeGreaterThan(0);
      expect(statSync(flutterFile).size).toBeGreaterThan(0);

      const webBytes = readFileSync(webFile);
      const flutterBytes = readFileSync(flutterFile);
      const webSha256 = createHash('sha256').update(webBytes).digest('hex');
      const flutterSha256 = createHash('sha256').update(flutterBytes).digest('hex');
      expect(flutterSha256, `SHA-256 mismatch for ${source}`).toBe(webSha256);

      if (source.endsWith('.wav')) {
        expect(webBytes.length).toBeGreaterThan(44);
        expect(webBytes.subarray(0, 4).toString('ascii')).toBe('RIFF');
        expect(webBytes.subarray(8, 12).toString('ascii')).toBe('WAVE');
        verifiedWavs += 1;
      } else if (source.endsWith('.png')) {
        expect(webBytes.subarray(0, 8).equals(pngMagic)).toBe(true);
        verifiedPngs += 1;
      }
    }

    expect(verifiedWavs).toBe(71);
    expect(verifiedPngs).toBe(15);
  });

  it('enforces 1:1 parity across all 98 questions (52 step + 33 reinforcement + 13 alternate), 9 modes, and permutation parity', () => {
    const dartA1LessonsMap = asObj(dartParser.get('a1LessonsData'), 'a1LessonsData');
    const dartA2LessonsMap = asObj(dartParser.get('a2LessonsData'), 'a2LessonsData');
    const dartB1LessonsMap = asObj(dartParser.get('b1LessonsData'), 'b1LessonsData');
    const dartSeedLessonsMap = asObj(dartParser.get('seedLessons'), 'seedLessons');

    const expectedModes = new Set([
      'multiple_choice',
      'text_input',
      'fill_blank',
      'word_match',
      'sentence_order',
      'error_correction',
      'conversation_completion',
      'speaking_prompt',
      'writing_prompt',
    ]);

    const levelSpecs = [
      {
        level: 'A1',
        canonLessons: canonicalA1.lessons,
        webRawQuestions: ENGLISH_A1_QUESTIONS,
        dartRawMap: dartA1LessonsMap,
        expectedCount: 42,
        seedPermutedInDart: false,
      },
      {
        level: 'A2',
        canonLessons: canonicalA2.lessons,
        webRawQuestions: ENGLISH_A2_QUESTIONS,
        dartRawMap: dartA2LessonsMap,
        expectedCount: 27,
        seedPermutedInDart: true,
      },
      {
        level: 'B1',
        canonLessons: canonicalB1.lessons,
        webRawQuestions: ENGLISH_B1_QUESTIONS,
        dartRawMap: dartB1LessonsMap,
        expectedCount: 29,
        seedPermutedInDart: true,
      },
    ];

    const allCanonQuestions: NormalizedQuestion[] = [];
    const allWebRawQuestions: NormalizedQuestion[] = [];
    const allDartRawQuestions: NormalizedQuestion[] = [];

    let stepQuestionCount = 0;
    let reinforcementCount = 0;
    let alternateCount = 0;

    for (const spec of levelSpecs) {
      const canonQuestions: NormalizedQuestion[] = [];
      const webRawQuestions = spec.webRawQuestions.map(normalizeJsonOrWebQuestion);
      const webSeedQuestions: NormalizedQuestion[] = [];
      const dartRawQuestions: NormalizedQuestion[] = [];
      const dartSeedQuestions: NormalizedQuestion[] = [];

      for (const rawCanonLesson of spec.canonLessons) {
        const canonLesson = normalizeJsonOrWebLesson(rawCanonLesson);
        const webSeedLesson = normalizeJsonOrWebLesson(SEED_LESSONS[canonLesson.id]);
        const dartRawLesson = normalizeDartLesson(spec.dartRawMap[canonLesson.id]);
        const dartSeedLesson = normalizeDartLesson(dartSeedLessonsMap[canonLesson.id]);

        for (const s of canonLesson.steps) {
          if (s.interactiveQuestion) stepQuestionCount += 1;
        }
        reinforcementCount += 1;
        if (canonLesson.alternateExercise) alternateCount += 1;

        canonQuestions.push(...collectQuestions(canonLesson));
        webSeedQuestions.push(...collectQuestions(webSeedLesson));
        dartRawQuestions.push(...collectQuestions(dartRawLesson));
        dartSeedQuestions.push(...collectQuestions(dartSeedLesson));
      }

      expect(canonQuestions).toHaveLength(spec.expectedCount);
      expect(new Set(canonQuestions.map((q) => q.questionType))).toEqual(expectedModes);

      // Raw unpermuted parity per level
      expect(webRawQuestions).toEqual(canonQuestions);
      expect(dartRawQuestions).toEqual(canonQuestions);

      if (!spec.seedPermutedInDart) {
        // A1: Dart seedLessons stays unpermuted; Web SEED_LESSONS permutes except q_eng_a1_u1_cp_main
        expect(dartSeedQuestions).toEqual(canonQuestions);
        expect(webSeedQuestions).toHaveLength(spec.expectedCount);
        canonQuestions.forEach((canonQ, idx) => {
          const webSeedQ = webSeedQuestions[idx];
          if (canonQ.id === 'q_eng_a1_u1_cp_main') {
            expect(webSeedQ).toEqual(canonQ);
            expect(webSeedQ.correctIndex).toBe(0);
            return;
          }

          if (OPTION_MODES.has(canonQ.questionType)) {
            expect(canonQ.correctIndex).toBeDefined();
            expect(webSeedQ.correctIndex).toBeDefined();
            expect([...webSeedQ.options].sort()).toEqual([...canonQ.options].sort());
            expect(webSeedQ.options[webSeedQ.correctIndex!]).toBe(
              canonQ.options[canonQ.correctIndex!],
            );
            expect({ ...webSeedQ, options: [], correctIndex: undefined }).toEqual({
              ...canonQ,
              options: [],
              correctIndex: undefined,
            });
          } else {
            expect(webSeedQ).toEqual(canonQ);
          }
        });
      } else {
        // A2 & B1: raw correctIndex === 0, Web SEED_LESSONS === Dart seedLessons 1:1
        const distinctPermutedIndices = new Set<number>();
        expect(webSeedQuestions).toEqual(dartSeedQuestions);
        expect(webSeedQuestions).toHaveLength(spec.expectedCount);

        canonQuestions.forEach((canonQ, idx) => {
          const webSeedQ = webSeedQuestions[idx];
          const dartSeedQ = dartSeedQuestions[idx];
          if (OPTION_MODES.has(canonQ.questionType)) {
            expect(canonQ.correctIndex).toBe(0);
            expect(webSeedQ.correctIndex).toBeDefined();
            expect(dartSeedQ.correctIndex).toBe(webSeedQ.correctIndex);
            distinctPermutedIndices.add(webSeedQ.correctIndex!);
            expect([...webSeedQ.options].sort()).toEqual([...canonQ.options].sort());
            expect(webSeedQ.options[webSeedQ.correctIndex!]).toBe(
              canonQ.options[canonQ.correctIndex!],
            );
            expect({ ...webSeedQ, options: [], correctIndex: undefined }).toEqual({
              ...canonQ,
              options: [],
              correctIndex: undefined,
            });
          } else {
            expect(webSeedQ).toEqual(canonQ);
            expect(dartSeedQ).toEqual(canonQ);
          }
        });
        expect(distinctPermutedIndices.size).toBeGreaterThanOrEqual(3);
      }

      allCanonQuestions.push(...canonQuestions);
      allWebRawQuestions.push(...webRawQuestions);
      allDartRawQuestions.push(...dartRawQuestions);
    }

    expect(stepQuestionCount).toBe(52);
    expect(reinforcementCount).toBe(33);
    expect(alternateCount).toBe(13);
    expect(allCanonQuestions).toHaveLength(98);
    expect(new Set(allCanonQuestions.map((q) => q.id)).size).toBe(98);
    expect(new Set(allCanonQuestions.map((q) => q.questionType))).toEqual(expectedModes);
    expect(ENGLISH_ALL_QUESTIONS.map(normalizeJsonOrWebQuestion)).toEqual(allCanonQuestions);
    expect(allWebRawQuestions).toEqual(allCanonQuestions);
    expect(allDartRawQuestions).toEqual(allCanonQuestions);
  });

  it('enforces explicit T2-F4-03 disambiguation on lesson_eng_listening_01 / q_eng_listening_01 across Canonical, Web, and Flutter', () => {
    const canonListening = normalizeJsonOrWebLesson(
      canonicalA1.lessons.find((l) => l.id === 'lesson_eng_listening_01')!,
    );
    const webListening = normalizeJsonOrWebLesson(SEED_LESSONS.lesson_eng_listening_01);
    const dartA1Map = asObj(dartParser.get('a1LessonsData'), 'a1LessonsData');
    const dartListening = normalizeDartLesson(dartA1Map.lesson_eng_listening_01);

    for (const lesson of [canonListening, webListening, dartListening]) {
      const audioStep = lesson.steps.find((s) => s.media?.kind === 'audio');
      expect(audioStep?.media?.transcript).toContain('quarter past three');
      expect(audioStep?.media?.transcript).toContain('in the afternoon');

      const q = lesson.steps.find((s) => s.interactiveQuestion?.id === 'q_eng_listening_01')
        ?.interactiveQuestion;
      expect(q).toBeDefined();
      if (!q) return;

      expect(q.options).toContain('03:15 (quarter past three AM)');
      expect(q.options).toContain('15:15 (quarter past three)');
      expect(q.options[q.correctIndex!]).toBe('15:15 (quarter past three)');
      expect(q.mistakeFeedbackByOption['03:15 (quarter past three AM)']?.uz).toContain(
        'in the afternoon',
      );
      expect(q.mistakeFeedbackByOption['03:15 (quarter past three AM)']?.ru).toContain(
        'in the afternoon',
      );
    }
  });

  it('enforces 3-way parity across 12 A1-B1 placement questions, 3 placement WAVs, permutation parity, and non-collision', () => {
    expect(canonicalPlacement.schemaVersion).toBe(1);
    expect(canonicalPlacement.documentType).toBe('placement_bank');
    expect(canonicalPlacement.courseId).toBe('course_eng_01');
    expect(canonicalPlacement.cefrRange).toEqual(['A1', 'A2', 'B1']);
    expect(canonicalPlacement.questions).toHaveLength(12);

    expect(canonicalPlacementMedia.courseId).toBe('course_eng_01');
    expect(canonicalPlacementMedia.language).toBe('en');
    expect(canonicalPlacementMedia.reviewStatus).toBe('approved');
    expect(canonicalPlacementMedia.audio).toHaveLength(3);
    expect(canonicalPlacementMedia.images).toHaveLength(0);

    const placementMediaById = new Map(
      canonicalPlacementMedia.audio.map((entry) => [entry.id, entry]),
    );
    expect(placementMediaById.size).toBe(3);

    const lessonQuestionIds = new Set(ENGLISH_ALL_QUESTIONS.map((q) => q.id));
    const lessonPrompts = new Set(
      ENGLISH_ALL_QUESTIONS.flatMap((q) => [q.text.trim(), (q.textRu ?? '').trim()].filter(Boolean)),
    );
    expect(lessonQuestionIds.size).toBe(98);

    const cefrDifficultyMap: Record<string, string> = {
      A1: 'easy',
      A2: 'medium',
      B1: 'hard',
    };
    const skillsMap = new Map<string, Set<string>>();

    for (const q of canonicalPlacement.questions) {
      expect(q.courseId).toBe('course_eng_01');
      expect(q.isPlacement).toBe(true);
      expect(q.questionType).toBe('multiple_choice');
      expect(['A1', 'A2', 'B1']).toContain(q.cefrLevel);
      expect(['B2', 'C1', 'C2']).not.toContain(q.cefrLevel);
      expect(q.difficulty).toBe(cefrDifficultyMap[q.cefrLevel!]);
      expect(q.options).toHaveLength(4);
      expect(q.correctIndex).toBeGreaterThanOrEqual(0);
      expect(q.correctIndex).toBeLessThan(4);
      expect(q.text).not.toContain('Audio context:');
      expect(q.textRu ?? '').not.toContain('Audio context:');
      expect(lessonQuestionIds.has(q.id)).toBe(false);
      expect(lessonPrompts.has(q.text.trim())).toBe(false);
      if (q.textRu) {
        expect(lessonPrompts.has(q.textRu.trim())).toBe(false);
      }

      expect(q.mistakeFeedbackByOption).toBeDefined();
      expect(Object.keys(q.mistakeFeedbackByOption ?? {}).sort()).toEqual([...q.options].sort());
      for (const option of q.options) {
        const fb = q.mistakeFeedbackByOption?.[option];
        expect(fb?.uz.trim().length ?? 0).toBeGreaterThan(0);
        expect(fb?.ru.trim().length ?? 0).toBeGreaterThan(0);
      }

      if (!skillsMap.has(q.skillId)) {
        skillsMap.set(q.skillId, new Set<string>());
      }
      skillsMap.get(q.skillId)!.add(q.cefrLevel!);

      if (q.skillId === 'skill_eng_listening') {
        expect(q.media).toBeDefined();
        expect(q.media?.kind).toBe('audio');
        expect(q.media?.language).toBe('en');
        expect(q.media?.reviewStatus).toBe('approved');
        expect(q.media?.provenance).toBe('local-system-speech');
        expect(q.media?.durationSeconds).toBeGreaterThan(0);
        expect(readApprovedLessonMedia(q.media)).toBeDefined();

        const manifestAudio = placementMediaById.get(q.media?.id ?? '');
        expect(manifestAudio).toBeDefined();
        expect(manifestAudio?.canonicalSource).toBe(q.media?.source);
        expect(manifestAudio?.transcript).toBe(q.media?.transcript);
        expect(manifestAudio?.durationSeconds).toBe(q.media?.durationSeconds);
        expect(manifestAudio?.reviewStatus).toBe('approved');

        const turns = (q.media?.transcript ?? '')
          .split('\n')
          .map((line) => line.replace(/^[^:]+:\s*/, '').trim())
          .filter((turn) => turn.length >= 20);
        expect(turns.length).toBeGreaterThan(0);
        for (const turn of turns) {
          expect(q.text).not.toContain(turn);
          expect(q.textRu ?? '').not.toContain(turn);
        }
      } else {
        expect(q.media).toBeUndefined();
        expect(q.audioSimText).toBeUndefined();
      }
    }

    expect(Array.from(skillsMap.keys()).sort()).toEqual([
      'skill_eng_grammar',
      'skill_eng_listening',
      'skill_eng_reading',
      'skill_eng_vocab',
    ]);
    for (const levels of skillsMap.values()) {
      expect(Array.from(levels).sort()).toEqual(['A1', 'A2', 'B1']);
    }

    const canonRawNormalized = canonicalPlacement.questions.map(normalizeJsonOrWebQuestion);
    const canonPermuted = canonicalPlacement.questions.map(permuteQuestionOptions);
    const canonPermutedNormalized = canonPermuted.map(normalizeJsonOrWebQuestion);

    const webPermuted = PLACEMENT_QUESTIONS.course_eng_01 ?? [];
    expect(webPermuted).toHaveLength(12);
    const webPermutedNormalized = webPermuted.map(normalizeJsonOrWebQuestion);

    const dartRawVal = dartParser.get('englishPlacementQuestionsRaw');
    expect(Array.isArray(dartRawVal)).toBe(true);
    if (!Array.isArray(dartRawVal)) return;
    const dartRawNormalized = dartRawVal.map(normalizeDartQuestion);

    const dartPlacementMap = asObj(dartParser.get('placementQuestionsData'), 'placementQuestionsData');
    const dartPermutedVal = dartPlacementMap.course_eng_01;
    expect(Array.isArray(dartPermutedVal)).toBe(true);
    if (!Array.isArray(dartPermutedVal)) return;
    const dartPermutedNormalized = dartPermutedVal.map(normalizeDartQuestion);

    expect(dartRawNormalized).toEqual(canonRawNormalized);
    expect(webPermutedNormalized).toEqual(canonPermutedNormalized);
    expect(dartPermutedNormalized).toEqual(canonPermutedNormalized);
    expect(dartPermutedNormalized).toEqual(webPermutedNormalized);

    const distinctPermutedIndices = new Set<number>();
    webPermuted.forEach((wq, idx) => {
      expect(readApprovedLessonMedia(wq.media)?.source).toBe(
        canonicalPlacement.questions[idx].media?.source,
      );
      if (wq.skillId === 'skill_eng_listening') {
        expect(readApprovedLessonMedia(wq.media)).toBeDefined();
      }
      if (wq.correctIndex !== undefined) {
        distinctPermutedIndices.add(wq.correctIndex);
      }
    });
    expect(distinctPermutedIndices.size).toBeGreaterThanOrEqual(3);

    const rawReadingA1 = canonRawNormalized.find((q) => q.id === 'q_eng_place_reading_a1');
    const webReadingA1 = webPermutedNormalized.find((q) => q.id === 'q_eng_place_reading_a1');
    const dartReadingA1 = dartPermutedNormalized.find((q) => q.id === 'q_eng_place_reading_a1');
    expect(rawReadingA1?.correctIndex).toBe(2);
    expect(rawReadingA1?.options[2]).toBe('On Wednesday at 11:00 AM');
    expect(webReadingA1?.correctIndex).toBe(3);
    expect(webReadingA1?.options[3]).toBe('On Wednesday at 11:00 AM');
    expect(dartReadingA1?.correctIndex).toBe(3);
    expect(dartReadingA1?.options[3]).toBe('On Wednesday at 11:00 AM');
  });

  it('supports braced early returns and nested blocks in DartDatasourceParser.execStatement', () => {
    const parser = new DartDatasourceParser();
    parser.parseSource(
      `
      String testBracedIfReturn(bool flag, bool nestedFlag) {
        if (flag) {
          final inner = 'yes';
          if (nestedFlag) {
            return inner;
            if (false) {
              return 'unreachable';
            }
          }
          return 'outer-yes';
        } else {
          {
            return 'no-from-nested-block';
          }
        }
      }

      String testSequentialFallthrough(bool first) {
        if (first) {
          final a = 'first-only';
        }
        return 'fallthrough';
      }

      final items = ['a', 'b'];
      final mappedWithBracedReturn = items.map((item) {
        if (item == 'a') {
          return 'alpha';
        }
        return item;
      }).toList();

      final outTrueNested = testBracedIfReturn(true, true);
      final outTrueOuter = testBracedIfReturn(true, false);
      final outFalse = testBracedIfReturn(false, false);
      final outFallthrough = testSequentialFallthrough(true);
      `,
      'braced_early_return_regression.dart',
    );

    expect(parser.get('outTrueNested')).toBe('yes');
    expect(parser.get('outTrueOuter')).toBe('outer-yes');
    expect(parser.get('outFalse')).toBe('no-from-nested-block');
    expect(parser.get('outFallthrough')).toBe('fallthrough');
    expect(parser.get('mappedWithBracedReturn')).toEqual(['alpha', 'b']);

    expect(() =>
      parser.parseSource(
        "String f(bool flag) { if (flag) { return 'yes'; }\nfinal out = f(true);",
        'unclosed.dart',
      ),
    ).toThrow(/Expected '\}'/);

    expect(() =>
      parser.parseSource(
        "String f(bool flag) { if (flag) { return 'yes';",
        'unclosed_uninvoked.dart',
      ),
    ).toThrow(/Expected '\}'/);

    expect(() =>
      parser.parseSource(
        "final out = ['a'].map((item) { if (item == 'a') { return 'yes'; }).toList();",
        'unclosed_lambda.dart',
      ),
    ).toThrow(/Expected '\}'/);

    expect(() =>
      parser.parseSource(
        "String f(bool flag) { if (flag) { return 'yes'; if (false) { } } final out = f(true);",
        'unclosed_nested_tail.dart',
      ),
    ).toThrow(/Expected '\}'/);

    expect(() =>
      parser.parseSource(
        'final Map<String, dynamic x = {};',
        'unclosed_generic.dart',
      ),
    ).toThrow(/Expected '>'/);

    expect(() =>
      parser.parseSource(
        'class Unclosed { int x = 1;',
        'unclosed_class.dart',
      ),
    ).toThrow(/Expected '\}'/);
  });
});
