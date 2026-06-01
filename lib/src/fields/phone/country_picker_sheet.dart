/// A searchable modal bottom sheet for picking a [Country].
library;

import 'package:flutter/material.dart';

import 'country_data.dart';
import 'country_picker_config.dart';

/// Shows a modal bottom sheet that lets the user pick a [Country].
///
/// The sheet contains a live search field (matching on name, dial code or ISO
/// code), an optional pinned section ([CountryPickerConfig.popularCountryCodes]
/// order preserved), a divider, and the full alphabetical list.
Future<Country?> showCountryPickerSheet(
  BuildContext context, {
  Country? selected,
  CountryPickerConfig config = CountryPickerConfig.defaults,
}) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CountryPickerSheet(
      selected: selected,
      config: config,
    ),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    this.selected,
    required this.config,
  });

  final Country? selected;
  final CountryPickerConfig config;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  late final List<Country> _popular = widget.config.resolvePopular();
  late final List<Country> _sorted = widget.config.resolveAll();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Country c, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    final dial = lower.startsWith('+') ? lower.substring(1) : lower;
    return c.name.toLowerCase().contains(lower) ||
        c.isoCode.toLowerCase().contains(lower) ||
        c.dialCode.contains(dial);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final filtered =
        _sorted.where((c) => _matches(c, _query)).toList(growable: false);
    final popularFiltered = _query.isEmpty
        ? _popular
        : _popular.where((c) => _matches(c, _query)).toList(growable: false);
    final showPopular = _query.isEmpty && popularFiltered.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Expanded(
              child: _buildList(
                context,
                filtered: filtered,
                popularFiltered: popularFiltered,
                showPopular: showPopular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context, {
    required List<Country> filtered,
    required List<Country> popularFiltered,
    required bool showPopular,
  }) {
    if (filtered.isEmpty && popularFiltered.isEmpty) {
      return const Center(child: Text('No countries found'));
    }

    if (!showPopular) {
      final searchHits = _query.isEmpty
          ? filtered
          : [...popularFiltered, ...filtered];
      return ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: searchHits.length,
        itemBuilder: (context, index) => _row(context, searchHits[index]),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
          child: Text(
            widget.config.popularSectionTitle,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        for (final country in popularFiltered) _row(context, country),
        const Divider(height: 1),
        for (final country in filtered) _row(context, country),
      ],
    );
  }

  Widget _row(BuildContext context, Country country) {
    final theme = Theme.of(context);
    final isSelected = widget.selected != null &&
        widget.selected!.isoCode == country.isoCode &&
        widget.selected!.dialCode == country.dialCode;
    return ListTile(
      leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
      title: Text(country.name),
      trailing: Text(
        '+${country.dialCode}',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      onTap: () => Navigator.of(context).pop(country),
    );
  }
}
