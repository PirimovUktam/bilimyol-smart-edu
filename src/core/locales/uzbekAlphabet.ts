const currentLetters: Record<string, string> = {
  o: 'ö', O: 'Ö', g: 'ğ', G: 'Ğ', s: 'ş', S: 'Ş', c: 'ç', C: 'Ç',
};

const legacyLetters: Record<string, string> = {
  ö: "o'", Ö: "O'", ğ: "g'", Ğ: "G'", ş: 'sh', Ş: 'Sh', ç: 'ch', Ç: 'Ch',
};

// Apply only to fields authored in Uzbek. Protect inline code, links and email.
export function updatedUzbekSpelling(text: string): string {
  if (typeof text !== 'string') return text;
  return text.replace(
    /\x60{3}[\s\S]*?\x60{3}|(?<!\p{L})\x60[^\x60\n]+\x60|https?:\/\/[^\s<>]+|[\w.+-]+@[\w.-]+\.[a-z]{2,}|\bo['’‘ʻʼ´]clock\b|([og])(?:[‘ʻʼ´]|['’\x60](?=\p{L}))|([sc])h/giu,
    (token, vowel?: string, digraph?: string) => {
      const initial = vowel ?? digraph;
      return (initial && currentLetters[initial]) || token;
    },
  );
}

// Match against existing Uzbek rules without changing the original text.
export function legacyUzbekSpelling(text: string): string {
  return text.normalize('NFC').replace(/[öÖğĞşŞçÇ]/g, (letter) => legacyLetters[letter]);
}

// The older English lessons mix Uzbek instructions with English examples.
const mixedLessonUzbekWords = new Set([
  'ajratish ajratishga bajarilishi birinchi borish boshlaganda boshlanadi boshlanish boshqa',
  'chiqarish chiqindini chiroqlar chiroqlarni chorshanba chuchuk ergash farqlash',
  'ichida ikkinchi inglizcha ishga ishlangan ishlatiladi kamaytirish',
  'kech kechikdi kechikkanini kechroq kelish kelishni kirish kirishida kishidan kishining',
  'nechada notanish ochilgan ochiq olish payshanba qachonga qaytarish qilish qisqacha',
  'rejalashtirilgan salomlashish seshanba shakli shart shaxs shu shuning sirpanchiq',
  'ta’mirlash takrorlash tanishtirish tasdiqlovchi tekshiring tezlashdi topish turishni',
  'tushdan tushuncha tuzatilishi uchala uchinchi uchrashadi uchrashuv uchrashuvning uchun',
  'vaqtincha xayrlashayotganda yashirin yetishmagan',
].join(' ').split(' '));

export function updatedCourseText(text: string, courseId: string): string {
  if (typeof text !== 'string') return text;
  if (courseId !== 'course_eng_01') return updatedUzbekSpelling(text);
  return text.replace(
    /https?:\/\/[^\s<>]+|[\w.+-]+@[\w.-]+\.[a-z]{2,}|\p{L}+(?:[’‘ʻʼ']\p{L}+)*/giu,
    (word) => mixedLessonUzbekWords.has(word.toLowerCase()) || /[og][‘ʻʼ]/iu.test(word)
      ? updatedUzbekSpelling(word)
      : word,
  );
}
