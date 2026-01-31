import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.bottom,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
  });

  final Widget child;
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3F0FF),
              Color(0xFFFFFFFF),
              Color(0xFFF7F6FF),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.40, 0.75, 1.0],
          ),
        ),
        child: SafeArea(child: Padding(padding: padding, child: child)),
      ),
      bottomNavigationBar:
          bottom == null
              ? null
              : SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(22, 10, 22, 14 + bottomInset),
                  child: bottom!,
                ),
              ),
    );
  }
}
