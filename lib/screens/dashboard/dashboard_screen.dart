import 'package:flutter/material.dart';
import 'package:jol_app/screens/dashboard/services/game_service.dart';
import '../../constants/add_manager.dart';
import 'models/game_models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);

  final GameService _gameService = GameService();

  // Game history data
  List<Game> _gameHistory = [];
  bool _isLoadingGames = true;
  String? _gamesError;

  @override
  void initState() {
    super.initState();
    _loadGameHistory();
  }

  Future<void> _loadGameHistory() async {
    setState(() {
      _isLoadingGames = true;
      _gamesError = null;
    });

    final result = await _gameService.getGameHistory(page: 1, pageSize: 20);

    if (mounted) {
      setState(() {
        _isLoadingGames = false;
        if (result.success && result.data != null) {
          _gameHistory = result.data!.results;
          _gamesError = null;
        } else {
          _gamesError = result.error ?? 'Failed to load game history';
          _gameHistory = [];
        }
      });
    }
  }

  // Get relative time string
  String _getRelativeTime(String timestamp) {
    try {
      final gameTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(gameTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} DAY${difference.inDays > 1 ? 'S' : ''} AGO';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} HOUR${difference.inHours > 1 ? 'S' : ''} AGO';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} MIN${difference.inMinutes > 1 ? 'S' : ''} AGO';
      } else {
        return 'JUST NOW';
      }
    } catch (e) {
      return 'RECENTLY';
    }
  }

  // Format completion time from seconds to MM:SS
  String _formatTime(int? seconds) {
    if (seconds == null) return 'N/A';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}M : ${secs.toString().padLeft(2, '0')}S';
  }

  // Get status text
  String _getStatusText(Game game) {
    if (game.status == 'completed') {
      if (game.finalScore >= 70) {
        return 'YOU WON';
      } else {
        return 'COMPLETED';
      }
    } else if (game.status == 'abandoned') {
      return 'ABANDONED';
    } else {
      return 'TIMED OUT';
    }
  }

  Color _getStatusColor(Game game) {
    if (game.status == 'completed' && game.finalScore >= 70) {
      return textPink;
    } else if (game.status == 'completed') {
      return textGreen;
    } else {
      return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 25),
        child: Container(
          decoration: BoxDecoration(
            color: textPink.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                "Match History",
                style: TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 1.5,
                ),
              ),
              Expanded(
                child: _buildGameList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameList() {
    if (_isLoadingGames) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (_gamesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                _gamesError!,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Rubik',
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadGameHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: textGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_gameHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_esports_outlined,
                color: Colors.white.withOpacity(0.8),
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'NO GAMES PLAYED YET!',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Digitalt',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Start playing to see your match history here',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontFamily: 'Rubik',
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGameHistory,
      color: textPink,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _gameHistory.length,
        itemBuilder: (context, index) {
          return _buildMatchResultCard(_gameHistory[index]);
        },
      ),
    );
  }

  // 🎯 Match Result Card
  Widget _buildMatchResultCard(Game game) {
    final statusText = _getStatusText(game);
    final statusColor = _getStatusColor(game);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔝 Top Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundImage:
                AssetImage("lib/assets/images/settings_emoji.png"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'Digitalt',
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${game.gameType.toUpperCase()} • ${game.gameMode.toUpperCase()}',
                      style: const TextStyle(
                        fontFamily: 'Digitalt',
                        fontSize: 14,
                        letterSpacing: 1.1,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 🔸 Divider info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIME: ${_getRelativeTime(game.timestamp)}',
                style: const TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: textPink,
                ),
              ),
              Text(
                'GRID: ${game.gridSize}x${game.gridSize}',
                style: const TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Color(0xFFfc6839),
                ),
              ),
            ],
          ),

          const Divider(thickness: 1, height: 16),

          // 📊 Stats
          _buildStatRow("OPERATION:", game.operation.toUpperCase()),
          _buildStatRow("SCORE:", game.finalScore.toString()),
          _buildStatRow("ACCURACY:", '${game.accuracyPercentage.toStringAsFixed(1)}%'),
          _buildStatRow("HINTS USED:", game.hintsUsed.toString()),
          if (game.completionTime != null)
            _buildStatRow("TIME TAKEN:", _formatTime(game.completionTime)),
          _buildStatRow("STATUS:", game.status.toUpperCase()),
        ],
      ),
    );
  }

  // helper row builder
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Digitalt',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Digitalt',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }
}