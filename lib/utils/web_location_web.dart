import 'package:web/web.dart' as web;

String currentHref() => web.window.location.href;

String appHashUrl(String route) {
  final normalized = route.startsWith('/') ? route : '/$route';
  final location = web.window.location;
  return '${location.origin}${location.pathname}#$normalized';
}

void replace(String url) {
  web.window.location.replace(url);
}
