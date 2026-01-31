import 'package:flutter/material.dart';

class MRPrimaryButton extends StatelessWidget {
  const MRPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.color = const Color(0xFF200F4C), // #200f4c
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        elevation: 10,
        shadowColor: color.withOpacity(.25),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withOpacity(.10),
          highlightColor: Colors.white.withOpacity(.06),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child:
                  loading
                      ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Row(
                        key: const ValueKey('text'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            text,
                            style: const TextStyle(
                              fontFamily: 'TTNorms',
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
