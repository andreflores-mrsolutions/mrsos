import 'package:flutter/material.dart';

class MRSkeleton extends StatefulWidget {
  const MRSkeleton({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<MRSkeleton> createState() => _MRSkeletonState();
}

class _MRSkeletonState extends State<MRSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value; // 0..1
        final base = Colors.grey.withOpacity(0.18);
        final hi = Colors.grey.withOpacity(0.32);

        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            // desatura un poquito
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment(-1.0 + (2.0 * t), -1),
                end: Alignment(1.0 + (2.0 * t), 1),
                colors: [base, hi, base],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 14,
    this.margin,
  });

  final double height;
  final double? width;
  final double radius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.22),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
