// File: services/wallet_service.dart

import 'dart:convert';
import 'package:jol_app/screens/auth/models/user_wallet.dart';
import '../../auth/services/secure_storage_service.dart';
import 'api_client.dart'; // Import the new ApiClient

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

      // ✅ Use ApiClient - it handles 401 automatically
      final response = await ApiClient.get('/v1/user/wallet/');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final wallet = Wallet.fromJson(data);
        return WalletResult(success: true, data: wallet);
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

      final request = AdjustCoinsRequest(coins: coins, type: type);
      final body = request.toJson();

      print('POST Adjust Coins - Body: ${jsonEncode(body)}');

      // ✅ Use ApiClient - it handles 401 automatically
      final response = await ApiClient.post(
        '/v1/user/wallet/adjust/',
        body: body,
      );

      print('POST Adjust Coins - Status: ${response.statusCode}');
      print('POST Adjust Coins - Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final adjustResponse = AdjustCoinsResponse.fromJson(data);
        return AdjustCoinsResult(success: true, data: adjustResponse);
      } else if (response.statusCode == 400) {
        String errorMsg = 'Unable to adjust coins.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
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

  /// Convert earned game_screen points into coins
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

      final request = RedeemRequest(coins: coins);
      final body = request.toJson();

      print('POST Redeem - Body: ${jsonEncode(body)}');
      print('POST Redeem - Points needed: ${coins * COIN_VALUE}');

      // ✅ Use ApiClient - it handles 401 automatically
      var response = await ApiClient.post(
        '/v1/user/wallet/redeem/',
        body: body,
      );

      print('POST Redeem - Status: ${response.statusCode}');
      print('POST Redeem - Response: ${response.body}');

      // Handle 307 redirect if needed
      if (response.statusCode == 307 || response.statusCode == 308) {
        final redirectUrl = response.headers['location'];
        print('POST Redeem - Following redirect to: $redirectUrl');

        if (redirectUrl != null) {
          response = await ApiClient.post(
            redirectUrl.replaceFirst(ApiClient.baseUrl, ''),
            body: body,
          );
          print('POST Redeem (after redirect) - Status: ${response.statusCode}');
          print('POST Redeem (after redirect) - Response: ${response.body}');
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final redeemResponse = RedeemResponse.fromJson(data);
        return RedeemResult(success: true, data: redeemResponse);
      } else if (response.statusCode == 400) {
        String errorMsg = 'Unable to redeem coins.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
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
}