import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/open_file_colors.dart';
import '../../../../domain/entities/file_entity.dart';
import '../../../widgets/o_banner.dart';
import '../../../widgets/viewer_shell.dart';
import '../text_code/text_code_viewer.dart';

class HtmlViewer extends ConsumerStatefulWidget {
  final FileEntity file;

  const HtmlViewer({
    super.key,
    required this.file,
  });

  @override
  ConsumerState<HtmlViewer> createState() => _HtmlViewerState();
}

class _HtmlViewerState extends ConsumerState<HtmlViewer> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _isSourceMode = false;
  bool _javascriptEnabled = false;
  String? _errorMessage;

  static const String _cspMeta =
      '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\' file:; script-src \'none\'; img-src \'self\' data: file:; font-src \'self\' data: file:;">';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    setState(() => _isLoading = true);

    try {
      final file = File(widget.file.path);
      if (!await file.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'HTML file not found.';
        });
        return;
      }

      String rawHtml = await file.readAsString();

      // Belt and braces: Inject offline-only CSP into head
      if (rawHtml.contains('<head>')) {
        rawHtml = rawHtml.replaceFirst('<head>', '<head>$_cspMeta');
      } else if (rawHtml.contains('<html>')) {
        rawHtml = rawHtml.replaceFirst('<html>', '<html><head>$_cspMeta</head>');
      } else {
        rawHtml = '<!DOCTYPE html><html><head>$_cspMeta</head><body>$rawHtml</body></html>';
      }

      final controller = WebViewController()
        ..setJavaScriptMode(
          _javascriptEnabled ? JavaScriptMode.unrestricted : JavaScriptMode.disabled,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              // Strictly block all external network traffic
              if (request.url.startsWith('http://') || request.url.startsWith('https://')) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
            onPageStarted: (_) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (error) {
              if (mounted) {
                // Ignore ERR_BLOCKED_BY_CSP for external images
              }
            },
          ),
        )
        ..loadHtmlString(rawHtml, baseUrl: file.parent.uri.toString());

      _controller = controller;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to render HTML: $e';
        });
      }
    }
  }

  void _toggleJavaScript() {
    setState(() {
      _javascriptEnabled = !_javascriptEnabled;
    });
    _initWebView();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isSourceMode) {
      return TextCodeViewer(file: widget.file);
    }

    final customActions = <Widget>[
      IconButton(
        icon: const Icon(Icons.code),
        tooltip: 'View source code',
        onPressed: () {
          setState(() {
            _isSourceMode = true;
          });
        },
      ),
      TextButton.icon(
        icon: Icon(_javascriptEnabled ? Icons.javascript : Icons.block, size: 16),
        label: Text(_javascriptEnabled ? 'JS ON' : 'JS OFF', style: const TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(
          foregroundColor: _javascriptEnabled ? colors.accentPrimary : colors.textSecondary,
        ),
        onPressed: _toggleJavaScript,
      ),
    ];

    Widget body;
    if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.stateError),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: colors.textPrimary)),
            ],
          ),
        ),
      );
    } else {
      body = Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(colors.accentPrimary),
              ),
            ),
        ],
      );
    }

    return ViewerShell(
      file: widget.file,
      customActions: customActions,
      noticeBanner: !_javascriptEnabled
          ? OBanner.notice(
              text: 'JavaScript is disabled for offline safety.',
              actionLabel: 'Enable',
              onAction: _toggleJavaScript,
            )
          : null,
      child: body,
    );
  }
}
