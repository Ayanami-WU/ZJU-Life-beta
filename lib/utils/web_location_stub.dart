String currentHref() => '';

String appHashUrl(String route) => route.startsWith('/') ? route : '/$route';

void replace(String url) {}
