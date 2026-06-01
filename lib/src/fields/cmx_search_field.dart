/// A debounced, suggestion-aware search input for `cmx_fields`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/cmx_animations.dart';
import '../core/cmx_field_mixin.dart';
import '../core/cmx_field_scaffold.dart';
import '../core/cmx_field_status.dart';
import '../core/cmx_field_theme.dart';

/// A polished search field with debounced change notifications, asynchronous
/// suggestions and a recent-searches dropdown.
///
/// Behavior:
/// * [onChanged] fires synchronously on every keystroke.
/// * [onDebouncedChanged] fires once the user stops typing for
///   [debounceDuration].
/// * When [onSearch] is provided it is awaited after the debounce; while it is
///   pending the field shows the scaffold's loading spinner, and once it
///   resolves up to [maxSuggestions] results are shown in an overlay anchored
///   to the field. Stale (out-of-order) results are discarded.
/// * When the field is focused, empty and [recentSearches] is non-empty, the
///   recent searches are shown in the overlay under a "Recent" header.
/// * Tapping a suggestion or recent entry fills the field, invokes
///   [onSuggestionTap] and closes the overlay.
/// * The clear (✕) button animates in while there is text; tapping it clears
///   the field, closes the overlay and refocuses.
///
/// The field works standalone and inside a [Form] (it owns no [FormField]; it
/// is a plain input). It is RTL-safe and honors reduced-motion.
class CmxSearchField extends StatefulWidget {
  /// Creates a search field.
  const CmxSearchField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.onChanged,
    this.onDebouncedChanged,
    this.onSearch,
    this.onSuggestionTap,
    this.recentSearches = const <String>[],
    this.showClearButton = true,
    this.maxSuggestions = 6,
    this.focusedColor,
    this.errorColor,
    this.successColor,
    this.borderColor,
    this.backgroundColor,
    this.fillColor,
    this.borderRadius,
    this.borderWidth,
    this.borderStyle,
    this.contentPadding,
    this.labelStyle,
    this.hintStyle,
    this.inputStyle,
  });

  /// Floating label text.
  final String? label;

  /// Placeholder shown when empty and focused.
  final String? hint;

  /// Optional external controller for the editable text.
  final TextEditingController? controller;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Whether the field is interactive.
  final bool enabled;

  /// How long to wait after the last keystroke before firing
  /// [onDebouncedChanged] and [onSearch].
  final Duration debounceDuration;

  /// Called synchronously on every keystroke with the current text.
  final ValueChanged<String>? onChanged;

  /// Called once typing settles for [debounceDuration].
  final ValueChanged<String>? onDebouncedChanged;

  /// Asynchronously resolves suggestions for the given query.
  ///
  /// Invoked after the debounce when non-null. Out-of-order results are
  /// ignored: only the response for the most recent query is shown.
  final Future<List<String>> Function(String query)? onSearch;

  /// Called when a suggestion or recent entry is tapped, with its text.
  final void Function(String suggestion)? onSuggestionTap;

  /// Recent searches shown in the overlay when the field is focused and empty.
  final List<String> recentSearches;

  /// Whether to show the animated clear (✕) button while there is text.
  final bool showClearButton;

  /// The maximum number of suggestions (or recent searches) to display.
  final int maxSuggestions;

  /// Override: accent color while focused.
  final Color? focusedColor;

  /// Override: error color.
  final Color? errorColor;

  /// Override: success color.
  final Color? successColor;

  /// Override: resting border color.
  final Color? borderColor;

  /// Override: field background color.
  final Color? backgroundColor;

  /// Override: fill color for the filled border style.
  final Color? fillColor;

  /// Override: corner radius.
  final double? borderRadius;

  /// Override: border stroke width.
  final double? borderWidth;

  /// Override: border/decoration style.
  final CmxBorderStyle? borderStyle;

  /// Override: inner content padding.
  final EdgeInsets? contentPadding;

  /// Override: floating label text style.
  final TextStyle? labelStyle;

  /// Override: hint text style.
  final TextStyle? hintStyle;

  /// Override: entered-text style.
  final TextStyle? inputStyle;

  @override
  State<CmxSearchField> createState() => _CmxSearchFieldState();
}

class _CmxSearchFieldState extends State<CmxSearchField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxSearchField> {
  late TextEditingController _controller;
  bool _ownsController = false;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  Timer? _debounce;

  /// Suggestions currently shown in the overlay.
  List<String> _suggestions = const <String>[];

  /// Whether the overlay is showing recent searches (vs. async suggestions).
  bool _showingRecent = false;

  /// Monotonic id of the latest query, used to discard stale async results.
  int _queryId = 0;

  @override
  void initState() {
    super.initState();
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);
    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;
    focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(CmxSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    focusNode.removeListener(_handleFocusChanged);
    if (_ownsController) _controller.dispose();
    disposeCmxField();
    super.dispose();
  }

  // --- Text / debounce --------------------------------------------------------

  void _onChanged(String value) {
    setState(() {}); // Reflect clear-button visibility / label float.
    widget.onChanged?.call(value);
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () => _onDebounced(value));

    // Showing recent only makes sense while empty; remove it once typing.
    if (value.isEmpty) {
      _maybeShowRecent();
    } else if (_showingRecent) {
      _removeOverlay();
    }
  }

  Future<void> _onDebounced(String value) async {
    if (!mounted) return;
    widget.onDebouncedChanged?.call(value);

    final search = widget.onSearch;
    if (search == null) return;
    if (value.isEmpty) {
      _maybeShowRecent();
      return;
    }

    final id = ++_queryId;
    setStatus(CmxFieldStatus.loading);

    List<String> results;
    try {
      results = await search(value);
    } catch (_) {
      results = const <String>[];
    }

    // Ignore stale or post-dispose responses.
    if (!mounted || id != _queryId) return;

    resetStatus();

    if (!isFocused) {
      _removeOverlay();
      return;
    }

    final limited = results.length > widget.maxSuggestions
        ? results.sublist(0, widget.maxSuggestions)
        : results;
    if (limited.isEmpty) {
      _removeOverlay();
      return;
    }
    setState(() {
      _suggestions = limited;
      _showingRecent = false;
    });
    _showOverlay();
  }

  // --- Recent searches --------------------------------------------------------

  void _maybeShowRecent() {
    if (!isFocused ||
        _controller.text.isNotEmpty ||
        widget.recentSearches.isEmpty) {
      _removeOverlay();
      return;
    }
    final limited = widget.recentSearches.length > widget.maxSuggestions
        ? widget.recentSearches.sublist(0, widget.maxSuggestions)
        : widget.recentSearches;
    setState(() {
      _suggestions = limited;
      _showingRecent = true;
    });
    _showOverlay();
  }

  // --- Focus / overlay --------------------------------------------------------

  void _handleFocusChanged() {
    if (!mounted) return;
    if (isFocused) {
      if (_controller.text.isEmpty) _maybeShowRecent();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _applySuggestion(String value) {
    _debounce?.cancel();
    // Bump the query id so any in-flight onSearch result is discarded.
    _queryId++;
    _controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    widget.onSuggestionTap?.call(value);
    _removeOverlay();
    if (status.isLoading) resetStatus();
    setState(() {});
  }

  void _clear() {
    _debounce?.cancel();
    _queryId++;
    _controller.clear();
    widget.onChanged?.call('');
    _removeOverlay();
    if (status.isLoading) resetStatus();
    setState(() {});
    focusNode.requestFocus();
    // Surface recent searches now that the field is empty + focused.
    _maybeShowRecent();
  }

  // --- Overlay UI -------------------------------------------------------------

  Widget _buildOverlay(BuildContext overlayContext) {
    final material = Theme.of(context);
    final suggestions = _suggestions;
    return Positioned(
      width: _fieldWidth(),
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: AlignmentDirectional.bottomStart.resolve(
          Directionality.of(context),
        ),
        followerAnchor: AlignmentDirectional.topStart.resolve(
          Directionality.of(context),
        ),
        offset: const Offset(0, 4),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: material.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                if (_showingRecent)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 4),
                    child: Text(
                      'Recent',
                      style: material.textTheme.labelSmall?.copyWith(
                        color: material.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                for (final s in suggestions)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      _showingRecent ? Icons.history : Icons.search,
                      size: 20,
                    ),
                    title: Text(s),
                    onTap: () => _applySuggestion(s),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _fieldWidth() {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size.width;
    return 320;
  }

  // --- Clear button -----------------------------------------------------------

  Widget? _buildClearButton() {
    if (!widget.showClearButton) return null;
    final visible = _controller.text.isNotEmpty && widget.enabled;
    final reduce = CmxAnimations.reduceMotion(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: visible
          ? GestureDetector(
              key: const ValueKey<String>('cmx-search-clear'),
              behavior: HitTestBehavior.opaque,
              onTap: _clear,
              child: Semantics(
                button: true,
                label: 'Clear',
                child: const Padding(
                  padding: EdgeInsetsDirectional.only(end: 12, start: 8),
                  child: Icon(Icons.close, size: 20),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('cmx-search-empty')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = resolveTheme(
      context,
      focusedColor: widget.focusedColor,
      errorColor: widget.errorColor,
      successColor: widget.successColor,
      borderColor: widget.borderColor,
      backgroundColor: widget.backgroundColor,
      fillColor: widget.fillColor,
      borderRadius: widget.borderRadius,
      borderWidth: widget.borderWidth,
      borderStyle: widget.borderStyle,
      contentPadding: widget.contentPadding,
      labelStyle: widget.labelStyle,
      hintStyle: widget.hintStyle,
      inputStyle: widget.inputStyle,
    );

    return TapRegion(
      onTapOutside: (_) {
        if (_overlayEntry != null) _removeOverlay();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: CmxFieldScaffold(
          theme: theme,
          status: status,
          isEmpty: _controller.text.isEmpty,
          enabled: widget.enabled,
          label: widget.label,
          hint: widget.hint,
          showCheckmark: false,
          prefix: const Icon(Icons.search),
          suffix: _buildClearButton(),
          shakeAnimation: shakeAnimation,
          child: TextField(
            controller: _controller,
            focusNode: focusNode,
            enabled: widget.enabled,
            decoration: null,
            style: theme.inputStyle,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.text,
            onChanged: _onChanged,
            onSubmitted: (value) {
              _debounce?.cancel();
              widget.onDebouncedChanged?.call(value);
            },
          ),
        ),
      ),
    );
  }
}
