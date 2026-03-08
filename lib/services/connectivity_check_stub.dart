/// Stub for platforms without dart:io (e.g. web). Assumes connectivity = internet.
Future<bool> hasRealInternet() async => true;
