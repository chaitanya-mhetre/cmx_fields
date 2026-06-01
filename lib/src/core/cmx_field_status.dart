/// The lifecycle/visual status of a field.
///
/// Drives the chrome rendered by [CmxFieldScaffold] (border color, checkmark,
/// error row, overlays) so every field reacts to state identically.
enum CmxFieldStatus {
  /// Not focused and not in an error state.
  idle,

  /// Currently focused by the user.
  focused,

  /// Validated successfully (shows the success checkmark / flash).
  valid,

  /// Failed validation (shows the error border + error text + shake).
  error,

  /// Not interactive.
  disabled,

  /// Performing async work (shows the loading indicator).
  loading;

  /// Whether the field is in its error state.
  bool get isError => this == CmxFieldStatus.error;

  /// Whether the field is currently focused.
  bool get isFocused => this == CmxFieldStatus.focused;

  /// Whether the field has been validated successfully.
  bool get isValid => this == CmxFieldStatus.valid;

  /// Whether the field is disabled.
  bool get isDisabled => this == CmxFieldStatus.disabled;

  /// Whether the field is performing async work.
  bool get isLoading => this == CmxFieldStatus.loading;
}
