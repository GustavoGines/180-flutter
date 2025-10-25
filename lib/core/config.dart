/// OJO: incluí el `/api` si tu backend lo usa así
const kFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
const kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://one80-api.onrender.com/api',
);
const kEnablePing = bool.fromEnvironment('ENABLE_PING', defaultValue: false);
const kLogHttp = bool.fromEnvironment('LOG_HTTP', defaultValue: false);

/// Helper para unir paths sin dobles barras
String apiPath(String path) {
  final base = kApiBase.replaceAll(RegExp(r'/+$'), '');
  final p = path.replaceFirst(RegExp(r'^/'), '');
  return '$base/$p';
}
