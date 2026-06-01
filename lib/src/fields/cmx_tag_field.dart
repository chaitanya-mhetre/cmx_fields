/// A tags-inside-the-field input for `cmx_fields`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cmx_animations.dart';
import '../core/cmx_field_mixin.dart';
import '../core/cmx_field_scaffold.dart';
import '../core/cmx_field_theme.dart';
import '../core/cmx_validators.dart';

/// A polished, animated tag/chip input.
///
/// Tags live *inside* the field: the scaffold's editable area is a [Wrap] of
/// removable chips followed by a flexible inline text input for typing the next
/// tag. The whole field grows vertically as chips wrap onto new lines.
///
/// Features:
/// * Commit a tag by pressing Enter (the keyboard's done action) or by typing
///   any character listed in [separators] (default `,`). The trimmed text is
///   added; empty input is ignored.
/// * Duplicate handling via [allowDuplicates] and an optional [maxTags] cap.
///   Attempting to add when blocked briefly shakes the field instead.
/// * Backspace on an empty input removes the most recent tag.
/// * Chips animate in and out with a scale (reduced-motion safe) and expose a
///   ✕ affordance to remove them individually.
/// * An optional [suggestions] overlay offers matching, not-yet-added tags as
///   the user types; tapping one adds it.
///
/// Works standalone and inside a [Form]; it builds an internal
/// [FormField] of `List<String>` so `Form.validate()` triggers [validator],
/// shows the error and shakes. Every mutation calls [onTagsChanged] with a
/// fresh copy of the tag list. RTL-safe.
class CmxTagField extends StatefulWidget {
  /// Creates a tag field.
  const CmxTagField({
    super.key,
    this.label,
    this.hint,
    this.focusNode,
    this.enabled = true,
    this.initialTags = const <String>[],
    this.maxTags,
    this.suggestions = const <String>[],
    this.onTagsChanged,
    this.tagBackgroundColor,
    this.tagTextColor,
    this.separators = const <String>[','],
    this.allowDuplicates = false,
    this.validator,
    this.autovalidateMode = AutovalidateMode.disabled,
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

  /// Placeholder shown in the inline input when empty.
  final String? hint;

  /// Optional external focus node for the inline text input.
  final FocusNode? focusNode;

  /// Whether the field is interactive.
  final bool enabled;

  /// Tags present when the field is first built.
  final List<String> initialTags;

  /// Maximum number of tags allowed, or `null` for unlimited.
  final int? maxTags;

  /// Candidate tags offered in the suggestion overlay as the user types.
  final List<String> suggestions;

  /// Called with a copy of the tag list after every mutation.
  final void Function(List<String> tags)? onTagsChanged;

  /// Background color of each chip; defaults to a tint of the focus color.
  final Color? tagBackgroundColor;

  /// Text/foreground color of each chip; defaults to the focus color.
  final Color? tagTextColor;

  /// Characters that, when typed, commit the current text as a tag (besides
  /// pressing Enter). Defaults to a single comma.
  final List<String> separators;

  /// Whether the same tag may be added more than once.
  final bool allowDuplicates;

  /// Validates the current tag list; return an error string or `null`.
  ///
  /// When omitted a [Form] treats the field as always valid.
  final CmxValidator<List<String>>? validator;

  /// When validation runs automatically inside a [Form].
  final AutovalidateMode autovalidateMode;

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

  /// Fails when fewer than [count] tags are present.
  static CmxValidator<List<String>> minTags(
    int count, [
    String? message,
  ]) {
    return (List<String>? tags) {
      final n = tags?.length ?? 0;
      if (n >= count) return null;
      return message ?? 'Add at least $count ${count == 1 ? 'tag' : 'tags'}';
    };
  }

  @override
  State<CmxTagField> createState() => _CmxTagFieldState();
}

class _CmxTagFieldState extends State<CmxTagField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxTagField> {
  late final TextEditingController _controller;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _matchingSuggestions = const <String>[];

  late List<String> _tags;
  String? _errorText;

  // Lets the FormField glue notify us of new tag values.
  FormFieldState<List<String>>? _field;

  @override
  void initState() {
    super.initState();
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);
    _tags = List<String>.from(widget.initialTags);
    _controller = TextEditingController();
    focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(CmxTagField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    disposeCmxField();
    super.dispose();
  }

  bool get _atCap => widget.maxTags != null && _tags.length >= widget.maxTags!;

  void _handleFocusChanged() {
    if (!mounted) return;
    if (isFocused) {
      _updateSuggestions();
    } else {
      _removeOverlay();
    }
  }

  // --- Mutations --------------------------------------------------------------

  /// Attempts to add [raw] as a tag. Returns whether it was added.
  bool _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return false;
    if (_atCap) {
      triggerShake();
      return false;
    }
    if (!widget.allowDuplicates && _tags.contains(tag)) {
      triggerShake();
      return false;
    }
    setState(() {
      _tags.add(tag);
      _controller.clear();
    });
    _notifyChanged();
    _updateSuggestions();
    return true;
  }

  void _removeTagAt(int index) {
    if (index < 0 || index >= _tags.length) return;
    setState(() => _tags.removeAt(index));
    _notifyChanged();
    _updateSuggestions();
  }

  void _removeLast() {
    if (_tags.isEmpty) return;
    _removeTagAt(_tags.length - 1);
  }

  void _notifyChanged() {
    final copy = List<String>.from(_tags);
    widget.onTagsChanged?.call(copy);
    _field?.didChange(copy);
    if (_errorText != null && (_field?.errorText == null)) {
      // A fresh edit may have cleared the error; recompute on next validate.
      setState(() => _errorText = null);
      _applyRestStatus();
    }
  }

  void _applyRestStatus() {
    if (!widget.enabled) return;
    if (status.isError) resetStatus();
  }

  // --- Input handling ---------------------------------------------------------

  void _handleChanged(String value) {
    // Commit on any configured separator character appearing in the text.
    for (final sep in widget.separators) {
      if (sep.isEmpty) continue;
      if (value.contains(sep)) {
        final committed = value.replaceAll(sep, '');
        _addTag(committed);
        return;
      }
    }
    _updateSuggestions();
  }

  void _handleSubmitted(String value) {
    _addTag(value);
    // Keep focus so the user can keep typing tags.
    focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controller.text.isEmpty &&
        _tags.isNotEmpty) {
      _removeLast();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // --- Suggestions overlay ----------------------------------------------------

  List<String> _computeSuggestions() {
    if (widget.suggestions.isEmpty) return const <String>[];
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return const <String>[];
    final results = <String>[];
    final seen = <String>{};
    for (final candidate in widget.suggestions) {
      final lower = candidate.toLowerCase();
      if (!lower.contains(query)) continue;
      if (!widget.allowDuplicates && _tags.contains(candidate)) continue;
      if (!seen.add(lower)) continue;
      results.add(candidate);
      if (results.length >= 6) break;
    }
    return results;
  }

  void _updateSuggestions() {
    if (!isFocused || !widget.enabled || _atCap) {
      _removeOverlay();
      return;
    }
    final next = _computeSuggestions();
    if (next.isEmpty) {
      _removeOverlay();
      return;
    }
    _matchingSuggestions = next;
    _showOverlay();
  }

  void _showOverlay() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: _buildOverlay);
      overlay.insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      width: 320,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _matchingSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _matchingSuggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_offer_outlined, size: 20),
                  title: Text(suggestion),
                  onTap: () => _addTag(suggestion),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- Chips ------------------------------------------------------------------

  Widget _buildChip(CmxFieldTheme theme, int index, String tag) {
    final reduce = CmxAnimations.reduceMotion(context);
    final bg =
        widget.tagBackgroundColor ?? theme.focusedColor.withValues(alpha: 0.12);
    final fg = widget.tagTextColor ?? theme.focusedColor;
    return _AnimatedChipIn(
      key: ValueKey<String>('cmx_tag_${index}_$tag'),
      enabled: !reduce,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6, top: 2, bottom: 2),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding:
                const EdgeInsetsDirectional.only(start: 10, end: 4, top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    tag,
                    style: (theme.inputStyle ?? const TextStyle())
                        .copyWith(color: fg, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                InkResponse(
                  radius: 16,
                  onTap: widget.enabled ? () => _removeTagAt(index) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- FormField glue ---------------------------------------------------------

  String? _runValidator(List<String>? value) {
    if (widget.validator == null) return null;
    return widget.validator!(value);
  }

  void _handleFieldStateChanged(FormFieldState<List<String>> field) {
    final error = field.errorText;
    if (error == _errorText) return;
    setState(() => _errorText = error);
    if (error != null) {
      triggerShake();
    } else {
      _applyRestStatus();
    }
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

    return FormField<List<String>>(
      initialValue: List<String>.from(_tags),
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      validator: _runValidator,
      builder: (FormFieldState<List<String>> field) {
        _field = field;
        if (field.errorText != _errorText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleFieldStateChanged(field);
          });
        }

        final isEmpty = _tags.isEmpty && _controller.text.isEmpty;

        return CompositedTransformTarget(
          link: _layerLink,
          child: CmxFieldScaffold(
            theme: theme,
            status: status,
            isEmpty: isEmpty,
            enabled: widget.enabled,
            label: widget.label,
            hint: _tags.isEmpty ? widget.hint : null,
            errorText: _errorText,
            showCheckmark: false,
            shakeAnimation: shakeAnimation,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? focusNode.requestFocus : null,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: <Widget>[
                  for (var i = 0; i < _tags.length; i++)
                    _buildChip(theme, i, _tags[i]),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: IntrinsicWidth(
                      child: Focus(
                        onKeyEvent: _handleKeyEvent,
                        child: TextField(
                          controller: _controller,
                          focusNode: focusNode,
                          enabled: widget.enabled,
                          decoration: null,
                          textInputAction: TextInputAction.done,
                          style: theme.inputStyle,
                          onChanged: _handleChanged,
                          onSubmitted: _handleSubmitted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Plays a one-shot scale-in when first mounted (reduced-motion safe).
class _AnimatedChipIn extends StatelessWidget {
  const _AnimatedChipIn({
    super.key,
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, value, animatedChild) {
        return Transform.scale(
          scale: value.clamp(0.0, 1.0),
          alignment: AlignmentDirectional.centerStart.resolve(
            Directionality.of(context),
          ),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: animatedChild),
        );
      },
      child: child,
    );
  }
}
