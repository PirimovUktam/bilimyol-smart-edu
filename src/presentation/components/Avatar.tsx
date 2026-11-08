interface AvatarProps {
  name: string;
  className?: string;
}

export function Avatar({ name, className = '' }: AvatarProps) {
  const initials = name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toLocaleUpperCase('uz')).join('');
  return (
    <span aria-hidden="true" className={'grid size-9 shrink-0 place-items-center rounded-xl bg-brand/12 text-xs font-extrabold text-brand-dark ' + className}>
      {initials || 'O'}
    </span>
  );
}
