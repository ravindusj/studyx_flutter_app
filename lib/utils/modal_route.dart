import 'package:flutter/material.dart';

class ModalPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final bool fullscreenDialog;
  
  ModalPageRoute({
    required this.page,
    this.fullscreenDialog = true,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeOutQuart;
      
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);
      
      var fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
      );
      

      return Stack(
        children: [
          FadeTransition(
            opacity: fadeAnimation.drive(Tween(begin: 0.0, end: 0.5)),
            child: Container(color: Colors.black),
          ),
          SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        ],
      );
    },
    barrierColor: Colors.transparent,
    opaque: false,
    barrierDismissible: true,
    fullscreenDialog: fullscreenDialog,
  );
}
