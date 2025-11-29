// File: models/wallet_models.dart

/// Wallet balance information
class Wallet {
  final int totalCoins;
  final int usedCoins;
  final int availableCoins;

  Wallet({
    required this.totalCoins,
    required this.usedCoins,
    required this.availableCoins,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      totalCoins: json['total_coins'] as int? ?? 0,
      usedCoins: json['used_coins'] as int? ?? 0,
      availableCoins: json['available_coins'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_coins': totalCoins,
      'used_coins': usedCoins,
      'available_coins': availableCoins,
    };
  }

  @override
  String toString() {
    return 'Wallet(total: $totalCoins, used: $usedCoins, available: $availableCoins)';
  }
}

/// Response for coin adjustment (admin/test only)
class AdjustCoinsResponse {
  final String message;

  AdjustCoinsResponse({
    required this.message,
  });

  factory AdjustCoinsResponse.fromJson(Map<String, dynamic> json) {
    return AdjustCoinsResponse(
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
    };
  }

  @override
  String toString() {
    return 'AdjustCoinsResponse(message: $message)';
  }
}

/// Request body for coin adjustment
class AdjustCoinsRequest {
  final int coins;
  final String type; // "increment" or "decrement"

  AdjustCoinsRequest({
    required this.coins,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'coins': coins,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'AdjustCoinsRequest(coins: $coins, type: $type)';
  }
}

/// Response for redeeming game points to coins
class RedeemResponse {
  final int coinsAwarded;
  final int availableGamePoints;
  final int availableCoins;

  RedeemResponse({
    required this.coinsAwarded,
    required this.availableGamePoints,
    required this.availableCoins,
  });

  factory RedeemResponse.fromJson(Map<String, dynamic> json) {
    return RedeemResponse(
      coinsAwarded: json['coins_awarded'] as int? ?? 0,
      availableGamePoints: json['available_game_points'] as int? ?? 0,
      availableCoins: json['available_coins'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coins_awarded': coinsAwarded,
      'available_game_points': availableGamePoints,
      'available_coins': availableCoins,
    };
  }

  @override
  String toString() {
    return 'RedeemResponse(awarded: $coinsAwarded, gamePoints: $availableGamePoints, coins: $availableCoins)';
  }
}

/// Request body for redeeming coins
class RedeemRequest {
  final int coins;

  RedeemRequest({
    required this.coins,
  });

  Map<String, dynamic> toJson() {
    return {
      'coins': coins,
    };
  }

  @override
  String toString() {
    return 'RedeemRequest(coins: $coins)';
  }
}