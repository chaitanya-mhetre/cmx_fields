/// cmx_fields — a comprehensive, animated, themeable smart-input-fields kit.
///
/// Phase 1 ships the shared field engine plus three flagship fields:
/// [CmxPhoneField], [CmxPasswordField] and [CmxOtpField]. Every field renders
/// into the same [CmxFieldScaffold], so they look, animate, theme and validate
/// identically.
library cmx_fields;

// ---------------------------------------------------------------------------
// Core engine
// ---------------------------------------------------------------------------
export 'src/core/cmx_animations.dart';
export 'src/core/cmx_field_mixin.dart';
export 'src/core/cmx_field_scaffold.dart';
export 'src/core/cmx_field_status.dart';
export 'src/core/cmx_field_theme.dart';
export 'src/core/cmx_fill_progress.dart';
export 'src/core/cmx_validators.dart';

// ---------------------------------------------------------------------------
// Fields — Phone
// ---------------------------------------------------------------------------
export 'src/fields/phone/cmx_phone_field.dart';
export 'src/fields/phone/country_data.dart';
export 'src/fields/phone/country_picker_config.dart';
export 'src/fields/phone/country_picker_sheet.dart';
export 'src/fields/phone/phone_formatter.dart';
export 'src/fields/phone/phone_fill_progress.dart';
export 'src/fields/phone/phone_validation.dart';
export 'src/fields/phone/phone_number_hint_service.dart';
export 'src/fields/phone/contacts_suggestions.dart';

// ---------------------------------------------------------------------------
// Fields — Password
// ---------------------------------------------------------------------------
export 'src/fields/password/cmx_password_field.dart';
export 'src/fields/password/strength_indicator.dart';

// ---------------------------------------------------------------------------
// Fields — OTP
// ---------------------------------------------------------------------------
export 'src/fields/otp/cmx_otp_field.dart';

// ---------------------------------------------------------------------------
// Fields — Card
// ---------------------------------------------------------------------------
export 'src/fields/card/cmx_card_field.dart';
export 'src/fields/card/card_type_detector.dart';

// ---------------------------------------------------------------------------
// Fields — Email / Number / Date / Search / TextArea / Tag
// ---------------------------------------------------------------------------
export 'src/fields/cmx_email_field.dart';
export 'src/fields/cmx_number_field.dart';
export 'src/fields/cmx_date_field.dart';
export 'src/fields/cmx_search_field.dart';
export 'src/fields/cmx_textarea_field.dart';
export 'src/fields/cmx_tag_field.dart';
