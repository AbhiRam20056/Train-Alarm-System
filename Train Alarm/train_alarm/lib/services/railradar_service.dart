import 'package:dio/dio.dart';
import '../data/models/train_status.dart';

class RailRadarService {
  static final RailRadarService instance = RailRadarService._();
  RailRadarService._();

  static const _proxyBase =
      'https://us-central1-train-alarm-napcodes.cloudfunctions.net/railradar';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  Future<TrainStatus> getLiveStatus(String trainNo) async {
    final resp = await _dio.get(_proxyBase, queryParameters: {
      'path': '/trains/$trainNo/live',
      'includeCoordinates': 'true',
    });
    _assertSuccess(resp);
    // ignore: avoid_print
    print('[RailRadar] live response keys: ${(resp.data as Map?)?.keys.toList()}');
    final data = (resp.data as Map<String, dynamic>)['data'];
    // ignore: avoid_print
    if (data is Map) print('[RailRadar] data keys: ${data.keys.toList()}');
    return TrainStatus.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getTrainDetails(String trainNo) async {
    final resp = await _dio.get(_proxyBase, queryParameters: {
      'path': '/trains/$trainNo',
    });
    _assertSuccess(resp);
    return (resp.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  void _assertSuccess(Response resp) {
    final body = resp.data as Map<String, dynamic>?;
    if (body != null && body['success'] == false) {
      throw RailRadarException(
        body['error']?.toString() ?? 'Unknown error',
        resp.statusCode ?? 0,
      );
    }
  }
}

class RailRadarException implements Exception {
  final String message;
  final int statusCode;
  const RailRadarException(this.message, this.statusCode);

  bool get isQuotaExceeded => statusCode == 429;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'RailRadarException($statusCode): $message';
}
