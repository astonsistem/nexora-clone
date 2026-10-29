class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.linkUrl,
  });

  final String id;
  final String question;
  final String answer;
  final String? linkUrl;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    final faq = json['faq'] as Map<String, dynamic>? ?? json;
    final link = faq['link_url'] as String?;

    return FaqItem(
      id: '${faq['id'] ?? ''}',
      question: faq['question'] as String? ?? '-',
      answer: faq['answer'] as String? ?? '-',
      linkUrl: (link != null && link.trim().isNotEmpty) ? link.trim() : null,
    );
  }
}
