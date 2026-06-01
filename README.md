# cmx_fields

A comprehensive, modern, **animated smart-input-fields kit** for Flutter. One package,
**ten field types** — all sharing a single field engine so they look, animate, theme and
validate identically.

**Fields:** 📱 Phone · 🔒 Password · 🔢 OTP · 💳 Card · 📧 Email · 🔣 Number ·
📅 Date · 🔍 Search · 📝 Text area · 🏷️ Tags.

## Showcase

Landscape previews from the example app (`example/`).

<p align="center">
  <img src="https://raw.githubusercontent.com/chaitanya-mhetre/cmx_fields/main/screenshots/ss_1.png" alt="cmx_fields — phone, country picker, password, OTP, card, email" width="100%">
</p>

<p align="center"><sub>Phone with country-aware validation &amp; fill-progress · searchable country picker · password strength · OTP · card · email</sub></p>

<p align="center">
  <img src="https://raw.githubusercontent.com/chaitanya-mhetre/cmx_fields/main/screenshots/ss_2.png" alt="cmx_fields — email, OTP, card, date, tags, autocomplete" width="100%">
</p>

<p align="center"><sub>Email &amp; OTP · card &amp; date picker · tag chips · email domain suggestions</sub></p>

## Why cmx_fields?

| | `intl_phone_field` | **cmx_fields** |
|---|:---:|:---:|
| Actively maintained | ❌ | ✅ |
| Multiple field types | ❌ phone only | ✅ 10 field types |
| Consistent API across fields | ❌ | ✅ |
| Global theming | ❌ | ✅ `CmxFieldThemeProvider` |
| Built-in animations (shake / pulse / checkmark) | ❌ | ✅ |
| Respects reduced-motion | ❌ | ✅ |
| Contact suggestions | ❌ | ✅ (graceful) |
| Device number hint (Android) | ❌ | ✅ Google Phone Number Hint |
| Fill-progress ring + valid tick | ❌ | ✅ |
| Password strength | n/a | ✅ |
| OTP autofill (`oneTimeCode`) | n/a | ✅ no native code |
| RTL-aware | partial | ✅ |

## Install

```yaml
dependencies:
  cmx_fields: ^0.0.1
```

```dart
import 'package:cmx_fields/cmx_fields.dart';
```

### Phone contact suggestions (Android / iOS)

If you use `showContactSuggestions: true` (default), add permissions to **your app**:

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
```

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSContactsUsageDescription</key>
<string>Used to suggest phone numbers from your contacts while typing.</string>
```

The package requests runtime permission before reading contacts. If the user denies,
suggestions are hidden and the app keeps running.

## Global theming

Wrap your app (or any subtree) once — every field below inherits the look. Per-field
props always override the inherited theme.

```dart
CmxFieldThemeProvider(
  theme: CmxFieldTheme(
    focusedColor: Colors.indigo,
    borderRadius: 16,
    borderStyle: CmxBorderStyle.outlined, // outlined | underline | filled | rounded | none
  ),
  child: MyForm(),
)
```

## Fields

### 📱 CmxPhoneField

```dart
CmxPhoneField(
  label: 'Mobile number',
  showContactSuggestions: true,
  onChanged: (phone) => print('${phone.fullNumber} ${phone.isValid}'),
  // Turnkey, country-aware validation — India needs 10 digits, others their own.
  validator: CmxPhoneField.validNumber(),
)
```

- **Country-aware validation:** `isValid` (and the ready-made `CmxPhoneField.validNumber()`
  validator) enforce each country's own rules via `phone_numbers_parser` — India requires
  10 digits, the US 10, and so on. `PhoneResult.expectedLength` exposes the target count.
- Tappable flag + dial-code prefix opens a searchable country picker (118 countries,
  popular ones pinned on top — **order and list are customizable**).
- As-you-type formatting per country.
- Auto-detects the country from the device locale.
- In-app contact suggestions once ≥3 digits are typed — **silently disabled** on
  web/desktop or when permission is denied (never crashes).
- **Device number hint (Android):** Google's Phone Number Hint picker auto-opens shortly
  after the field appears (and via the suffix button), letting the user fill a SIM/Google
  number in one tap. No phone-read permission needed; silently inert on iOS/web/desktop.
- **Green fill-progress ring:** the suffix ring fills 0 → 100% as the national number is
  typed, then settles to a full green ring with a drawn checkmark once the number validates.
- Emits a `PhoneResult { nationalNumber, dialCode, fullNumber, country, isValid, expectedLength }`.

> **Android setup:** the number hint uses Google Play Services — test on a real device
> (emulators without Play Services may not show it). No manifest permission is required.
> If Gradle fails with `phone_number_hint is currently compiled against android-31`,
> add this to your app’s `android/build.gradle.kts` (see `example/android/build.gradle.kts`):
>
> ```kotlin
> import com.android.build.gradle.LibraryExtension
> subprojects {
>     afterEvaluate {
>         extensions.findByType<LibraryExtension>()?.compileSdk = 36
>     }
> }
> ```

| Prop | Type | Default |
|---|---|---|
| `label`, `hint` | `String?` | — |
| `initialCountry` | `Country?` | locale / US |
| `initialValue` | `String?` | — |
| `showContactSuggestions` | `bool` | `true` |
| `autoDetectCountry` | `bool` | `true` |
| `enablePhoneNumberHint` | `bool` | `true` |
| `autoRequestHint` | `bool` | `true` |
| `hintRequestDelay` | `Duration` | `500ms` |
| `showHintButton` | `bool` | `true` |
| `showFillProgress` | `bool` | `true` |
| `countryPicker` | `CountryPickerConfig` | popular = [kPopularCountryCodes] |
| `onChanged`, `onSubmitted` | `ValueChanged<PhoneResult>?` | — |
| `validator` | `String? Function(PhoneResult?)` | — |
| `controller`, `focusNode`, `enabled` | — | — |
| theme overrides | `focusedColor`, `borderStyle`, `borderRadius`, … | inherited |

**Country picker customization:**

```dart
CmxPhoneField(
  countryPicker: CountryPickerConfig(
    // Shown first, in this exact order:
    popularCountryCodes: ['IN', 'US', 'AE', 'GB', 'SG'],
    popularSectionTitle: 'Frequent',
    // Optional: only these countries in the sheet:
    // allowedCountryCodes: ['IN', 'US', 'GB', 'AE'],
    // Optional: hide countries:
    // excludedCountryCodes: ['CU', 'KP'],
  ),
)
```

### 🔒 CmxPasswordField

```dart
final pwd = TextEditingController();

CmxPasswordField(
  label: 'Password',
  controller: pwd,
  showStrengthIndicator: true,
  showRules: true,
  minStrength: PasswordStrength.strong,
)

CmxPasswordField(
  label: 'Confirm password',
  validator: CmxValidators.match(() => pwd.text, 'Passwords do not match'),
)
```

- Animated show/hide eye toggle and a focus-bounce lock icon.
- Live 4-segment strength bar (`none → weak → medium → strong → veryStrong`).
- Optional rules checklist that ticks off as each rule is met.
- `minStrength` enforced during `Form` validation.

| Prop | Type | Default |
|---|---|---|
| `showStrengthIndicator` | `bool` | `true` |
| `showRules` | `bool` | `false` |
| `rules` | `List<PasswordRule>?` | `kDefaultPasswordRules` |
| `minStrength` | `PasswordStrength?` | — |
| `obscureInitially` | `bool` | `true` |
| `onChanged`, `onSubmitted` | `ValueChanged<String>?` | — |
| `validator` | `CmxValidator<String>?` | — |

### 🔢 CmxOtpField

```dart
final otp = CmxOtpController();

CmxOtpField(
  length: 6,
  controller: otp,
  autoReadSms: true, // OS oneTimeCode autofill — no native code
  onCompleted: (code) => verify(code),
  validator: (v) => (v == null || v.length < 6) ? 'Enter all 6 digits' : null,
)

// later:
otp.shake();  // wrong code feedback
otp.clear();  // reset boxes
```

- Auto-advance, backspace-to-previous, paste/OS-autofill distribution across boxes.
- Shake on error, success flash, four box styles (`outlined / underline / filled / rounded`).

| Prop | Type | Default |
|---|---|---|
| `length` | `int` | `6` |
| `controller` | `CmxOtpController?` | — |
| `autoReadSms` | `bool` | `true` |
| `fieldStyle` | `OtpFieldStyle` | `outlined` |
| `boxSize`, `spacing` | `double` | `52`, `8` |
| `obscureText` | `bool` | `false` |
| `onChanged`, `onCompleted` | `ValueChanged<String>?` | — |
| `validator` | `FormFieldValidator<String>?` | — |

### 💳 CmxCardField

```dart
CmxCardField(
  onChanged: (c) => print('${c.cardType} ${c.isValid}'),
  validator: (c) => (c == null || !c.isValid) ? 'Invalid card' : null,
)
```

Auto-detects brand (Visa, Mastercard, Amex, Discover, RuPay, Maestro) from the digits,
groups the number (`4242 4242 4242 4242`, Amex `3782 822463 10005`), Luhn-validates,
and pairs it with `MM/YY` expiry + brand-aware CVV fields. Emits a `CardResult`.

### 📧 CmxEmailField

```dart
CmxEmailField(
  label: 'Email',
  showSuggestions: true, // gmail.com, yahoo.com, … completions after @
  validator: CmxValidators.compose([CmxValidators.required(), CmxValidators.email()]),
)
```

Green fill-progress ring + tick suffix (same as phone), animated envelope prefix,
and a domain-completion overlay after `@`.

### 🔣 CmxNumberField

```dart
CmxNumberField(label: 'Quantity', min: 0, max: 99, showSteppers: true)

CmxNumberField(
  label: 'Amount',
  currencySymbol: '₹ ',
  decimalPlaces: 2,
  grouping: NumberGrouping.indian, // 12,34,567   (or .western → 1,234,567)
)
```

Grouping (`none`/`western`/`indian`), decimal precision, currency prefix, optional
`+`/`-` steppers, and min/max validation.

### 📅 CmxDateField

```dart
CmxDateField(
  label: 'Date of birth',
  dateFormat: 'dd/MM/yyyy', // also MMM d, yyyy · d MMMM yyyy · …
  pickerStyle: DatePickerStyle.adaptive, // material | cupertino | adaptive
  onChanged: (d) => print(d),
)
```

Tap opens a Material or Cupertino picker; read-only formatted display with an
animated calendar icon. No `intl` dependency.

### 🔍 CmxSearchField

```dart
CmxSearchField(
  label: 'Search',
  debounceDuration: Duration(milliseconds: 300),
  onSearch: (q) async => api.suggest(q), // overlay + loading spinner
  recentSearches: ['Mango', 'Cherry'],
  onSuggestionTap: (s) => run(s),
)
```

Debounced input, async-suggestion overlay with a loading indicator, recent-search list,
and an animated clear button. Stale async results are discarded.

### 📝 CmxTextAreaField

```dart
CmxTextAreaField(label: 'Description', maxLength: 200, minLines: 3, maxLines: 8)
```

Auto-expands smoothly between `minLines` and `maxLines`, with a live `47 / 200` counter
that turns red near the limit.

### 🏷️ CmxTagField

```dart
CmxTagField(
  label: 'Skills',
  initialTags: ['Flutter', 'Dart'],
  maxTags: 8,
  suggestions: ['Firebase', 'Riverpod', 'Bloc'],
  onTagsChanged: (tags) => print(tags),
)
```

Type + Enter/comma to add chips, ✕ or backspace to remove, with add/remove animations,
duplicate/`maxTags` guards, and a suggestions overlay.

## Validators

Shared (`CmxValidators`): `required`, `email`, `minLength`, `maxLength`, `pattern`,
`match`, `compose`.

Built-in per field (clear default messages):

| Field | Helper | Example error |
|---|---|---|
| Phone | `CmxPhoneField.validNumber()` | `Enter 10 digits for India (+91) (3 more)` |
| Email | `CmxValidators.email()` | `Enter a valid email` |
| Password | `minStrength` + `CmxValidators.required()` | `Password is too weak (minimum: Strong)` |
| OTP | `CmxOtpField.complete(6)` | `Enter all 6 digits` |
| Card | `CmxCardField.validCard()` | `Enter valid card details` |
| Number | `CmxNumberField.inRange(min: 0, max: 99)` | `Must be at most 99` |
| Date | `CmxDateField.required()` | `Select a date` |
| Tags | `CmxTagField.minTags(2)` | `Add at least 2 tags` |

```dart
CmxPhoneField(validator: CmxPhoneField.validNumber());
CmxEmailField(
  validator: CmxValidators.compose([
    CmxValidators.required('Enter your email'),
    CmxValidators.email(),
  ]),
);
```

## Form integration

Every field works standalone or inside a `Form`:

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: Column(children: [
    CmxPhoneField(validator: CmxPhoneField.validNumber()),
    CmxPasswordField(
      minStrength: PasswordStrength.strong,
      validator: CmxValidators.required('Enter a password'),
    ),
  ]),
);

if (formKey.currentState!.validate()) submit();
```

Failed validation shows the error text, flips the border to the error color, and shakes
the field (unless reduced-motion is enabled).

## Platform support

Android · iOS · Web · macOS · Windows · Linux. Mobile-only features (contacts, OS OTP
autofill) degrade silently on platforms or permission states that don't support them.

## License

MIT
