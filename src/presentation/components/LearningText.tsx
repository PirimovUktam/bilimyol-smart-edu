import { Fragment } from 'react';
import katex from 'katex';

export function Formula({ source, display = false }: { source: string; display?: boolean }) {
  const className = display ? 'block max-w-full overflow-x-auto py-2 text-center' : 'inline-block max-w-full align-middle';
  if (source.length > 2000) return <code className={className}>{source}</code>;
  try {
    const html = katex.renderToString(source, {
      output: 'mathml',
      displayMode: display,
      trust: false,
      strict: 'ignore',
      maxExpand: 150,
      maxSize: 16,
    });
    return <span className={className} dangerouslySetInnerHTML={{ __html: html }} />;
  } catch {
    return <code className={className}>{source}</code>;
  }
}

const markup = /(```[^\n`]*\r?\n[\s\S]*?```|\$\$[\s\S]+?\$\$|\$[^\n$]+\$|`[^\n`]+`)/g;

export function LearningText({ text }: { text: string }) {
  return (
    <div className="min-w-0 break-words whitespace-pre-wrap leading-relaxed">
      {text.split(markup).map((part, index) => {
        if (index % 2 === 0) return <Fragment key={index}>{part}</Fragment>;
        if (part.startsWith('```')) {
          const end = part.indexOf('\n');
          const language = part.slice(3, end).trim();
          return (
            <div key={index} className="my-3 overflow-hidden rounded-xl bg-navy text-indigo-50">
              {language && <p className="border-b border-white/15 px-3 py-2 text-xs font-semibold">{language}</p>}
              <pre className="overflow-x-auto p-3 text-sm whitespace-pre"><code>{part.slice(end + 1, -3).trimEnd()}</code></pre>
            </div>
          );
        }
        if (part.startsWith('$$')) return <Formula key={index} source={part.slice(2, -2)} display />;
        if (part.startsWith('$')) return <Formula key={index} source={part.slice(1, -1)} />;
        return <code key={index} className="rounded bg-sand px-1.5 py-0.5 text-brand-dark">{part.slice(1, -1)}</code>;
      })}
    </div>
  );
}
