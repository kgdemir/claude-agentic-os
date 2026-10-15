# Accessibility

Applies to projects with a web or desktop UI. Target: WCAG 2.2 level AA. Lint rules
(`eslint-plugin-jsx-a11y`): `~/.claude/guides/tools/eslint.md`.

- **Native elements first.** A clickable thing is a `<button>` or `<a href>`, a field is an `<input>` with a `<label>`; ARIA only where no native element fits.
  *Why: a `<div onClick>` has no keyboard support, no role and no focus, and ARIA added to fake them is usually incomplete.*
- **Every control has an accessible name:** a visible label, `aria-label` for icon-only buttons, `alt` on informative images (`alt=""` on decorative ones). Desktop: `AutomationProperties.Name` (WPF), `AccessibleName` (WinForms).
  *Why: a screen reader announces an unnamed control as just "button".*
- **Everything works from the keyboard,** in a logical order, with a visible focus indicator that is never hidden behind sticky headers or overlays (WCAG 2.4.7, 2.4.11).
  *Why: keyboard users and screen-reader users cannot use what a mouse alone can reach.*
- **Focus is managed:** a dialog moves focus into itself, traps it, and returns it to the trigger on close; a route change moves focus to the new page's heading.
  *Why: otherwise focus stays behind on the hidden page, and keyboard users are lost.*
- **Contrast at least 4.5:1 for text, 3:1 for large text and UI component edges;** never colour alone to convey state.
  *Why: low contrast and colour-only errors are unreadable for low-vision and colour-blind users and in sunlight.*
- **Errors and live updates are announced:** field errors linked with `aria-describedby`, status messages in an `aria-live` region.
  *Why: a red message that appears silently is invisible to a screen reader.*
- **Pointer targets are at least 24×24 CSS px** (WCAG 2.5.8), `<html lang>` is set, and animation respects `prefers-reduced-motion`.
  *Why: small targets fail for tremor and touch; a missing `lang` makes the screen reader mispronounce every word.*
- **Automated checks run in tests** (`@axe-core/playwright` on main pages and states), plus a manual keyboard pass for new screens.
  *Why: automated tools catch only part of WCAG failures; keyboard and focus problems need a person.*
