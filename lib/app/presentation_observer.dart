import 'package:flutter/material.dart';

/// A single navigator inventory keeps timer dialogs behind existing user tasks.
class PresentationObserver extends NavigatorObserver {
  PresentationObserver(this.onChanged);
  final VoidCallback onChanged;
  final List<Route<dynamic>> _routes = [];
  bool get blocked =>
      _routes.isNotEmpty &&
      (_routes.last is PopupRoute || _routes.last.settings.name == 'editing');
  void _changed() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _changed();
  }
}
