// File: services/wallet_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jol_app/screens/auth/models/user_wallet.dart';
import '../../auth/services/secure_storage_service.dart';

// Result wrapper classes
class WalletResult {
  final bool success;
  final Wallet? data;
  final String? error;

  WalletResult({
    required this.success,
    this.data,
    this.error,
  });
}

class AdjustCoinsResult {
  final bool success;
  final AdjustCoinsResponse? data;
  final String? error;

  AdjustCoinsResult({
    required this.success,
    this.data,
    this.error,
  });
}

class RedeemResult {
  final bool success;
  final RedeemResponse? data;
  final String? error;

  RedeemResult({
    required this.success,
    this.data,
    this.error,
  });
}

class WalletService {
  final String baseUrl = 'http://nonabstemiously-stocky-cynthia.ngrok-free.dev/api/v1';
  final SecureStorageService _storage = SecureStorageService();

  // Coin value constant (points needed per coin)
  static const int COIN_VALUE = 1000;

  // ═══════════════════════════════════════════════════════════════
  // GET /v1/user/wallet/ - Get Wallet Balance
  // ═══════════════════════════════════════════════════════════════

  /// Retrieve the user's coin balances
  /// Returns: total_coins, used_coins, available_coins
  Future<WalletResult> getWallet() async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return WalletResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      final csrfToken = await _getCsrfToken();

      final headers = {
        'accept': 'application/json',
        'Authorization': 'Token $token',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      print('GET Wallet - URL: $baseUrl/user/wallet/');

      final response = await http.get(
        Uri.parse('$baseUrl/user/wallet/'),
        headers: headers,
      );

      print('GET Wallet - Status: ${response.statusCode}');
      print('GET Wallet - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final wallet = Wallet.fromJson(data);
        return WalletResult(success: true, data: wallet);
      } else if (response.statusCode == 401) {
        return WalletResult(
          success: false,
          error: 'Session expired. Please log in again.',
        );
      } else {
        String errorMsg = 'Unable to load wallet. Please try again.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMsg = _extractErrorMessage(errorData);
          }
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return WalletResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in getWallet: $e');
      return WalletResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // POST /v1/user/wallet/adjust/ - Adjust Coins (Admin/Test Only)
  // ═══════════════════════════════════════════════════════════════

  /// Manually add or subtract coins (Admin/Test only)
  /// Not part of normal redeem flow
  ///
  /// Parameters:
  /// - coins: Amount to adjust (positive integer)
  /// - type: "increment" to add, "decrement" to subtract
  Future<AdjustCoinsResult> adjustCoins({
    required int coins,
    required String type,
  }) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return AdjustCoinsResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Validate input
      if (coins <= 0) {
        return AdjustCoinsResult(
          success: false,
          error: 'Coins must be a positive number.',
        );
      }

      if (type != 'increment' && type != 'decrement') {
        return AdjustCoinsResult(
          success: false,
          error: 'Type must be either "increment" or "decrement".',
        );
      }

      final csrfToken = await _getCsrfToken();

      final headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      final request = AdjustCoinsRequest(coins: coins, type: type);
      final body = request.toJson();

      print('POST Adjust Coins - Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse('$baseUrl/user/wallet/adjust/'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('POST Adjust Coins - Status: ${response.statusCode}');
      print('POST Adjust Coins - Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final adjustResponse = AdjustCoinsResponse.fromJson(data);
        return AdjustCoinsResult(success: true, data: adjustResponse);
      } else if (response.statusCode == 401) {
        return AdjustCoinsResult(
          success: false,
          error: 'Session expired. Please log in again.',
        );
      } else if (response.statusCode == 400) {
        String errorMsg = 'Unable to adjust coins.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            // Check for specific errors
            if (errorData.containsKey('error')) {
              errorMsg = errorData['error'] as String;
            } else {
              errorMsg = _extractErrorMessage(errorData);
            }
          }
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return AdjustCoinsResult(success: false, error: errorMsg);
      } else {
        String errorMsg = 'Unable to adjust coins. Please try again.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMsg = _extractErrorMessage(errorData);
          }
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return AdjustCoinsResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in adjustCoins: $e');
      return AdjustCoinsResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // POST /v1/wallet/redeem/ - Redeem Game Points to Coins
  // ═══════════════════════════════════════════════════════════════

  /// Convert earned game points into coins
  /// Points needed = coins * COIN_VALUE (currently 1000)
  /// Requires enough available_game_points
  ///
  /// Parameter:
  /// - coins: Number of coins to create
  ///
  /// Returns: coins_awarded, available_game_points, available_coins
  Future<RedeemResult> redeemCoins({required int coins}) async {
    try {
      final token = await _storage.getToken();

      if (token == null) {
        return RedeemResult(
          success: false,
          error: 'Not authenticated. Please log in again.',
        );
      }

      // Validate input
      if (coins <= 0) {
        return RedeemResult(
          success: false,
          error: 'Coins must be a positive number.',
        );
      }

      final csrfToken = await _getCsrfToken();

      final headers = {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      };
      if (csrfToken != null) headers['X-CSRFTOKEN'] = csrfToken;

      final request = RedeemRequest(coins: coins);
      final body = request.toJson();

      print('POST Redeem - Body: ${jsonEncode(body)}');
      print('POST Redeem - Points needed: ${coins * COIN_VALUE}');

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/redeem/'),
        headers: headers,
        body: jsonEncode(body),
      );

      print('POST Redeem - Status: ${response.statusCode}');
      print('POST Redeem - Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final redeemResponse = RedeemResponse.fromJson(data);
        return RedeemResult(success: true, data: redeemResponse);
      } else if (response.statusCode == 401) {
        return RedeemResult(
          success: false,
          error: 'Session expired. Please log in again.',
        );
      } else if (response.statusCode == 400) {
        String errorMsg = 'Unable to redeem coins.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            // Check for specific errors
            if (errorData.containsKey('error')) {
              errorMsg = errorData['error'] as String;
            } else {
              errorMsg = _extractErrorMessage(errorData);
            }
          }
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return RedeemResult(success: false, error: errorMsg);
      } else {
        String errorMsg = 'Unable to redeem coins. Please try again.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMsg = _extractErrorMessage(errorData);
          }
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        return RedeemResult(success: false, error: errorMsg);
      }
    } catch (e) {
      print('Exception in redeemCoins: $e');
      return RedeemResult(
        success: false,
        error: 'Connection issue. Please check your internet and try again.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate points needed for a given number of coins
  int calculatePointsNeeded(int coins) {
    return coins * COIN_VALUE;
  }

  /// Calculate coins that can be created from available points
  int calculateAvailableCoins(int availablePoints) {
    return availablePoints ~/ COIN_VALUE;
  }

  /// Extract error message from error response
  String _extractErrorMessage(Map<String, dynamic> errorData) {
    final errors = <String>[];
    errorData.forEach((key, value) {
      if (value is List) {
        errors.addAll(value.map((e) => '$key: ${e.toString()}'));
      } else if (value is String) {
        errors.add('$key: $value');
      }
    });
    return errors.isNotEmpty ? errors.join('\n') : 'An error occurred.';
  }

  /// Get CSRF token
  Future<String?> _getCsrfToken() async {
    try {
      final response = await http.get(
        Uri.parse('http://nonabstemiously-stocky-cynthia.ngrok-free.dev/api/auth/csrf/'),
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['csrfToken'] ?? data['csrf_token'];
      }
    } catch (e) {
      print('Exception in _getCsrfToken: $e');
    }
    return null;
  }
}