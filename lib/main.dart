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

  static const String _serverUrl = 'http://192.168.0.99:8080/?folder=/Users/sakuralost/Library/Mobile%20Documents/com~apple~CloudDocs/heliostar/App';

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
          _controller.runJavaScript(r'''
            (function() {
              // 1. 消除点击延迟 + Monaco GPU加速
              var s = document.createElement('style');
              s.textContent = '* { touch-action: manipulation !important; }'
                + '.monaco-editor,.xterm { will-change: transform; }'
                + '#cp-bar button:active { opacity: 0.6; }';
              document.head.appendChild(s);

              // 2. 禁止 iOS 聚焦时自动缩放
              var meta = document.querySelector('meta[name="viewport"]');
              if (meta) meta.content = 'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no';

              // 3. Monaco 性能优化
              function patchMonaco() {
                if (window.monaco && window.monaco.editor) {
                  var opts = {
                    accessibilitySupport:'off', minimap:{enabled:false},
                    smoothScrolling:false, cursorSmoothCaretAnimation:'off',
                    renderWhitespace:'none', renderControlCharacters:false,
                    renderLineHighlight:'none', occurrencesHighlight:false,
                    selectionHighlight:false, codeLens:false, folding:false,
                  };
                  window.monaco.editor.getEditors().forEach(function(e){ e.updateOptions(opts); });
                  window.monaco.editor.onDidCreateEditor(function(e){ e.updateOptions(opts); });
                } else { setTimeout(patchMonaco, 500); }
              }
              patchMonaco();

              // 4. 终端快捷键工具栏
              if (document.getElementById('cp-bar')) return;
              var ctrlOn = false;
              var bar = document.createElement('div');
              bar.id = 'cp-bar';
              bar.style.cssText = [
                'position:fixed','bottom:0','left:0','right:0','height:46px',
                'background:#1e1e1e','border-top:1px solid #444',
                'display:flex','align-items:center','padding:0 6px','gap:5px',
                'z-index:99999','overflow-x:auto','-webkit-overflow-scrolling:touch',
                'box-sizing:border-box'
              ].join(';');

              function btn(label, action) {
                var b = document.createElement('button');
                b.textContent = label;
                b.style.cssText = [
                  'min-width:44px','height:34px','border-radius:6px',
                  'background:#3a3a3a','color:#ccc','border:none',
                  'font-size:13px','font-family:-apple-system',
                  'padding:0 10px','flex-shrink:0','cursor:pointer',
                  '-webkit-tap-highlight-color:transparent','user-select:none'
                ].join(';');
                b.addEventListener('touchend', function(e) {
                  e.preventDefault();
                  action(b);
                });
                return b;
              }

              function sendKey(key, opts) {
                var target = document.activeElement;
                var ev = new KeyboardEvent('keydown', Object.assign({
                  key:key, bubbles:true, cancelable:true
                }, opts || {}));
                target.dispatchEvent(ev);
                target.dispatchEvent(new KeyboardEvent('keyup', Object.assign({key:key,bubbles:true},opts||{})));
              }

              // CTRL 锁定键
              var ctrlBtn = btn('CTRL', function(b) {
                ctrlOn = !ctrlOn;
                b.style.background = ctrlOn ? '#0066cc' : '#3a3a3a';
                b.style.color = ctrlOn ? '#fff' : '#ccc';
              });
              bar.appendChild(ctrlBtn);

              function tmuxKey(k, code) {
                // 发 Ctrl+B 前缀，然后发目标键
                sendKey('b',{keyCode:66,ctrlKey:true});
                setTimeout(function(){ sendKey(k,{keyCode:code}); }, 80);
              }

              var keys = [
                ['ESC',   function(){ sendKey('Escape',{keyCode:27}); }],
                ['TAB',   function(){ sendKey('Tab',{keyCode:9,ctrlKey:false}); }],
                ['↑',     function(){ sendKey('ArrowUp',{keyCode:38,ctrlKey:ctrlOn}); ctrlOn=false; ctrlBtn.style.background='#3a3a3a'; ctrlBtn.style.color='#ccc'; }],
                ['↓',     function(){ sendKey('ArrowDown',{keyCode:40,ctrlKey:ctrlOn}); ctrlOn=false; ctrlBtn.style.background='#3a3a3a'; ctrlBtn.style.color='#ccc'; }],
                ['←',     function(){ sendKey('ArrowLeft',{keyCode:37,ctrlKey:ctrlOn}); ctrlOn=false; ctrlBtn.style.background='#3a3a3a'; ctrlBtn.style.color='#ccc'; }],
                ['→',     function(){ sendKey('ArrowRight',{keyCode:39,ctrlKey:ctrlOn}); ctrlOn=false; ctrlBtn.style.background='#3a3a3a'; ctrlBtn.style.color='#ccc'; }],
                ['C',     function(){ sendKey('c',{keyCode:67,ctrlKey:true}); ctrlOn=false; ctrlBtn.style.background='#3a3a3a'; ctrlBtn.style.color='#ccc'; }],
                ['D',     function(){ sendKey('d',{keyCode:68,ctrlKey:true}); ctrlOn=false; ctrlBtn.style.background='#3a3a3a'; ctrlBtn.style.color='#ccc'; }],
                ['L',     function(){ sendKey('l',{keyCode:76,ctrlKey:true}); ctrlOn=false; ctrlBtn.style.background='#3a3a3a'; ctrlBtn.style.color='#ccc'; }],
                ['|',     function(){ sendKey('|'); }],
                ['~',     function(){ sendKey('~'); }],
                // tmux 快捷键分隔符
                ['─',     function(){}],
                ['^B',    function(){ sendKey('b',{keyCode:66,ctrlKey:true}); }],
                ['新窗',  function(){ tmuxKey('c',67); }],
                ['下分',  function(){ tmuxKey('"',222); }],
                ['右分',  function(){ tmuxKey('%',53); }],
                ['上格',  function(){ sendKey('ArrowUp',{keyCode:38,ctrlKey:true,altKey:false}); }],
              ];
              keys.forEach(function(k){
                var b = btn(k[0], k[1]);
                // Ctrl 组合键显示蓝色前缀
                if(['C','D','L'].indexOf(k[0])!==-1) b.title = 'Ctrl+'+k[0];
                bar.appendChild(b);
              });

              document.body.appendChild(bar);
              // 给终端区域留出底部空间
              document.body.style.paddingBottom = '46px';
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
