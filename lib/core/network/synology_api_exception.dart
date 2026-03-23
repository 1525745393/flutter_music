class SynologyApiException implements Exception {
  const SynologyApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
