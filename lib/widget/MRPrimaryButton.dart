import 'package:flutter/material.dart';

import 'colors.dart';

class MRPrimaryButton extends StatelessWidget {
  const MRPrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.color = MRSColors.teal,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(15),
        elevation: 0,
        shadowColor: color.withOpacity(.25),
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(15),
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
                      : Padding(
                        key: const ValueKey('text'),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(icon, color: Colors.white),
                          ],
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
