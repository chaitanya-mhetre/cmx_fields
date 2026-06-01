# Changelog

## 0.0.1

Initial release — a shared field engine plus **ten** smart input fields.

### Core engine
- `CmxFieldTheme` + `CmxFieldThemeProvider` for global, inheritable theming.
- `CmxBorderStyle`: `outlined`, `underline`, `filled`, `rounded`, `none`.
- `CmxFieldScaffold`: the shared, animated visual shell every field renders into.
- `CmxFieldStateMixin`: focus/shake/status/theme plumbing for field authors.
- `CmxAnimations` (shake, pulse, slide-in error) + `CmxCheckmark`, all honoring
  `MediaQuery.disableAnimations`.
- `CmxValidators`: `required`, `email`, `minLength`, `maxLength`, `pattern`, `match`,
  `compose`.

### Fields
- **`CmxPhoneField`** — country picker (118 countries, popular pinned), per-country
  as-you-type formatting, validation via `phone_numbers_parser`, locale auto-detect,
  animated flag, graceful in-app contact suggestions, Android device number hint
  (`phone_number_hint`, auto + manual, no permission needed), and a green fill-progress
  ring that completes into a validated checkmark.
- **`CmxPasswordField`** — animated show/hide toggle, live strength indicator,
  rules checklist, `minStrength` validation, focus-bounce lock icon.
- **`CmxOtpField`** + `CmxOtpController` — auto-advance, backspace-to-previous,
  paste/OS-autofill distribution (`AutofillHints.oneTimeCode`), shake on error,
  success flash, four box styles.
- **`CmxCardField`** — brand detection (Visa/Mastercard/Amex/Discover/RuPay/Maestro),
  grouped formatting, Luhn validation, `MM/YY` expiry + brand-aware CVV; emits `CardResult`.
- **`CmxEmailField`** — real-time validity checkmark, animated envelope, domain-completion
  suggestions overlay.
- **`CmxNumberField`** — `none`/`western`/`indian` grouping, decimal precision,
  currency prefix, optional steppers, min/max validation.
- **`CmxDateField`** — Material/Cupertino/adaptive picker, custom format strings
  (no `intl` dependency), animated calendar icon.
- **`CmxSearchField`** — debounced input, async-suggestion overlay with loading state,
  recent searches, animated clear, stale-result discarding.
- **`CmxTextAreaField`** — smooth auto-expand, live character counter with near-limit
  warning, max-length enforcement.
- **`CmxTagField`** — chip input with Enter/separator add, ✕/backspace remove,
  add/remove animations, duplicate & `maxTags` guards, suggestions overlay.

### Shared
- Every field works standalone and inside a `Form` with `GlobalKey<FormState>`.
- RTL-aware, dartdoc on all public API, zero `flutter analyze` issues.
