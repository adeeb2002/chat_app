import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LinkedInService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();

  Future<Map<String, dynamic>?> login() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          dotenv.env['LINKEDIN_CLIENT_ID']!,
          dotenv.env['LINKEDIN_REDIRECT_URI']!,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint:
            'https://www.linkedin.com/oauth/v2/authorization',
            tokenEndpoint:
            'https://www.linkedin.com/oauth/v2/accessToken',
          ),
          scopes: ['openid', 'profile', 'email'],
        ),
      );

      final accessToken = result?.accessToken;
      if (accessToken == null) return null;

      final response = await http.get(
        Uri.parse('https://api.linkedin.com/v2/userinfo'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print('LinkedIn Login Error: $e');
      return null;
    }
  }
}