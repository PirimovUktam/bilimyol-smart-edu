import { useEffect, useRef, useState, type FormEvent } from 'react';
import { Search } from 'lucide-react';
import { Button } from '@/presentation/components/Button';

type Definition = { partOfSpeech: string; definition: string; example?: string };
type Entry = { phonetic?: string; definitions: Definition[] };

function getEntry(body: unknown): Entry | null {
  if (!Array.isArray(body)) return null;
  const definitions: Definition[] = [];
  let phonetic: string | undefined;
  for (const entry of body.slice(0, 4)) {
    if (!entry || typeof entry !== 'object') continue;
    if (!phonetic) {
      const phonetics: unknown[] = Array.isArray(entry.phonetics) ? entry.phonetics : [];
      const alternate = phonetics.find((item): item is { text: string } =>
        Boolean(item && typeof item === 'object' && 'text' in item && typeof item.text === 'string' && item.text.trim()));
      const hint = typeof entry.phonetic === 'string' && entry.phonetic.trim() ? entry.phonetic : alternate?.text;
      if (hint) phonetic = hint.slice(0, 100);
    }
    if (!Array.isArray(entry.meanings)) continue;
    for (const meaning of entry.meanings.slice(0, 6)) {
      if (!meaning || !Array.isArray(meaning.definitions)) continue;
      const first = meaning.definitions.find((item: unknown) => item && typeof item === 'object' && 'definition' in item && typeof item.definition === 'string' && item.definition.trim());
      if (!first) continue;
      definitions.push({ partOfSpeech: typeof meaning.partOfSpeech === 'string' ? meaning.partOfSpeech.slice(0, 40) : '',
        definition: first.definition.slice(0, 650), example: typeof first.example === 'string' ? first.example.slice(0, 300) : undefined });
      if (definitions.length === 3) return { phonetic, definitions };
    }
  }
  return definitions.length ? { phonetic, definitions } : null;
}

export function DictionaryLookup() {
  const [word, setWord] = useState('');
  const [result, setResult] = useState<{ word: string; entry: Entry } | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const pending = useRef<AbortController | null>(null);
  useEffect(() => () => { pending.current?.abort(); pending.current = null; }, []);

  const lookup = async (event: FormEvent) => {
    event.preventDefault();
    if (pending.current) return;
    const query = word.trim().toLowerCase();
    setResult(null);
    setError('');
    if (!/^[a-z]+(?:[-'][a-z]+)*$/.test(query) || query.length > 40) {
      setError('Bitta inglizcha so‘z kiriting. Masalan: hello.');
      return;
    }
    const controller = new AbortController();
    pending.current = controller;
    setLoading(true);
    const timeout = window.setTimeout(() => controller.abort(), 7500);
    try {
      const response = await fetch('https://api.dictionaryapi.dev/api/v2/entries/en/' + encodeURIComponent(query), {
        signal: controller.signal, credentials: 'omit', referrerPolicy: 'no-referrer',
      });
      const entry = response.ok ? getEntry(await response.json()) : null;
      if (pending.current !== controller) return;
      if (entry) setResult({ word: query, entry });
      else if (response.status === 404 || response.ok) setError('Bu so‘z uchun ta’rif topilmadi. Imlo yoki boshqa so‘zni tekshiring.');
      else setError('Lug‘at hozir javob bermayapti. Keyinroq qayta urinib ko‘ring.');
    } catch {
      if (pending.current === controller) setError('Lug‘atga ulanib bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.');
    } finally {
      window.clearTimeout(timeout);
      if (pending.current === controller) { pending.current = null; setLoading(false); }
    }
  };

  return <div className="space-y-3">
    <p className="text-sm text-slatefine">So‘zning inglizcha ta’rifi, talaffuzi va mavjud misolini toping.</p>
    <form onSubmit={(event) => void lookup(event)} className="flex flex-wrap items-end gap-2">
      <label className="min-w-0 flex-1 basis-40 text-sm font-bold">Inglizcha so‘z
        <input type="text" value={word} maxLength={40} autoComplete="off" spellCheck={false} onChange={(event) => setWord(event.target.value)}
          placeholder="hello" className="form-input mt-1 px-3" />
      </label>
      <Button type="submit" isLoading={loading} disabled={!word.trim()} leftIcon={<Search aria-hidden="true" className="size-4" />}>So‘zni izlash</Button>
    </form>
    {error && <p role="alert" className="rounded-xl bg-rose-50 p-3 text-sm text-coral">{error}</p>}
    {result && <section aria-live="polite" className="rounded-card border border-hairline bg-canvas p-4">
      <h3 lang="en" className="font-display text-xl font-bold">{result.word} <span className="text-sm text-slatefine">{result.entry.phonetic}</span></h3>
      <ol lang="en" className="mt-3 space-y-3">{result.entry.definitions.map(({ partOfSpeech, definition, example }, index) => <li key={index}>
        {partOfSpeech && <p className="text-xs font-bold text-brand-dark">{partOfSpeech}</p>}
        <p className="break-words text-sm">{definition}</p>{example && <p className="mt-1 break-words text-sm italic text-slatefine">{example}</p>}
      </li>)}</ol>
    </section>}
    <p className="text-xs text-slatefine">Manba: <a className="font-bold underline" href="https://dictionaryapi.dev/" target="_blank" rel="noreferrer">Free Dictionary API</a></p>
  </div>;
}
