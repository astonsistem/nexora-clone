import 'package:flutter/foundation.dart';

class KepuasanFabRefresh extends ChangeNotifier {
  KepuasanFabRefresh._();

  static final KepuasanFabRefresh instance = KepuasanFabRefresh._();

  int _token = 0;
  int get token => _token;

  void ping() {
    _token++;
    notifyListeners();
  }
}
