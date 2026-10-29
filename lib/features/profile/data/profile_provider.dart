import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/data/home_service.dart';
import '../../home/data/models/user_profile.dart';

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(() {
  return ProfileNotifier();
});

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  FutureOr<UserProfile> build() async {
    return _fetchProfile();
  }

  Future<UserProfile> _fetchProfile({bool forceRefresh = false}) async {
    final service = ref.read(homeServiceProvider);

    if (!forceRefresh) {
      final cached = service.peekCachedProfile();
      if (cached != null) return cached;
    }

    try {
      return await service.getProfile(forceRefresh: forceRefresh);
    } on DioException catch (e) {
      final msg = service.extractErrorMessage(e);
      throw Exception(msg);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchProfile(forceRefresh: true));
  }

  Future<void> updatePicture(String path) async {
    final service = ref.read(homeServiceProvider);
    try {
      await service.updateProfilePicture(path);
      final updated = await service.getProfile(forceRefresh: true);
      state = AsyncValue.data(updated);
    } on DioException catch (e) {
      final msg = service.extractErrorMessage(e);
      throw Exception(msg);
    }
  }
}
