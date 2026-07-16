/// Kori 风格页面过渡
import 'package:flutter/material.dart';

class KoriPageTransition extends PageTransitionsBuilder {
  const KoriPageTransition();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(opacity: animation, child: child);
  }
}
