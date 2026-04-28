import 'dart:isolate';
import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// Data structures
// ─────────────────────────────────────────────────────────────────────────────

class PageText {
  final int pageNumber;
  final String text;
  const PageText({required this.pageNumber, required this.text});
}

class SummaryResult {
  final List<String> sentences;
  final int sourcePageCount;
  final SummaryMode mode;
  const SummaryResult({
    required this.sentences,
    required this.sourcePageCount,
    required this.mode,
  });
}

enum SummaryMode { singlePage, chapter, document }

class _ScoredSentence {
  final String text;
  final int originalIndex;
  final int pageNumber;
  double score;

  _ScoredSentence({
    required this.text,
    required this.originalIndex,
    required this.pageNumber,
    required this.score,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry points — run in a Flutter Isolate, never on the main thread
// ─────────────────────────────────────────────────────────────────────────────

/// Summarize a single page. Pass [allPages] for cross-page scoring context.
Future<SummaryResult> summarizePage({
  required PageText page,
  required List<PageText> allPages,
}) async {
  return Isolate.run(() {
    final engine = ExtractiveEngine(allPages: allPages);
    return engine.summarizeSinglePage(page, topK: 3);
  });
}

/// Summarize a chapter (a range of pages, e.g. current ± 2).
Future<SummaryResult> summarizeChapter({
  required List<PageText> pages,
  required List<PageText> allPages,
}) async {
  return Isolate.run(() {
    final engine = ExtractiveEngine(allPages: allPages);
    return engine.summarizeMultiPage(pages, topK: 5);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Core engine
// ─────────────────────────────────────────────────────────────────────────────

class ExtractiveEngine {
  final List<PageText> allPages;

  // Precomputed from allPages at construction — O(N·M) once, reused per query
  late final Map<String, double> _idf;
  late final Map<String, int> _crossPageRecurrence;
  late final int _totalPageCount;

  ExtractiveEngine({required this.allPages}) {
    _totalPageCount = allPages.length;
    _crossPageRecurrence = _buildCrossPageRecurrence();
    _idf = _buildIdf();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  SummaryResult summarizeSinglePage(PageText page, {int topK = 3}) {
    final sentences = _tokenize(page.text);
    if (sentences.isEmpty) {
      return const SummaryResult(
          sentences: [], sourcePageCount: 1, mode: SummaryMode.singlePage);
    }

    final tf = _termFrequency(sentences.join(' '));
    final scored = _scoreSentences(
      sentences: sentences,
      pageNumber: page.pageNumber,
      pageTf: tf,
      isMultiPage: false,
    );

    final top = _selectTopK(scored, topK);
    return SummaryResult(
      sentences: top.map((s) => s.text).toList(),
      sourcePageCount: 1,
      mode: SummaryMode.singlePage,
    );
  }

  SummaryResult summarizeMultiPage(List<PageText> pages, {int topK = 5}) {
    if (pages.isEmpty) {
      return const SummaryResult(
          sentences: [], sourcePageCount: 0, mode: SummaryMode.chapter);
    }

    final allText = pages.map((p) => p.text).join(' ');
    final globalTf = _termFrequency(allText);
    final List<_ScoredSentence> allScored = [];

    for (final page in pages) {
      final sentences = _tokenize(page.text);
      if (sentences.isEmpty) continue;
      final scored = _scoreSentences(
        sentences: sentences,
        pageNumber: page.pageNumber,
        pageTf: globalTf,
        isMultiPage: true,
      );
      allScored.addAll(scored);
    }

    final top = _selectTopK(allScored, topK);

    // Re-sort by (pageNumber, originalIndex) so summary reads in document order
    top.sort((a, b) {
      final pageCmp = a.pageNumber.compareTo(b.pageNumber);
      return pageCmp != 0 ? pageCmp : a.originalIndex.compareTo(b.originalIndex);
    });

    return SummaryResult(
      sentences: top.map((s) => s.text).toList(),
      sourcePageCount: pages.length,
      mode: pages.length <= 3 ? SummaryMode.chapter : SummaryMode.document,
    );
  }

  // ── Scoring pipeline ────────────────────────────────────────────────────────

  List<_ScoredSentence> _scoreSentences({
    required List<String> sentences,
    required int pageNumber,
    required Map<String, double> pageTf,
    required bool isMultiPage,
  }) {
    final total = sentences.length;
    final scored = <_ScoredSentence>[];

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final words = _tokenizeWords(sentence);

      if (_isNoiseSentence(sentence, words)) continue;

      double score = 0.0;
      score += _tfidfScore(words, pageTf);
      score += _positionalScore(i, total);
      score += _crossPageScore(words);
      score += _lengthScore(words.length);
      score += _numericBonus(sentence);
      if (isMultiPage && scored.isNotEmpty) {
        score -= _redundancyPenalty(sentence, scored);
      }

      scored.add(_ScoredSentence(
        text: sentence,
        originalIndex: i,
        pageNumber: pageNumber,
        score: score,
      ));
    }

    return scored;
  }

  // ── Individual scoring functions ────────────────────────────────────────────

  double _tfidfScore(List<String> words, Map<String, double> tf) {
    if (words.isEmpty) return 0.0;
    double total = 0.0;
    for (final word in words) {
      final termTf = tf[word] ?? 0.0;
      final termIdf = _idf[word] ?? log((_totalPageCount + 1).toDouble());
      total += termTf * termIdf;
    }
    return total / words.length;
  }

  double _positionalScore(int index, int total) {
    if (total == 0) return 0.0;
    if (index == 0) return 0.40;
    if (index == total - 1) return 0.15;
    final relativePos = index / total;
    return max(0.0, 0.10 - (relativePos * 0.10));
  }

  double _crossPageScore(List<String> words) {
    int conceptTermCount = 0;
    for (final word in words) {
      if ((_crossPageRecurrence[word] ?? 0) >= 3) conceptTermCount++;
    }
    if (words.isEmpty) return 0.0;
    return min(0.35, (conceptTermCount / words.length) * 0.70);
  }

  double _lengthScore(int wordCount) {
    if (wordCount < 6) return -0.50;
    if (wordCount < 10) return 0.00;
    if (wordCount <= 35) return 0.10;
    if (wordCount <= 50) return 0.05;
    return -0.10;
  }

  double _numericBonus(String sentence) =>
      RegExp(r'\d').hasMatch(sentence) ? 0.08 : 0.0;

  double _redundancyPenalty(
      String candidate, List<_ScoredSentence> existing) {
    final candidateWords = _tokenizeWords(candidate).toSet();
    double maxOverlap = 0.0;

    for (final other in existing) {
      final otherWords = _tokenizeWords(other.text).toSet();
      final intersection = candidateWords.intersection(otherWords).length;
      final union = candidateWords.union(otherWords).length;
      if (union > 0) {
        maxOverlap = max(maxOverlap, intersection / union);
      }
    }

    if (maxOverlap > 0.5) return 0.40;
    if (maxOverlap > 0.3) return 0.15;
    return 0.0;
  }

  // ── Noise filter ────────────────────────────────────────────────────────────

  bool _isNoiseSentence(String sentence, List<String> words) {
    if (words.length < 6) return true;
    if (words.length > 80) return true;

    final upperCount = sentence
        .split('')
        .where((c) =>
            c == c.toUpperCase() &&
            c.trim().isNotEmpty &&
            !RegExp(r'[0-9\W]').hasMatch(c))
        .length;
    final letterCount =
        sentence.split('').where((c) => RegExp(r'[a-zA-Z]').hasMatch(c)).length;
    if (letterCount > 0 && upperCount / letterCount > 0.7) return true;

    if (RegExp(r'https?://|www\.|@').hasMatch(sentence)) return true;
    if (RegExp(r'^[\d\s\.\-\(\)]+$').hasMatch(sentence.trim())) return true;

    return false;
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  List<_ScoredSentence> _selectTopK(List<_ScoredSentence> scored, int k) {
    if (scored.isEmpty) return [];
    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(k).toList();
    top.sort((a, b) => a.originalIndex.compareTo(b.originalIndex));
    return top;
  }

  // ── Preprocessing ───────────────────────────────────────────────────────────

  List<String> _tokenize(String text) {
    if (text.trim().isEmpty) return [];

    String protected = text
        .replaceAll(RegExp(r'\bDr\.'), 'Dr#')
        .replaceAll(RegExp(r'\bMr\.'), 'Mr#')
        .replaceAll(RegExp(r'\bMrs\.'), 'Mrs#')
        .replaceAll(RegExp(r'\bMs\.'), 'Ms#')
        .replaceAll(RegExp(r'\bProf\.'), 'Prof#')
        .replaceAll(RegExp(r'\bSt\.'), 'St#')
        .replaceAll(RegExp(r'\betc\.'), 'etc#')
        .replaceAll(RegExp(r'\bvs\.'), 'vs#')
        .replaceAll(RegExp(r'\be\.g\.'), 'eg#')
        .replaceAll(RegExp(r'\bi\.e\.'), 'ie#')
        .replaceAll(RegExp(r'\bFig\.'), 'Fig#')
        .replaceAll(RegExp(r'\bEq\.'), 'Eq#');

    return protected
        .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'))
        .map((s) => s
            .replaceAll('#', '.')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _tokenizeWords(String sentence) {
    return sentence
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !_stopwords.contains(w))
        .toList();
  }

  Map<String, double> _termFrequency(String text) {
    final words = _tokenizeWords(text);
    if (words.isEmpty) return {};
    final counts = <String, int>{};
    for (final w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
    final total = words.length.toDouble();
    return counts.map((k, v) => MapEntry(k, v / total));
  }

  Map<String, double> _buildIdf() {
    final docFreq = <String, int>{};
    for (final page in allPages) {
      for (final w in _tokenizeWords(page.text).toSet()) {
        docFreq[w] = (docFreq[w] ?? 0) + 1;
      }
    }
    final n = _totalPageCount.toDouble();
    return docFreq
        .map((term, df) => MapEntry(term, log((n + 1) / (df + 1)) + 1));
  }

  Map<String, int> _buildCrossPageRecurrence() {
    final recurrence = <String, int>{};
    for (final page in allPages) {
      for (final w in _tokenizeWords(page.text).toSet()) {
        recurrence[w] = (recurrence[w] ?? 0) + 1;
      }
    }
    return recurrence;
  }

  // ── Stopwords ───────────────────────────────────────────────────────────────

  static const Set<String> _stopwords = {
    'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'any', 'can',
    'had', 'her', 'was', 'one', 'our', 'out', 'has', 'him', 'his', 'how',
    'its', 'may', 'new', 'now', 'old', 'see', 'two', 'who', 'did', 'get',
    'let', 'put', 'say', 'she', 'too', 'use', 'that', 'this', 'with',
    'have', 'from', 'they', 'will', 'been', 'when', 'were', 'what', 'your',
    'said', 'each', 'which', 'their', 'there', 'would', 'about', 'could',
    'other', 'these', 'those', 'than', 'then', 'some', 'into', 'just',
    'more', 'also', 'over', 'such', 'even', 'most', 'made', 'after',
    'while', 'where', 'should', 'being', 'between', 'through', 'during',
    'before', 'without', 'under', 'within', 'along', 'following', 'across',
    'behind', 'beyond', 'plus', 'except', 'however', 'therefore', 'thus',
  };
}
