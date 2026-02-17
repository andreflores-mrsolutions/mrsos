import 'package:flutter/material.dart';
import 'package:mrsos/main.dart';
import 'package:mrsos/services/push_router.dart';
import 'package:video_player/video_player.dart';

import 'welcome_screen.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  late final VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/video/mi_splash.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });

    _controller.setLooping(false);

    _controller.addListener(() {
      if (!mounted) return;

      final v = _controller.value;

      // cuando termina el video, navegar
      if (v.isInitialized &&
          !_navigated &&
          v.position >= v.duration &&
          !v.isPlaying) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomeMRSOSScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(250, 252, 255, 255),
      body: Center(
        child:
            _controller.value.isInitialized
                ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                )
                : Image.asset(
                  'assets/images/logo MR.webp',
                  height: 96,
                  fit: BoxFit.contain,
                ),
      ),
    );
  }
}
