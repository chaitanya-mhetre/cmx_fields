/// Country metadata for the phone field: dial codes, ISO codes, emoji flags,
/// input masks and digit limits, plus a comprehensive built-in dataset and
/// lookup helpers.
library;

/// A single country/region usable by [CmxPhoneField].
///
/// Holds everything the phone field needs to render and format a number for a
/// given country: a human-readable [name], the ISO 3166-1 alpha-2 [isoCode],
/// the international [dialCode] (without the leading `+`), an emoji [flag], an
/// as-you-type [mask] and the [maxLength] (number of national digits).
class Country {
  /// Creates an immutable [Country] entry.
  const Country(
    this.name,
    this.isoCode,
    this.dialCode,
    this.flag,
    this.mask,
    this.maxLength,
  );

  /// The English display name of the country (e.g. `India`).
  final String name;

  /// The ISO 3166-1 alpha-2 code, upper-case (e.g. `IN`).
  final String isoCode;

  /// The international dial code without the leading `+` (e.g. `91`).
  final String dialCode;

  /// The emoji flag for the country (e.g. 🇮🇳).
  final String flag;

  /// The as-you-type mask. `#` is a digit placeholder; every other character
  /// (space, dash, parenthesis) is a literal separator, e.g. `'##### #####'`.
  final String mask;

  /// The maximum number of national significant digits accepted.
  final int maxLength;

  /// The number of `#` digit placeholders contained in [mask].
  int get maskDigitCount => mask.split('#').length - 1;

  @override
  bool operator ==(Object other) =>
      other is Country &&
      other.isoCode == isoCode &&
      other.dialCode == dialCode;

  @override
  int get hashCode => Object.hash(isoCode, dialCode);

  @override
  String toString() => 'Country($isoCode, +$dialCode, $name)';

  /// Returns the country whose [isoCode] matches [iso] (case-insensitive), or
  /// `null` if none is found.
  static Country? fromIso(String iso) {
    final needle = iso.toUpperCase();
    for (final c in kAllCountries) {
      if (c.isoCode == needle) return c;
    }
    return null;
  }

  /// Returns the first country whose [dialCode] matches [dial] (an optional
  /// leading `+` is ignored), or `null` if none is found.
  ///
  /// Because some dial codes are shared by several territories, the first
  /// match in [kAllCountries] (the canonical one) is returned.
  static Country? fromDial(String dial) {
    final needle = dial.startsWith('+') ? dial.substring(1) : dial;
    for (final c in kAllCountries) {
      if (c.dialCode == needle) return c;
    }
    return null;
  }

  /// The sensible default country used when nothing else can be resolved.
  static const Country fallback = Country(
    'United States',
    'US',
    '1',
    '🇺🇸',
    '(###) ###-####',
    10,
  );
}

/// ISO codes of the most commonly used countries, surfaced in a pinned
/// "Popular" section at the top of the country picker.
const List<String> kPopularCountryCodes = <String>[
  'IN',
  'US',
  'GB',
  'AE',
  'SG',
  'AU',
  'CA',
  'PK',
  'BD',
];

/// A comprehensive list of countries with correct dial codes, ISO codes and
/// emoji flags. Masks/lengths are reasonable defaults for formatting.
const List<Country> kAllCountries = <Country>[
  Country('Afghanistan', 'AF', '93', '🇦🇫', '### ### ###', 9),
  Country('Albania', 'AL', '355', '🇦🇱', '### ### ###', 9),
  Country('Algeria', 'DZ', '213', '🇩🇿', '### ## ## ##', 9),
  Country('Argentina', 'AR', '54', '🇦🇷', '## ####-####', 10),
  Country('Armenia', 'AM', '374', '🇦🇲', '## ######', 8),
  Country('Australia', 'AU', '61', '🇦🇺', '### ### ###', 9),
  Country('Austria', 'AT', '43', '🇦🇹', '### ######', 10),
  Country('Azerbaijan', 'AZ', '994', '🇦🇿', '## ### ## ##', 9),
  Country('Bahrain', 'BH', '973', '🇧🇭', '#### ####', 8),
  Country('Bangladesh', 'BD', '880', '🇧🇩', '#### ######', 10),
  Country('Belarus', 'BY', '375', '🇧🇾', '## ###-##-##', 9),
  Country('Belgium', 'BE', '32', '🇧🇪', '### ## ## ##', 9),
  Country('Bolivia', 'BO', '591', '🇧🇴', '# ### ####', 8),
  Country('Bosnia and Herzegovina', 'BA', '387', '🇧🇦', '## ###-###', 8),
  Country('Brazil', 'BR', '55', '🇧🇷', '(##) #####-####', 11),
  Country('Bulgaria', 'BG', '359', '🇧🇬', '### ### ###', 9),
  Country('Cambodia', 'KH', '855', '🇰🇭', '## ### ###', 9),
  Country('Cameroon', 'CM', '237', '🇨🇲', '#### ####', 9),
  Country('Canada', 'CA', '1', '🇨🇦', '(###) ###-####', 10),
  Country('Chile', 'CL', '56', '🇨🇱', '# #### ####', 9),
  Country('China', 'CN', '86', '🇨🇳', '### #### ####', 11),
  Country('Colombia', 'CO', '57', '🇨🇴', '### ### ####', 10),
  Country('Costa Rica', 'CR', '506', '🇨🇷', '#### ####', 8),
  Country('Croatia', 'HR', '385', '🇭🇷', '## ### ####', 9),
  Country('Cuba', 'CU', '53', '🇨🇺', '# ### ####', 8),
  Country('Cyprus', 'CY', '357', '🇨🇾', '## ######', 8),
  Country('Czechia', 'CZ', '420', '🇨🇿', '### ### ###', 9),
  Country('Denmark', 'DK', '45', '🇩🇰', '## ## ## ##', 8),
  Country('Dominican Republic', 'DO', '1', '🇩🇴', '(###) ###-####', 10),
  Country('Ecuador', 'EC', '593', '🇪🇨', '## ### ####', 9),
  Country('Egypt', 'EG', '20', '🇪🇬', '## #### ####', 10),
  Country('El Salvador', 'SV', '503', '🇸🇻', '#### ####', 8),
  Country('Estonia', 'EE', '372', '🇪🇪', '#### ####', 8),
  Country('Ethiopia', 'ET', '251', '🇪🇹', '## ### ####', 9),
  Country('Finland', 'FI', '358', '🇫🇮', '## ### ####', 9),
  Country('France', 'FR', '33', '🇫🇷', '# ## ## ## ##', 9),
  Country('Georgia', 'GE', '995', '🇬🇪', '### ## ## ##', 9),
  Country('Germany', 'DE', '49', '🇩🇪', '#### #######', 11),
  Country('Ghana', 'GH', '233', '🇬🇭', '## ### ####', 9),
  Country('Greece', 'GR', '30', '🇬🇷', '### ### ####', 10),
  Country('Guatemala', 'GT', '502', '🇬🇹', '#### ####', 8),
  Country('Honduras', 'HN', '504', '🇭🇳', '####-####', 8),
  Country('Hong Kong', 'HK', '852', '🇭🇰', '#### ####', 8),
  Country('Hungary', 'HU', '36', '🇭🇺', '## ### ####', 9),
  Country('Iceland', 'IS', '354', '🇮🇸', '### ####', 7),
  Country('India', 'IN', '91', '🇮🇳', '##### #####', 10),
  Country('Indonesia', 'ID', '62', '🇮🇩', '###-###-####', 11),
  Country('Iran', 'IR', '98', '🇮🇷', '### ### ####', 10),
  Country('Iraq', 'IQ', '964', '🇮🇶', '### ### ####', 10),
  Country('Ireland', 'IE', '353', '🇮🇪', '## ### ####', 9),
  Country('Israel', 'IL', '972', '🇮🇱', '##-###-####', 9),
  Country('Italy', 'IT', '39', '🇮🇹', '### ### ####', 10),
  Country('Ivory Coast', 'CI', '225', '🇨🇮', '## ## ## ## ##', 10),
  Country('Jamaica', 'JM', '1', '🇯🇲', '(###) ###-####', 10),
  Country('Japan', 'JP', '81', '🇯🇵', '## #### ####', 10),
  Country('Jordan', 'JO', '962', '🇯🇴', '# #### ####', 9),
  Country('Kazakhstan', 'KZ', '7', '🇰🇿', '### ###-##-##', 10),
  Country('Kenya', 'KE', '254', '🇰🇪', '### ######', 9),
  Country('Kuwait', 'KW', '965', '🇰🇼', '#### ####', 8),
  Country('Latvia', 'LV', '371', '🇱🇻', '## ### ###', 8),
  Country('Lebanon', 'LB', '961', '🇱🇧', '## ### ###', 8),
  Country('Libya', 'LY', '218', '🇱🇾', '##-#######', 9),
  Country('Lithuania', 'LT', '370', '🇱🇹', '### #####', 8),
  Country('Luxembourg', 'LU', '352', '🇱🇺', '### ### ###', 9),
  Country('Macau', 'MO', '853', '🇲🇴', '#### ####', 8),
  Country('Malaysia', 'MY', '60', '🇲🇾', '##-### ####', 9),
  Country('Maldives', 'MV', '960', '🇲🇻', '###-####', 7),
  Country('Malta', 'MT', '356', '🇲🇹', '#### ####', 8),
  Country('Mexico', 'MX', '52', '🇲🇽', '### ### ####', 10),
  Country('Moldova', 'MD', '373', '🇲🇩', '#### ####', 8),
  Country('Monaco', 'MC', '377', '🇲🇨', '## ## ## ##', 8),
  Country('Mongolia', 'MN', '976', '🇲🇳', '#### ####', 8),
  Country('Montenegro', 'ME', '382', '🇲🇪', '## ### ###', 8),
  Country('Morocco', 'MA', '212', '🇲🇦', '###-######', 9),
  Country('Myanmar', 'MM', '95', '🇲🇲', '## ### ####', 9),
  Country('Nepal', 'NP', '977', '🇳🇵', '###-#######', 10),
  Country('Netherlands', 'NL', '31', '🇳🇱', '# ########', 9),
  Country('New Zealand', 'NZ', '64', '🇳🇿', '## ### ####', 9),
  Country('Nicaragua', 'NI', '505', '🇳🇮', '#### ####', 8),
  Country('Nigeria', 'NG', '234', '🇳🇬', '### ### ####', 10),
  Country('North Macedonia', 'MK', '389', '🇲🇰', '## ### ###', 8),
  Country('Norway', 'NO', '47', '🇳🇴', '### ## ###', 8),
  Country('Oman', 'OM', '968', '🇴🇲', '#### ####', 8),
  Country('Pakistan', 'PK', '92', '🇵🇰', '### #######', 10),
  Country('Panama', 'PA', '507', '🇵🇦', '#### ####', 8),
  Country('Paraguay', 'PY', '595', '🇵🇾', '### ######', 9),
  Country('Peru', 'PE', '51', '🇵🇪', '### ### ###', 9),
  Country('Philippines', 'PH', '63', '🇵🇭', '### ### ####', 10),
  Country('Poland', 'PL', '48', '🇵🇱', '### ### ###', 9),
  Country('Portugal', 'PT', '351', '🇵🇹', '### ### ###', 9),
  Country('Qatar', 'QA', '974', '🇶🇦', '#### ####', 8),
  Country('Romania', 'RO', '40', '🇷🇴', '### ### ###', 9),
  Country('Russia', 'RU', '7', '🇷🇺', '### ###-##-##', 10),
  Country('Saudi Arabia', 'SA', '966', '🇸🇦', '## ### ####', 9),
  Country('Senegal', 'SN', '221', '🇸🇳', '## ### ## ##', 9),
  Country('Serbia', 'RS', '381', '🇷🇸', '## #######', 9),
  Country('Singapore', 'SG', '65', '🇸🇬', '#### ####', 8),
  Country('Slovakia', 'SK', '421', '🇸🇰', '### ### ###', 9),
  Country('Slovenia', 'SI', '386', '🇸🇮', '## ### ###', 8),
  Country('South Africa', 'ZA', '27', '🇿🇦', '## ### ####', 9),
  Country('South Korea', 'KR', '82', '🇰🇷', '##-####-####', 10),
  Country('Spain', 'ES', '34', '🇪🇸', '### ### ###', 9),
  Country('Sri Lanka', 'LK', '94', '🇱🇰', '## ### ####', 9),
  Country('Sweden', 'SE', '46', '🇸🇪', '##-### ## ##', 9),
  Country('Switzerland', 'CH', '41', '🇨🇭', '## ### ## ##', 9),
  Country('Syria', 'SY', '963', '🇸🇾', '## #### ###', 9),
  Country('Taiwan', 'TW', '886', '🇹🇼', '### ### ###', 9),
  Country('Tanzania', 'TZ', '255', '🇹🇿', '### ### ###', 9),
  Country('Thailand', 'TH', '66', '🇹🇭', '## ### ####', 9),
  Country('Tunisia', 'TN', '216', '🇹🇳', '## ### ###', 8),
  Country('Turkey', 'TR', '90', '🇹🇷', '### ### ## ##', 10),
  Country('Uganda', 'UG', '256', '🇺🇬', '### ######', 9),
  Country('Ukraine', 'UA', '380', '🇺🇦', '## ### ## ##', 9),
  Country('United Arab Emirates', 'AE', '971', '🇦🇪', '## ### ####', 9),
  Country('United Kingdom', 'GB', '44', '🇬🇧', '#### ######', 10),
  Country('United States', 'US', '1', '🇺🇸', '(###) ###-####', 10),
  Country('Uruguay', 'UY', '598', '🇺🇾', '#### ####', 8),
  Country('Uzbekistan', 'UZ', '998', '🇺🇿', '## ### ## ##', 9),
  Country('Venezuela', 'VE', '58', '🇻🇪', '###-#######', 10),
  Country('Vietnam', 'VN', '84', '🇻🇳', '### ### ####', 10),
  Country('Yemen', 'YE', '967', '🇾🇪', '### ### ###', 9),
  Country('Zambia', 'ZM', '260', '🇿🇲', '### ######', 9),
  Country('Zimbabwe', 'ZW', '263', '🇿🇼', '## ### ####', 9),
];
