import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  static String get _defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost/samde_db';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2/samde_db';
    }
    return 'http://localhost/samde_db';
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final response = await _client.get(uri, headers: _headers);
    return _processResponse(response);
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    return _processResponse(response);
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final response = await _client.put(
      uri,
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    return _processResponse(response);
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final response = await _client.delete(uri, headers: _headers);
    return _processResponse(response);
  }

  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    return Uri.parse('$_baseUrl/$normalizedEndpoint').replace(
      queryParameters: queryParams?.isEmpty ?? true ? null : queryParams,
    );
  }

  Map<String, String> get _headers => const {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  dynamic _processResponse(http.Response response) {
    final decodedBody = response.body.isEmpty
        ? null
        : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    if (decodedBody is Map<String, dynamic> && decodedBody['error'] != null) {
      throw ApiException(
        decodedBody['error'].toString(),
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      'Error del servidor (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  void dispose() {
    _client.close();
  }
}
