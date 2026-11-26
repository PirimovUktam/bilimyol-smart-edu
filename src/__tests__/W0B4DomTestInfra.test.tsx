// @vitest-environment jsdom
import '@testing-library/jest-dom/vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Button } from '../presentation/components/Button';
import { PasswordInput } from '../presentation/components/PasswordInput';

describe('W0-B4 Web DOM test infrastructure (jsdom + RTL + jest-dom)', () => {
  it('renders PasswordInput into a real DOM and toggles password visibility on click', () => {
    render(
      <PasswordInput
        id="w0b4-password"
        placeholder="Parolni kiriting"
        value="secret123"
        onChange={() => {}}
      />,
    );

    const input = screen.getByPlaceholderText('Parolni kiriting');
    expect(input).toBeInTheDocument();
    expect(input).toHaveAttribute('type', 'password');

    const toggleButton = screen.getByRole('button');
    fireEvent.click(toggleButton);
    expect(input).toHaveAttribute('type', 'text');

    fireEvent.click(toggleButton);
    expect(input).toHaveAttribute('type', 'password');
  });

  it('renders Button loading and interactive click states in jsdom', () => {
    const onSave = vi.fn();
    const { rerender } = render(
      <Button onClick={onSave}>Saqlash</Button>,
    );

    const button = screen.getByRole('button', { name: 'Saqlash' });
    expect(button).toBeInTheDocument();
    expect(button).not.toBeDisabled();

    fireEvent.click(button);
    expect(onSave).toHaveBeenCalledTimes(1);

    rerender(
      <Button isLoading onClick={onSave}>
        Saqlash
      </Button>,
    );
    expect(button).toBeDisabled();
    expect(button).toHaveAttribute('aria-busy', 'true');
  });
});
