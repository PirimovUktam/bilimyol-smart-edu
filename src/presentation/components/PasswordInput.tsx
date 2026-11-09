import { useTranslation } from '@/core/locales/useTranslation';
import { useState, type InputHTMLAttributes } from 'react';
import { Eye, EyeOff, Lock } from 'lucide-react';
import { IconButton } from './IconButton';

export function PasswordInput({ className = '', ...props }: InputHTMLAttributes<HTMLInputElement>) {
  const { t } = useTranslation();
  const [visible, setVisible] = useState(false);
  const Icon = visible ? EyeOff : Eye;
  return (
    <div className="relative">
      <Lock aria-hidden="true" className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-slatefine" />
      <input {...props} type={visible ? 'text' : 'password'} className={'form-input pl-10 pr-12 ' + className} />
      <IconButton
        label={t(visible ? 'auth.hidePassword' : 'auth.showPassword')}
        onClick={() => setVisible(!visible)}
        className="absolute inset-y-0 right-0"
      >
        <Icon aria-hidden="true" className="size-4" />
      </IconButton>
    </div>
  );
}
