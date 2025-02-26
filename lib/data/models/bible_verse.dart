class BibleVerse {
  final int idx;
  final int cate;
  final int book;
  final int chapter;
  final int paragraph;
  final String sentence;
  final String testament;
  final String longLabel;
  final String shortLabel;

  BibleVerse({
    required this.idx,
    required this.cate,
    required this.book,
    required this.chapter,
    required this.paragraph,
    required this.sentence,
    required this.testament,
    required this.longLabel,
    required this.shortLabel,
  });

  factory BibleVerse.fromMap(Map<String, dynamic> map) {
    return BibleVerse(
      idx: map['idx'] as int,
      cate: map['cate'] as int,
      book: map['book'] as int,
      chapter: map['chapter'] as int,
      paragraph: map['paragraph'] as int,
      sentence: map['sentence'] as String,
      testament: map['testament'] as String,
      longLabel: map['long_label'] as String,
      shortLabel: map['short_label'] as String,
    );
  }
}
