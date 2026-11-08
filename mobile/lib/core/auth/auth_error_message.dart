import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error) {
  final code = error is AuthException ? error.code : null;
  return switch (code) {
    'invalid_credentials' => 'Email yoki parol xato.',
    'email_not_confirmed' => 'Emailingiz hali tasdiqlanmagan. Pochtangiz va spam papkasini tekshiring.',
    'over_email_send_rate_limit' => 'Xat yuborish limiti tugagan. Hozir xat yuborilmadi. Keyinroq urinib ko‘ring; muammo davom etsa, yordam xizmatiga murojaat qiling.',
    'over_request_rate_limit' => 'So‘rovlar juda ko‘p yuborildi. Biroz kutib, qayta urinib ko‘ring.',
    'email_address_not_authorized' => 'Pochta xizmati bu manzilga xat yubora olmayapti. Yordam xizmatiga murojaat qiling.',
    'email_address_invalid' => 'Email manzilini tekshirib, qayta kiriting.',
    'user_already_exists' => 'Bu email bilan hisob mavjud. Kirish yoki parolni tiklashni tanlang.',
    'weak_password' => 'Kuchliroq parol tanlang: harflar, raqamlar va belgilar qo‘shing.',
    _ => 'Hisob xizmatiga ulanib bo‘lmadi. Qayta urinib ko‘ring.',
  };
}
