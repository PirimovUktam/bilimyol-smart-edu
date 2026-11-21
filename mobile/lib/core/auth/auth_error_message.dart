import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_strings.dart';

String authErrorMessage(Object error, {AppStrings strings = AppStrings.uz}) {
  final code = error is AuthException ? error.code : null;
  final ru = strings.isRu;
  return switch (code) {
    'invalid_credentials' =>
      ru ? 'Неверный email или пароль.' : 'Email yoki parol xato.',
    'email_not_confirmed' =>
      ru
          ? 'Ваш email ещё не подтверждён. Проверьте почту и папку «Спам».'
          : 'Emailingiz hali tasdiqlanmagan. Pochtangiz va spam papkasini tekshiring.',
    'over_email_send_rate_limit' =>
      ru
          ? 'Превышен лимит отправки писем. Письмо сейчас не отправлено. Попробуйте позже или обратитесь в поддержку.'
          : 'Xat yuborish limiti tugagan. Hozir xat yuborilmadi. Keyinroq urinib ko‘ring; muammo davom etsa, yordam xizmatiga murojaat qiling.',
    'over_request_rate_limit' =>
      ru
          ? 'Слишком много запросов. Подождите немного и попробуйте снова.'
          : 'So‘rovlar juda ko‘p yuborildi. Biroz kutib, qayta urinib ko‘ring.',
    'email_address_not_authorized' =>
      ru
          ? 'Почтовый сервис не может отправить письмо на этот адрес. Обратитесь в поддержку.'
          : 'Pochta xizmati bu manzilga xat yubora olmayapti. Yordam xizmatiga murojaat qiling.',
    'email_address_invalid' =>
      ru
          ? 'Проверьте адрес электронной почты и введите снова.'
          : 'Email manzilini tekshirib, qayta kiriting.',
    'user_already_exists' =>
      ru
          ? 'Аккаунт с таким email уже существует. Войдите или восстановите пароль.'
          : 'Bu email bilan hisob mavjud. Kirish yoki parolni tiklashni tanlang.',
    'weak_password' =>
      ru
          ? 'Выберите более надёжный пароль: добавьте буквы, цифры и символы.'
          : 'Kuchliroq parol tanlang: harflar, raqamlar va belgilar qo‘shing.',
    _ => strings.authServiceUnavailable,
  };
}
