/** Public messages only: never display raw provider errors or account internals. */
export function authErrorMessage(error: unknown, fallback = 'Hisob xizmatiga ulanib bo‘lmadi. Qayta urinib ko‘ring.'): string {
  const code = typeof error === 'object' && error !== null && 'code' in error ? error.code : undefined;
  switch (code) {
    case 'invalid_credentials': return 'Email yoki parol xato.';
    case 'email_not_confirmed': return 'Emailingiz hali tasdiqlanmagan. Pochtangiz va spam papkasini tekshiring yoki tasdiqlash xatini qayta so‘rang.';
    case 'over_email_send_rate_limit': return 'Tasdiqlash xatini yuborish limiti tugagan. Hozir xat yuborilmadi. Keyinroq urinib ko‘ring; muammo davom etsa, yordam xizmatiga murojaat qiling.';
    case 'over_request_rate_limit': return 'So‘rovlar juda ko‘p yuborildi. Biroz kutib, qayta urinib ko‘ring.';
    case 'email_address_not_authorized': return 'Pochta xizmati bu manzilga xat yubora olmayapti. Yordam xizmatiga murojaat qiling.';
    case 'email_address_invalid': return 'Email manzilini tekshirib, qayta kiriting.';
    case 'user_already_exists': return 'Bu email bilan hisob mavjud. Kirish yoki parolni tiklashni tanlang.';
    case 'weak_password': return 'Kuchliroq parol tanlang: harflar, raqamlar va belgilar qo‘shing.';
    case 'signup_disabled': return 'Yangi hisob ochish vaqtincha yopiq. Keyinroq urinib ko‘ring.';
    default: return fallback;
  }
}
