const _currentLetters = {
  'o': 'ö',
  'O': 'Ö',
  'g': 'ğ',
  'G': 'Ğ',
  's': 'ş',
  'S': 'Ş',
  'c': 'ç',
  'C': 'Ç',
};

const _legacyLetters = {
  'ö': "o'",
  'Ö': "O'",
  'ğ': "g'",
  'Ğ': "G'",
  'ş': 'sh',
  'Ş': 'Sh',
  'ç': 'ch',
  'Ç': 'Ch',
};

final _legacyPattern = RegExp(
  r"\x60{3}[\s\S]*?\x60{3}|(?<!\p{L})\x60[^\x60\n]+\x60|https?://[^\s<>]+|[\w.+-]+@[\w.-]+\.[a-z]{2,}|\bo['’‘ʻʼ´]clock\b|([og])(?:[‘ʻʼ´]|['’\x60](?=\p{L}))|([sc])h",
  caseSensitive: false,
  unicode: true,
);

final _currentPattern = RegExp(
  r'[öÖğĞşŞçÇ]|[oO]\u0308|[gG]\u0306|[sScC]\u0327',
);

/// Converts only fields authored in Uzbek.
String updatedUzbekSpelling(String text) => text.replaceAllMapped(
  _legacyPattern,
  (match) => _currentLetters[match[1] ?? match[2]] ?? match[0]!,
);

String legacyUzbekSpelling(String text) => text.replaceAllMapped(
  _currentPattern,
  (match) {
    final letter = match[0]!;
    final composed = letter.length == 1 ? letter : _currentLetters[letter[0]]!;
    return _legacyLetters[composed]!;
  },
);

// The older English lessons mix Uzbek instructions with English examples.
final _mixedLessonUzbekWords =
    ('ajratish ajratishga bajarilishi birinchi borish boshlaganda boshlanadi boshlanish boshqa '
            'chiqarish chiqindini chiroqlar chiroqlarni chorshanba chuchuk ergash farqlash '
            'ichida ikkinchi inglizcha ishga ishlangan ishlatiladi kamaytirish '
            'kech kechikdi kechikkanini kechroq kelish kelishni kirish kirishida kishidan kishining '
            'nechada notanish ochilgan ochiq olish payshanba qachonga qaytarish qilish qisqacha '
            'rejalashtirilgan salomlashish seshanba shakli shart shaxs shu shuning sirpanchiq '
            'ta’mirlash takrorlash tanishtirish tasdiqlovchi tekshiring tezlashdi topish turishni '
            'tushdan tushuncha tuzatilishi uchala uchinchi uchrashadi uchrashuv uchrashuvning uchun '
            'vaqtincha xayrlashayotganda yashirin yetishmagan')
        .split(' ')
        .toSet();

final _mixedLessonToken = RegExp(
  r"https?://[^\s<>]+|[\w.+-]+@[\w.-]+\.[a-z]{2,}|\p{L}+(?:[’‘ʻʼ']\p{L}+)*",
  caseSensitive: false,
  unicode: true,
);
final _oldUzbekVowel = RegExp('[og][‘ʻʼ]', caseSensitive: false);

String updatedCourseText(String text, String courseId) {
  if (courseId != 'course_eng_01') return updatedUzbekSpelling(text);
  return text.replaceAllMapped(_mixedLessonToken, (match) {
    final word = match[0]!;
    return _mixedLessonUzbekWords.contains(word.toLowerCase()) ||
            _oldUzbekVowel.hasMatch(word)
        ? updatedUzbekSpelling(word)
        : word;
  });
}
