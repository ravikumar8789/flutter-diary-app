import 'dart:io';

/// Performs real internet check via DNS lookup (mobile/desktop only).
Future<bool> hasRealInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}
