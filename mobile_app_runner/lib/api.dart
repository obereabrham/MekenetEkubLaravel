import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  final http.Client _client;
  final FlutterSecureStorage _storage;
  String? _token;

  String get baseUrl => _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<void> restoreToken() async {
    _token = await _storage.read(key: 'mekenet_access_token');
  }

  Future<bool> hasToken() async {
    if (_token == null) await restoreToken();
    return _token != null && _token!.isNotEmpty;
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'mekenet_access_token', value: token);
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'mekenet_access_token');
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) =>
      _request('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) => _request('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);

  Future<Map<String, dynamic>> postFiles(
    String path, {
    required Map<String, String> fields,
    required Map<String, String> files,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1$path'),
    );
    request.headers['Accept'] = 'application/json';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    request.fields.addAll(fields);
    for (final entry in files.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value),
      );
    }

    late final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw const ApiException(
        'Could not reach the site. Check the server, phone network, and API address.',
      );
    }

    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = data['errors'];
      String? firstValidation;
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            firstValidation = value.first.toString();
            break;
          }
        }
      }
      throw ApiException(
        (firstValidation ?? data['message'] ?? data['error'])?.toString() ??
            'The request could not be completed.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? <String, dynamic>{}),
          );
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers);
          break;
        default:
          throw const ApiException('Unsupported request.');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not reach the site. Check the server, phone network, and API address.',
      );
    }

    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // Keep a friendly message for HTML/server errors.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = data['errors'];
      String? firstValidation;
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            firstValidation = value.first.toString();
            break;
          }
        }
      }
      final message =
          (firstValidation ?? data['message'] ?? data['error'])?.toString() ??
          'The request could not be completed.';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return data;
  }
}
