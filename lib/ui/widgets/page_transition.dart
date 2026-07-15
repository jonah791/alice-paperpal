import 'package:flutter/material.dart';

class SlideInTransitionBuilder extends PageTransitionsBuilder {
  const SlideInTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Cubic(0.77, 0.0, 0.18, 1.0);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: curve,
        reverseCurve: curve,
      )),
      child: child,
    );
  }
}
