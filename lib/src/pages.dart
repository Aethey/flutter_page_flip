import 'package:flutter/foundation.dart';

@immutable
class BookPage {
  const BookPage({
    required this.title,
    required this.body,
    required this.pageNumber,
  });

  final String title;
  final String body;
  final int pageNumber;
}
