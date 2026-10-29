enum SatisfactionQuestionType { rating, text }

class SatisfactionQuestion {
  const SatisfactionQuestion({
    required this.id,
    required this.question,
    required this.type,
    required this.order,
    this.maxRating = 5,
    this.answer,
  });

  final String id;
  final String question;
  final SatisfactionQuestionType type;
  final int order;
  final int maxRating;
  final String? answer;

  factory SatisfactionQuestion.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['type'] ?? 'text').toString().toLowerCase();
    return SatisfactionQuestion(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      type: typeRaw == 'rating'
          ? SatisfactionQuestionType.rating
          : SatisfactionQuestionType.text,
      order: int.tryParse('${json['order'] ?? 0}') ?? 0,
      maxRating: int.tryParse('${json['max_rating'] ?? 5}') ?? 5,
      answer: json['answer']?.toString(),
    );
  }
}

class SatisfactionSection {
  const SatisfactionSection({
    required this.id,
    this.name,
    this.description,
    required this.order,
    this.questions = const [],
  });

  final String id;
  final String? name;
  final String? description;
  final int order;
  final List<SatisfactionQuestion> questions;

  factory SatisfactionSection.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'];
    final questions = questionsRaw is List
        ? questionsRaw
            .whereType<Map>()
            .map((item) => SatisfactionQuestion.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <SatisfactionQuestion>[];
    questions.sort((a, b) => a.order.compareTo(b.order));

    return SatisfactionSection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      order: int.tryParse('${json['order'] ?? 0}') ?? 0,
      questions: questions,
    );
  }
}

class SatisfactionSurvey {
  const SatisfactionSurvey({
    required this.id,
    required this.title,
    this.description,
    this.instruction,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.thumbnail,
    this.submitted = false,
    this.sections = const [],
  });

  final String id;
  final String title;
  final String? description;
  final String? instruction;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final String? thumbnail;
  final bool submitted;
  final List<SatisfactionSection> sections;

  factory SatisfactionSurvey.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final sections = sectionsRaw is List
        ? sectionsRaw
            .whereType<Map>()
            .map((item) => SatisfactionSection.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <SatisfactionSection>[];
    sections.sort((a, b) => a.order.compareTo(b.order));

    return SatisfactionSurvey(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '-',
      description: json['description']?.toString(),
      instruction: json['instruction']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      startAt: DateTime.tryParse('${json['start_at']}') ?? DateTime.now(),
      endAt: DateTime.tryParse('${json['end_at']}') ?? DateTime.now(),
      status: (json['status'] ?? 'ACTIVE').toString().toUpperCase(),
      submitted: json['submitted'] == true,
      sections: sections,
    );
  }
}

class SatisfactionAnswerInput {
  const SatisfactionAnswerInput({
    required this.questionId,
    required this.answer,
  });

  final String questionId;
  final String answer;

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'answer': answer,
      };
}
