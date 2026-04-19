import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  const DocumentViewerScreen(
      {required this.url, required this.title, super.key});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // For PDFs use Google Docs viewer
    final viewUrl = widget.url.toLowerCase().contains('.pdf')
        ? 'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.url)}'
        : widget.url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(viewUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
