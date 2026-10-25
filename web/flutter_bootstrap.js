// ChatMate Flutter bootstrap.
//
// Deliberately no serviceWorkerSettings here: Flutter's generated worker
// unregisters itself, which can stop Chrome from offering installation.
// web/service-worker.js provides the installable fetch handler instead.
{{flutter_js}}
{{flutter_build_config}}

// Start the CanvasKit download while main.dart.js is still loading. This is the
// largest asset in the web build; fetching it in parallel cuts the time to the
// first frame. The loader uses the chromium variant for Chromium browsers with
// image codecs + V8 break iterators, and the full variant everywhere else.
(function () {
  var config = _flutter.buildConfig;
  var build = config && config.builds && config.builds[0];
  if (!config || !config.engineRevision || !build || build.renderer !== 'canvaskit') return;

  var chromium =
    (navigator.vendor === 'Google Inc.' || navigator.userAgent.indexOf('Edg/') !== -1) &&
    typeof ImageDecoder !== 'undefined' &&
    typeof Intl.v8BreakIterator !== 'undefined';

  var link = document.createElement('link');
  link.rel = 'preload';
  link.as = 'fetch';
  link.type = 'application/wasm';
  link.crossOrigin = 'anonymous';
  link.href = 'https://www.gstatic.com/flutter-canvaskit/' + config.engineRevision +
    (chromium ? '/chromium' : '') + '/canvaskit.wasm';
  document.head.appendChild(link);
})();

_flutter.loader.load();
