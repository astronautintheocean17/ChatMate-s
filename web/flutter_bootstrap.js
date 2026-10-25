// ChatMate Flutter bootstrap.
//
// Deliberately no serviceWorkerSettings here: Flutter's generated worker
// unregisters itself, which can stop Chrome from offering installation.
// web/service-worker.js provides the installable fetch handler instead.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
