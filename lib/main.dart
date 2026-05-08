// CodePad — code-server native wrapper for iPad
// v0.1.0 2026-05-08
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  runApp(const CodePadApp());
}

class CodePadApp extends StatelessWidget {
  const CodePadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodePad',
      theme: ThemeData.dark(),
      home: const CodeServerView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CodeServerView extends StatefulWidget {
  const CodeServerView({super.key});

  @override
  State<CodeServerView> createState() => _CodeServerViewState();
}

class _CodeServerViewState extends State<CodeServerView> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  static const String _serverUrl = 'http://192.168.0.99:8080';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    _controller = WebViewController.fromPlatformCreationParams(params);

    if (_controller.platform is WebKitWebViewController) {
      final wkController = _controller.platform as WebKitWebViewController;
      wkController.setAllowsBackForwardNavigationGestures(true);
      wkController.setInspectable(true);
    }

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E1E1E))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _loading = true;
          _error = null;
        }),
        onPageFinished: (_) {
          setState(() => _loading = false);
          _controller.runJavaScript('''
            (function() {
              // 1. 消除 300ms 点击延迟
              var style = document.createElement('style');
              style.textContent = '* { touch-action: manipulation !important; } '
                + '.monaco-editor { will-change: transform; }';
              document.head.appendChild(style);

              // 2. 禁止 iOS 在 input 聚焦时自动缩放（缩放会触发重排导致卡顿）
              var meta = document.querySelector('meta[name="viewport"]');
              if (meta) {
                meta.content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
              }

              // 3. Monaco 性能优化 + IME 修复
              function patchMonaco() {
                if (window.monaco && window.monaco.editor) {
                  var opts = {
                    accessibilitySupport: 'off',
                    minimap: { enabled: false },
                    smoothScrolling: false,
                    cursorSmoothCaretAnimation: 'off',
                    renderWhitespace: 'none',
                    renderControlCharacters: false,
                    renderLineHighlight: 'none',
                    occurrencesHighlight: false,
                    selectionHighlight: false,
                    codeLens: false,
                    folding: false,
                  };
                  window.monaco.editor.getEditors().forEach(function(e) {
                    e.updateOptions(opts);
                  });
                  window.monaco.editor.onDidCreateEditor(function(e) {
                    e.updateOptions(opts);
                  });
                } else {
                  setTimeout(patchMonaco, 500);
                }
              }
              patchMonaco();
            })();
          ''');
        },
        onWebResourceError: (error) {
          // 只对主框架错误显示错误页，忽略子资源错误
          if (error.isForMainFrame != false) {
            setState(() {
              _loading = false;
              _error = '无法连接服务器\n[${error.errorCode}] ${error.description}';
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(_serverUrl));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: SafeArea(
          child: Stack(
            children: [
              if (_error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white54, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => _controller.reload(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              else
                WebViewWidget(controller: _controller),
              if (_loading)
                const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: Colors.blue,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
