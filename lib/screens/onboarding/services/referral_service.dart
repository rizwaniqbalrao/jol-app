import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/referral_model.dart';

class ReferralService {
  static const String baseUrl =
      'http://13.53.102.145';
  static const String referralEndpoint = '/api/v1/user/process-referral/';

  /// Process referral by hitting the API once
  /// Device ID is automatically checked by the backend
  static Future<ReferralResponse> processReferral() async {
    try {
      final url = Uri.parse('$baseUrl$referralEndpoint');

      // Create a client that follows redirects
      final client = http.Client();

      final response = await client.post(
        url,
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRFTOKEN':
          '0N3Ph6HFBSBMptDCI6XaysOQnYi4NgKo1uQI71g4zawQabS8HYXwHDhJU7imth6U',
          'ngrok-skip-browser-warning': 'true', // Skip ngrok browser warning
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          client.close();
          throw Exception('Request timeout');
        },
      );

      client.close();

      // Handle various success status codes
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          try {
            final jsonData = json.decode(response.body);
            return ReferralResponse.fromJson(jsonData);
          } catch (e) {
            // If response is not JSON, treat as success with no data
            return ReferralResponse(
              success: true,
              message: 'Referral processed successfully',
            );
          }
        } else {
          return ReferralResponse(
            success: true,
            message: 'Referral processed successfully',
          );
        }
      } else if (response.statusCode == 307 || response.statusCode == 308) {
        // Temporary or Permanent Redirect
        return ReferralResponse(
          success: false,
          message: 'Server redirect detected (${response.statusCode}). Check API URL or add trailing slash.',
        );
      } else {
        return ReferralResponse(
          success: false,
          message: 'Failed to process referral: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      return ReferralResponse(
        success: false,
        message: 'Error processing referral: $e',
      );
    }
  }
}