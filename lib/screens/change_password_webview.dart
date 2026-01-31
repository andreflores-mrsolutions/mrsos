import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ChangePasswordWebViewScreen extends StatefulWidget {
  const ChangePasswordWebViewScreen({super.key, required this.url});

  final String
  url; // ej: https://yellow-chicken-910471.hostingersite.com/php/cambiar_password.php

  @override
  State<ChangePasswordWebViewScreen> createState() =>
      _ChangePasswordWebViewScreenState();
}

class _ChangePasswordWebViewScreenState
    extends State<ChangePasswordWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) => setState(() => _loading = true),
              onPageFinished: (_) => setState(() => _loading = false),
            ),
          )
          ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
