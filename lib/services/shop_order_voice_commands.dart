import 'dart:math' as math;

/// Voice command matching for incoming shop order accept/reject.
abstract final class ShopOrderVoiceCommands {
  static const List<String> rejectPhrases = <String>[
    'ปฏิเสธออเดอร์ด้วยเสียง',
    'ปฏิเสธออเดอร์ออก',
    'ปฏิเสธออเดอร์',
    'ไม่รับออเดอร์',
    'ยกเลิกออเดอร์',
    'rejectorder',
    'ไม่รับ',
    'ปฏิเสธ',
    'ยกเลิก',
  ];

  static const List<String> acceptPhrases = <String>[
    'รับออเดอร์ด้วยเสียง',
    'รับออเดอร์เข้า',
    'ตกลงรับออเดอร์',
    'ยืนยันออเดอร์',
    'รับออเดอร์',
    'acceptorder',
    'ยืนยัน',
    'ตกลง',
    'รับ',
  ];

  static const List<String> backPhrases = <String>[
    'ย้อนกลับ',
    'ถอยกลับ',
    'กลับหน้าก่อน',
    'กลับ',
    'back',
  ];

  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('คิวอาร์', 'qr')
        .replaceAll(RegExp(r'[^a-z0-9ก-๙]+'), '');
  }

  /// Returns `true` for accept, `false` for reject, `null` if unmatched.
  static bool? matchAcceptReject(String words) {
    final normalized = normalize(words);
    if (normalized.isEmpty) return null;

    _VoicePhraseMatch? bestReject;
    for (final phrase in rejectPhrases) {
      final match = _matchPhrase(normalized, phrase);
      if (match == null) continue;
      if (bestReject == null || match.confidence > bestReject.confidence) {
        bestReject = match;
      }
    }

    _VoicePhraseMatch? bestAccept;
    for (final phrase in acceptPhrases) {
      final match = _matchPhrase(normalized, phrase);
      if (match == null) continue;
      if (bestAccept == null || match.confidence > bestAccept.confidence) {
        bestAccept = match;
      }
    }

    final rejectScore = bestReject?.confidence ?? 0;
    final acceptScore = bestAccept?.confidence ?? 0;
    if (rejectScore <= 0 && acceptScore <= 0) return null;

    if (rejectScore >= acceptScore && bestReject!.shouldTrigger) {
      return false;
    }
    if (acceptScore > rejectScore && bestAccept!.shouldTrigger) {
      return true;
    }
    return null;
  }

  static String? describeMatch(String words) {
    final normalized = normalize(words);
    if (normalized.isEmpty) return null;
    if (matchBackNavigation(words)) return 'ย้อนกลับ';
    final decision = matchAcceptReject(words);
    if (decision == null) return null;
    return decision ? 'รับออเดอร์' : 'ปฏิเสธออเดอร์';
  }

  static bool matchBackNavigation(String words) {
    final normalized = normalize(words);
    if (normalized.isEmpty) return false;

    _VoicePhraseMatch? bestMatch;
    for (final phrase in backPhrases) {
      final match = _matchPhrase(normalized, phrase);
      if (match == null) continue;
      if (bestMatch == null || match.confidence > bestMatch.confidence) {
        bestMatch = match;
      }
    }
    return bestMatch?.shouldTrigger ?? false;
  }

  static _VoicePhraseMatch? _matchPhrase(
    String normalizedInput,
    String phrase,
  ) {
    final normalizedPhrase = normalize(phrase);
    if (normalizedPhrase.isEmpty) return null;

    if (normalizedPhrase.length <= 3 && normalizedInput != normalizedPhrase) {
      return null;
    }

    final exact = normalizedInput.contains(normalizedPhrase);
    final confidence = exact
        ? 1.0
        : _voiceSimilarity(normalizedInput, normalizedPhrase);
    if (confidence < 0.45) return null;

    // Standalone "รับ" only when user says exactly that.
    if (normalizedPhrase == 'รับ' && normalizedInput != 'รับ') {
      return null;
    }

    return _VoicePhraseMatch(
      phrase: phrase,
      confidence: confidence,
      isExact: exact,
    );
  }
}

class _VoicePhraseMatch {
  const _VoicePhraseMatch({
    required this.phrase,
    required this.confidence,
    required this.isExact,
  });

  final String phrase;
  final double confidence;
  final bool isExact;

  bool get shouldTrigger {
    final normalizedPhraseLength = phrase.replaceAll(RegExp(r'\s+'), '').length;
    final threshold = normalizedPhraseLength <= 4 ? 0.78 : 0.68;
    return confidence >= threshold;
  }
}

double _voiceSimilarity(String input, String phrase) {
  if (input == phrase) return 1;
  if (input.contains(phrase) || phrase.contains(input)) {
    final shorter = math.min(input.length, phrase.length);
    final longer = math.max(input.length, phrase.length);
    if (longer == 0) return 0;
    return shorter / longer;
  }

  final windowScore = input.length > phrase.length
      ? _bestWindowSimilarity(input, phrase)
      : 0.0;
  final directDistance = _levenshteinDistance(input, phrase);
  final directMax = math.max(input.length, phrase.length);
  final directScore = directMax == 0 ? 0.0 : 1 - (directDistance / directMax);
  return math.max(windowScore, directScore).clamp(0.0, 1.0);
}

double _bestWindowSimilarity(String input, String phrase) {
  if (phrase.isEmpty || input.length < phrase.length) return 0;
  var bestScore = 0.0;
  final minWindow = math.max(1, phrase.length - 2);
  final maxWindow = math.min(input.length, phrase.length + 2);
  for (
    var windowLength = minWindow;
    windowLength <= maxWindow;
    windowLength++
  ) {
    for (var start = 0; start <= input.length - windowLength; start++) {
      final window = input.substring(start, start + windowLength);
      final distance = _levenshteinDistance(window, phrase);
      final maxLength = math.max(window.length, phrase.length);
      final score = maxLength == 0 ? 0.0 : 1 - (distance / maxLength);
      if (score > bestScore) bestScore = score;
    }
  }
  return bestScore;
}

int _levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (index) => index);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      final substitution = previous[j] + (a[i] == b[j] ? 0 : 1);
      current[j + 1] = math.min(insertion, math.min(deletion, substitution));
    }
    previous = current;
  }
  return previous[b.length];
}
