class HeavyUiGate {
  HeavyUiGate._();

  static int _depth = 0;

  static bool get isActive => _depth > 0;

  static void enter() => _depth++;

  static void leave() {
    if (_depth > 0) _depth--;
  }
}
