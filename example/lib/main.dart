import 'package:cmx_fields/cmx_fields.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CmxFieldsDemoApp());

const _seed = Color(0xFF5C6BC0); // indigo

/// Root of the cmx_fields showcase.
class CmxFieldsDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const CmxFieldsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cmx_fields demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      // Global field theme: every field below inherits this indigo look.
      home: const CmxFieldThemeProvider(
        theme: CmxFieldTheme(
          focusedColor: _seed,
          borderRadius: 14,
          borderStyle: CmxBorderStyle.outlined,
        ),
        child: GalleryShell(),
      ),
    );
  }
}

/// A scrollable tab gallery of all ten fields.
class GalleryShell extends StatelessWidget {
  /// Creates the gallery shell.
  const GalleryShell({super.key});

  static const _tabs = <(String, Widget)>[
    ('Phone', PhoneDemo()),
    ('Password', PasswordDemo()),
    ('OTP', OtpDemo()),
    ('Card', CardDemo()),
    ('Email', EmailDemo()),
    ('Number', NumberDemo()),
    ('Date', DateDemo()),
    ('Search', SearchDemo()),
    ('Text area', TextAreaDemo()),
    ('Tags', TagDemo()),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('cmx_fields'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final t in _tabs) Tab(text: t.$1)],
          ),
        ),
        body: SafeArea(
          child: TabBarView(children: [for (final t in _tabs) t.$2]),
        ),
      ),
    );
  }
}

/// Shared page chrome: a titled, padded, scrollable form body.
class DemoPage extends StatelessWidget {
  /// Creates a demo page.
  const DemoPage({super.key, required this.title, required this.children});

  /// Heading shown at the top.
  final String title;

  /// Body widgets.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}

/// A reusable "Validate" button bound to a form key.
class ValidateButton extends StatelessWidget {
  /// Creates a validate button.
  const ValidateButton({
    super.key,
    required this.formKey,
    this.label = 'Validate',
  });

  /// The form to validate on press.
  final GlobalKey<FormState> formKey;

  /// Button label.
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () => formKey.currentState?.validate(),
      child: Text(label),
    );
  }
}

/// Phone field demo.
class PhoneDemo extends StatefulWidget {
  /// Creates the phone demo.
  const PhoneDemo({super.key});

  @override
  State<PhoneDemo> createState() => _PhoneDemoState();
}

class _PhoneDemoState extends State<PhoneDemo> {
  final _formKey = GlobalKey<FormState>();
  PhoneResult? _result;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: DemoPage(
        title: 'Phone',
        children: [
          CmxPhoneField(
            label: 'Mobile number',
            hint: 'Enter your number',
            showContactSuggestions: true,
            countryPicker: const CountryPickerConfig(
              popularCountryCodes: ['IN', 'US', 'AE', 'GB', 'SG', 'AU'],
              popularSectionTitle: 'Frequent',
            ),
            onChanged: (r) => setState(() => _result = r),
            validator: CmxPhoneField.validNumber(),
          ),
          const SizedBox(height: 8),
          Text(
            'Validation is per country (India 10 digits, others accordingly). '
            'On Android the device number-hint picker opens automatically; the '
            'green ring fills as you type and ticks when valid.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          ValidateButton(formKey: _formKey),
          const SizedBox(height: 16),
          if (_result != null)
            Text('Full number: ${_result!.fullNumber}\n'
                'Country: ${_result!.country.name}\n'
                'Valid: ${_result!.isValid}'),
        ],
      ),
    );
  }
}

/// Password field demo.
class PasswordDemo extends StatefulWidget {
  /// Creates the password demo.
  const PasswordDemo({super.key});

  @override
  State<PasswordDemo> createState() => _PasswordDemoState();
}

class _PasswordDemoState extends State<PasswordDemo> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: DemoPage(
        title: 'Password',
        children: [
          CmxPasswordField(
            label: 'Password',
            controller: _passwordController,
            showStrengthIndicator: true,
            showRules: true,
            minStrength: PasswordStrength.strong,
            validator: CmxValidators.required('Enter a password'),
          ),
          const SizedBox(height: 20),
          CmxPasswordField(
            label: 'Confirm password',
            showStrengthIndicator: false,
            validator: CmxValidators.match(
              () => _passwordController.text,
              'Passwords do not match',
            ),
          ),
          const SizedBox(height: 20),
          ValidateButton(formKey: _formKey),
        ],
      ),
    );
  }
}

/// OTP field demo.
class OtpDemo extends StatefulWidget {
  /// Creates the OTP demo.
  const OtpDemo({super.key});

  @override
  State<OtpDemo> createState() => _OtpDemoState();
}

class _OtpDemoState extends State<OtpDemo> {
  final _formKey = GlobalKey<FormState>();
  final _otp = CmxOtpController();
  String _entered = '';

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: DemoPage(
        title: 'OTP',
        children: [
          Center(
            child: CmxOtpField(
              length: 6,
              controller: _otp,
              autoReadSms: true,
              onChanged: (v) => setState(() => _entered = v),
              onCompleted: (v) => setState(() => _entered = v),
              validator: CmxOtpField.complete(6),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            children: [
              ValidateButton(formKey: _formKey, label: 'Verify'),
              OutlinedButton(onPressed: _otp.shake, child: const Text('Shake')),
              OutlinedButton(onPressed: _otp.clear, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Entered: $_entered'),
        ],
      ),
    );
  }
}

/// Card field demo.
class CardDemo extends StatefulWidget {
  /// Creates the card demo.
  const CardDemo({super.key});

  @override
  State<CardDemo> createState() => _CardDemoState();
}

class _CardDemoState extends State<CardDemo> {
  final _formKey = GlobalKey<FormState>();
  CardResult? _result;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: DemoPage(
        title: 'Card',
        children: [
          CmxCardField(
            onChanged: (r) => setState(() => _result = r),
            validator: CmxCardField.validCard(),
          ),
          const SizedBox(height: 20),
          ValidateButton(formKey: _formKey),
          const SizedBox(height: 16),
          if (_result != null)
            Text('Brand: ${CardTypeDetector.displayName(_result!.cardType)}\n'
                'Valid: ${_result!.isValid}'),
        ],
      ),
    );
  }
}

/// Email field demo.
class EmailDemo extends StatelessWidget {
  /// Creates the email demo.
  const EmailDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return Form(
      key: formKey,
      child: DemoPage(
        title: 'Email',
        children: [
          CmxEmailField(
            label: 'Email address',
            validator: CmxValidators.compose([
              CmxValidators.required(),
              CmxValidators.email(),
            ]),
          ),
          const SizedBox(height: 20),
          ValidateButton(formKey: formKey),
        ],
      ),
    );
  }
}

/// Number field demo.
class NumberDemo extends StatelessWidget {
  /// Creates the number demo.
  const NumberDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return Form(
      key: formKey,
      child: DemoPage(
        title: 'Number',
        children: [
          CmxNumberField(
            label: 'Quantity',
            min: 0,
            max: 99,
            showSteppers: true,
            validator: CmxNumberField.inRange(min: 0, max: 99),
          ),
          const SizedBox(height: 20),
          CmxNumberField(
            label: 'Amount',
            currencySymbol: '₹ ',
            decimalPlaces: 2,
            grouping: NumberGrouping.indian,
          ),
          const SizedBox(height: 20),
          ValidateButton(formKey: formKey),
        ],
      ),
    );
  }
}

/// Date field demo.
class DateDemo extends StatelessWidget {
  /// Creates the date demo.
  const DateDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return Form(
      key: formKey,
      child: DemoPage(
        title: 'Date',
        children: [
          CmxDateField(
            label: 'Date of birth',
            dateFormat: 'dd/MM/yyyy',
            validator: CmxDateField.required('Select your date of birth'),
          ),
          const SizedBox(height: 20),
          CmxDateField(label: 'Appointment', dateFormat: 'MMM d, yyyy'),
          const SizedBox(height: 20),
          ValidateButton(formKey: formKey),
        ],
      ),
    );
  }
}

/// Search field demo.
class SearchDemo extends StatelessWidget {
  /// Creates the search demo.
  const SearchDemo({super.key});

  static const _fruits = [
    'Apple',
    'Apricot',
    'Banana',
    'Blueberry',
    'Cherry',
    'Mango',
    'Orange',
    'Peach',
    'Pear',
    'Pineapple',
  ];

  Future<List<String>> _search(String q) async {
    final lower = q.toLowerCase();
    return _fruits.where((f) => f.toLowerCase().contains(lower)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Search',
      children: [
        CmxSearchField(
          label: 'Search fruit',
          onSearch: _search,
          recentSearches: const ['Mango', 'Cherry'],
        ),
      ],
    );
  }
}

/// Text area field demo.
class TextAreaDemo extends StatelessWidget {
  /// Creates the text area demo.
  const TextAreaDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoPage(
      title: 'Text area',
      children: [
        CmxTextAreaField(
          label: 'Description',
          maxLength: 200,
          minLines: 3,
          maxLines: 8,
        ),
      ],
    );
  }
}

/// Tag field demo.
class TagDemo extends StatelessWidget {
  /// Creates the tag demo.
  const TagDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    return Form(
      key: formKey,
      child: DemoPage(
        title: 'Tags',
        children: [
          CmxTagField(
            label: 'Skills',
            initialTags: const ['Flutter', 'Dart'],
            maxTags: 8,
            suggestions: const ['Firebase', 'GraphQL', 'Riverpod', 'Bloc'],
            validator: CmxTagField.minTags(2, 'Add at least 2 skills'),
          ),
          const SizedBox(height: 20),
          ValidateButton(formKey: formKey),
        ],
      ),
    );
  }
}
