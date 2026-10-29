import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import 'faq_service.dart';
import 'models/faq_item.dart';

final faqServiceProvider = Provider<FaqService>((ref) {
  return FaqService(dioClient: ref.watch(dioClientProvider));
});

final faqProvider = AutoDisposeAsyncNotifierProviderFamily<
    FaqNotifier, List<FaqItem>, String>(() {
  return FaqNotifier();
});

class FaqNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<FaqItem>, String> {
  @override
  FutureOr<List<FaqItem>> build(String arg) async {
    return _fetch(q: arg);
  }

  Future<List<FaqItem>> _fetch({
    required String q,
    bool forceRefresh = false,
  }) async {
    final service = ref.read(faqServiceProvider);

    if (!forceRefresh) {
      final cached = service.peekCachedList(q: q);
      if (cached != null) return cached;
    }

    try {
      return await service.list(q: q, forceRefresh: forceRefresh);
    } on DioException catch (e) {
      throw Exception(service.extractErrorMessage(e));
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(q: arg, forceRefresh: true));
  }
}
