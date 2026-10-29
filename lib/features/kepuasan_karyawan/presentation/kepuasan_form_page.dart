import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/sky_theme.dart';
import '../../../shared/widgets/sky_header_background.dart';
import '../../home/theme/home_tokens.dart';
import '../../../core/config/env_config.dart';
import '../data/models/kepuasan_models.dart';
import '../data/kepuasan_service.dart';

class KepuasanFormPage extends StatefulWidget {
  const KepuasanFormPage({super.key, this.surveyId});

  final String? surveyId;

  @override
  State<KepuasanFormPage> createState() => _KepuasanFormPageState();
}

class _KepuasanFormPageState extends State<KepuasanFormPage> {
  final _service = KepuasanService();
  final Map<String, dynamic> _answers = {};

  SatisfactionSurvey? _survey;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final survey = widget.surveyId != null
          ? await _service.getSurvey(widget.surveyId!)
          : await _service.getActiveSurvey();
      if (!mounted) return;
      setState(() {
        _survey = survey;
        _loading = false;
        if (survey == null) {
          _error = 'Tidak ada survei aktif saat ini.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submit() async {
    final survey = _survey;
    if (survey == null || _submitting) return;

    final allQuestions = <SatisfactionQuestion>[];
    for (final section in survey.sections) {
      allQuestions.addAll(section.questions);
    }

    for (final q in allQuestions) {
      final value = _answers[q.id];
      if (q.type == SatisfactionQuestionType.rating) {
        final rating = value is int ? value : int.tryParse('$value');
        if (rating == null || rating < 1 || rating > q.maxRating) {
          _snack('Isi rating untuk: ${q.question}', isError: true);
          return;
        }
      } else {
        final text = (value?.toString() ?? '').trim();
        if (text.length < 3) {
          _snack('Isi jawaban untuk: ${q.question}', isError: true);
          return;
        }
      }
    }

    setState(() => _submitting = true);
    try {
      await _service.submitAnswers(
        surveyId: survey.id,
        answers: allQuestions
            .map(
              (q) => SatisfactionAnswerInput(
                questionId: q.id,
                answer: '${_answers[q.id]}'.trim(),
              ),
            )
            .toList(growable: false),
      );
      if (!mounted) return;
      _snack('Terima kasih! Survei berhasil dikirim.');
      _close(submitted: true);
    } catch (e) {
      if (!mounted) return;
      _snack(_service.extractErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _close({bool submitted = false}) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop(submitted);
      return;
    }
    Navigator.of(context, rootNavigator: true).maybePop(submitted);
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : HomeTokens.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _periodLabel(SatisfactionSurvey survey) {
    try {
      final fmt = DateFormat('d MMM yyyy', 'id');
      return '${fmt.format(survey.startAt.toLocal())} – ${fmt.format(survey.endAt.toLocal())}';
    } catch (_) {
      final a = survey.startAt.toLocal();
      final b = survey.endAt.toLocal();
      String d(DateTime x) =>
          '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
      return '${d(a)} – ${d(b)}';
    }
  }

  String? _getThumbnailUrl(String? thumbnail) {
    if (thumbnail == null || thumbnail.isEmpty) return null;
    if (thumbnail.startsWith('http://') || thumbnail.startsWith('https://')) {
      return thumbnail;
    }
    final base = EnvConfig.hrisWebBaseUrl ?? EnvConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$base/storage/satisfaction-thumbnails/$thumbnail';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            SkyHeaderBand(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _close(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Kepuasan Karyawan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _survey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Survei tidak tersedia.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: HomeTokens.muted),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    final survey = _survey!;
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if ((survey.thumbnail ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _getThumbnailUrl(survey.thumbnail) ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Text(
                survey.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: HomeTokens.ink,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              if ((survey.description ?? '').isNotEmpty)
                Text(
                  survey.description!,
                  style: const TextStyle(
                    color: HomeTokens.ink,
                    height: 1.45,
                  ),
                ),
              if ((survey.description ?? '').isNotEmpty && (survey.instruction ?? '').isNotEmpty)
                const SizedBox(height: 16),
              if ((survey.instruction ?? '').isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeTokens.accent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: HomeTokens.accent.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.info_outline, size: 16, color: HomeTokens.accent),
                          SizedBox(width: 6),
                          Text(
                            'Petunjuk Pengisian',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: HomeTokens.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        survey.instruction!,
                        style: const TextStyle(
                          color: HomeTokens.ink,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Periode: ${_periodLabel(survey)}',
                style: const TextStyle(
                  color: HomeTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              for (final section in survey.sections) ...[
                if ((section.name ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      section.name!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: HomeTokens.ink,
                      ),
                    ),
                  ),
                if ((section.description ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      section.description!,
                      style: const TextStyle(
                        color: HomeTokens.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                for (final question in section.questions) ...[
                  _QuestionCard(
                    question: question,
                    value: _answers[question.id],
                    onChanged: (value) =>
                        setState(() => _answers[question.id] = value),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              SkyAccentBuilder(
                builder: (context, accent, _) {
                  return FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _submitting ? 'Mengirim...' : 'Kirim Survei',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final SatisfactionQuestion question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomeTokens.ink,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (question.type == SatisfactionQuestionType.rating)
            _RatingRow(
              maxRating: question.maxRating,
              value: value is int ? value as int : int.tryParse('$value'),
              onChanged: onChanged,
            )
          else
            TextField(
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Tulis jawaban Anda',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: HomeTokens.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: HomeTokens.line),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.value,
    required this.maxRating,
    required this.onChanged,
  });

  final int? value;
  final int maxRating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SkyAccentBuilder(
      builder: (context, accent, _) {
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(maxRating, (index) {
            final star = index + 1;
            final selected = (value ?? 0) >= star;
            return IconButton(
              onPressed: () => onChanged(star),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                selected ? Icons.star_rounded : Icons.star_outline_rounded,
                color: selected ? accent : HomeTokens.muted,
                size: 32,
              ),
            );
          }),
        );
      },
    );
  }
}
