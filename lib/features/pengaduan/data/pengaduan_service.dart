import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import 'models/pengaduan_models.dart';

class PengaduanService {
  PengaduanService({DioClient? dioClient})
    : _dio = (dioClient ?? DioClient()).dio;

  final Dio _dio;

  Future<List<TicketType>> getTypes() async {
    final response = await _dio.get('/tickets/types');
    return ticketDataList(response.data)
        .map((item) => TicketType.fromJson(_asMap(item)))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<TicketPage> getTickets({
    int page = 1,
    int size = 15,
    String? status,
    String? ticketTypeId,
    String? query,
  }) async {
    final params = <String, dynamic>{'page': page, 'size': size};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (ticketTypeId != null && ticketTypeId.isNotEmpty) {
      params['ticket_type_id'] = ticketTypeId;
    }
    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      params['q'] = trimmedQuery;
    }

    final response = await _dio.get(
      '/tickets',
      queryParameters: params,
    );
    return TicketPage.fromJson(ticketDataMap(response.data));
  }

  Future<Ticket> getTicket(String id) async {
    final response = await _dio.get('/tickets/$id');
    return Ticket.fromJson(ticketDataMap(response.data));
  }

  Future<({Uint8List bytes, String filename})> downloadAttachment(
    String id,
  ) async {
    final response = await _dio.get<List<int>>(
      '/tickets/$id/attachment',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw StateError('Lampiran kosong atau tidak tersedia.');
    }

    final disposition = response.headers.value('content-disposition') ?? '';
    final encoded = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    final plain = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition)?.group(1);
    final rawFilename = encoded ?? plain ?? 'lampiran-pengaduan';
    final filename = Uri.decodeComponent(rawFilename);

    return (bytes: Uint8List.fromList(data), filename: filename);
  }

  Future<Ticket> createTicket({
    required String ticketTypeId,
    required String subject,
    required String description,
    String? attachmentPath,
    ProgressCallback? onSendProgress,
  }) async {
    final fields = <String, dynamic>{
      'ticket_type_id': ticketTypeId,
      'subject': subject.trim(),
      'description': description.trim(),
    };
    if (attachmentPath != null && attachmentPath.isNotEmpty) {
      fields['attachment'] = await MultipartFile.fromFile(attachmentPath);
    }

    final response = await _dio.post(
      '/tickets',
      data: FormData.fromMap(fields),
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
    );
    return Ticket.fromJson(ticketDataMap(response.data));
  }

  String extractErrorMessage(DioException error) => ApiError.fromDio(error);

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }
}
