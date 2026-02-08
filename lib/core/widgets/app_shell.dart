import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';

class AppShell extends CompositionWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget Function(BuildContext) setup() {
    return (context) {
      return child;
    };
  }
}
