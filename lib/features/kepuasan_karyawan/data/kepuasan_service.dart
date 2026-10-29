import 'package:dio/dio.dart';

import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import 'models/kepuasan_models.dart';

class KepuasanService {
  KepuasanService({DioClient? dioClient})
    : _dio = (dioClient ?? DioClient()).dio;

  final Dio _dio;

  Future<SatisfactionSurvey?> getActiveSurvey() async {

    final response = await _dio.get(
      '/satisfaction-surveys',
      queryParameters: {'_ts': DateTime.now().millisecondsSinceEpoch},
    );
    final items = _list(response.data);
    for (final raw in items) {
      final survey = SatisfactionSurvey.fromJson(_map(raw));
      if (_isVisibleOnFab(survey)) return survey;
    }
    return null;
  }

  Future<List<SatisfactionSurvey>> listActiveSurveys() async {
    final response = await _dio.get(
      '/satisfaction-surveys',
      queryParameters: {'_ts': DateTime.now().millisecondsSinceEpoch},
    );
    return _list(response.data)
        .map((item) => SatisfactionSurvey.fromJson(_map(item)))
        .where(_isVisibleOnFab)
        .toList(growable: false);
  }

  bool _isVisibleOnFab(SatisfactionSurvey survey) {
    if (survey.id.isEmpty) return false;
    if (survey.submitted) return false;
    if (survey.status.toUpperCase() != 'ACTIVE') return false;
    final now = DateTime.now();
    if (survey.endAt.isBefore(now)) return false;
    if (survey.startAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return false;
    }
    return true;
  }

  Future<SatisfactionSurvey> getSurvey(String id) async {
    final response = await _dio.get('/satisfaction-surveys/$id');
    return SatisfactionSurvey.fromJson(_dataMap(response.data));
  }

  Future<void> submitAnswers({
    required String surveyId,
    required List<SatisfactionAnswerInput> answers,
  }) async {
    await _dio.post(
      '/satisfaction-surveys/$surveyId/answers',
      data: {'answers': answers.map((a) => a.toJson()).toList(growable: false)},
    );
  }

  Future<void> submitDailyMood(int score, String emoji) async {
    await _dio.post('/mood', data: {'score': score, 'emoji': emoji});
  }

  Future<List<Map<String, dynamic>>> getMoodTrend({int days = 7}) async {
    final response = await _dio.get(
      '/mood/trend',
      queryParameters: {'days': days},
    );
    final items = _list(response.data);
    return items.map((item) {
      final raw = _map(item);
      return {
        'date': DateTime.parse(raw['date'] as String),
        'score': raw['score'] as int,
        'emoji': raw['emoji'] as String? ?? '',
      };
    }).toList(growable: false);
  }

  String extractErrorMessage(Object error) {
    if (error is DioException) return ApiError.fromDio(error);
    return error.toString();
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    if (body is Map) {
      final data = body['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return Map<String, dynamic>.from(body);
    }
    return {};
  }

  List<dynamic> _list(dynamic body) {
    if (body is List) return body;
    if (body is! Map) return const [];

    final root = Map<String, dynamic>.from(body);
    final data = root['data'];
    if (data is List) return data;
    if (data is Map) {
      final nested = Map<String, dynamic>.from(data);
      final items = nested['items'] ?? nested['data'];
      if (items is List) return items;
    }

    final items = root['items'];
    if (items is List) return items;
    return const [];
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}

extension on SatisfactionSurvey {
  SatisfactionSurvey copyWith({String? id}) {
    return SatisfactionSurvey(
      id: id ?? this.id,
      title: title,
      description: description,
      instruction: instruction,
      startAt: startAt,
      endAt: endAt,
      status: status,
      submitted: submitted,
      sections: sections,
    );
  }
}
