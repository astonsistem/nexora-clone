import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../networks/dio_client.dart';
import '../services/device_service.dart';
import '../storage/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService();
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient.instance;
});
