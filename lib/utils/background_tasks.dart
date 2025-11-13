import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Runs a heavy function on a background isolate using Flutter's [compute].
///
/// Example:
/// final result = await computeInBackground(parseLargeJson, jsonString);
Future<R> computeInBackground<Q, R>(R Function(Q) callback, Q message) {
  // Flutter's compute signature is compute<Q, R>(callback, message)
  return compute<Q, R>((Q msg) => callback(msg), message);
}

/// Example heavy task: parse a large JSON string into a Map.
/// Move work like this off the UI thread to avoid jank.
Map<String, dynamic> parseLargeJson(String source) {
  return jsonDecode(source) as Map<String, dynamic>;
}
