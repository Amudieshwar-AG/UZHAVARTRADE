import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Override with: --dart-define=API_BASE_URL=http://<ip>:5000
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }
    return 'http://10.143.105.57:5000';
  }

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static String _fallbackFilename(String field) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$field-$ts.webm';
  }

  static Future<http.MultipartFile> _audioPart(
    String field,
    String source,
  ) async {
    if (!kIsWeb) {
      return http.MultipartFile.fromPath(field, source);
    }

    final uri = Uri.parse(source);
    final response = await http.get(uri);
    if (response.statusCode >= 400) {
      throw Exception('Unable to read audio blob from browser memory');
    }

    final name = uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty
        ? uri.pathSegments.last
        : _fallbackFilename(field);
    return http.MultipartFile.fromBytes(
      field,
      response.bodyBytes,
      filename: name,
    );
  }

  static Map<String, dynamic> _decodeJson(http.Response response) {
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {
      'success': false,
      'message': 'Unexpected response format',
      'raw': decoded,
    };
  }

  static Future<Map<String, dynamic>> health() async {
    final response = await http.get(_uri('/health'));
    return _decodeJson(response);
  }

  // Register requires 2 or 3 audio files per backend contract.
  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required List<String> audioFilePaths,
  }) async {
    if (audioFilePaths.length < 2 || audioFilePaths.length > 3) {
      return {
        'success': false,
        'message': 'Please provide 2 or 3 audio files for registration.',
      };
    }

    final request = http.MultipartRequest('POST', _uri('/register'))
      ..fields['name'] = name
      ..fields['phone'] = phone;

    for (final path in audioFilePaths) {
      request.files.add(await _audioPart('audio_files', path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decodeJson(response);
  }

  // Login requires one audio sample and optional phone hint.
  static Future<Map<String, dynamic>> login({
    required String audioFilePath,
    String? phone,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/login'));
    if (phone != null && phone.trim().isNotEmpty) {
      request.fields['phone'] = phone.trim();
    }
    request.files.add(await _audioPart('audio', audioFilePath));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> getSellers() async {
    final response = await http.get(_uri('/sellers'));
    return _decodeJson(response);
  }

  static Future<Map<String, dynamic>> getLoginAttempts({int limit = 20}) async {
    final response = await http.get(_uri('/login-attempts?limit=$limit'));
    return _decodeJson(response);
  }
}
