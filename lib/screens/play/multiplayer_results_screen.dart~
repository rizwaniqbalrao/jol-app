import 'package:flutter/material.dart';
import 'package:jol_app/screens/play/services/room_service.dart';
import 'models/room_models.dart';

class MultiplayerResultsScreen extends StatefulWidget {
  final String roomCode;
  final String playerId;

  const MultiplayerResultsScreen({
    super.key,
    required this.roomCode,
    required this.playerId,
  });

  @override
  State<MultiplayerResultsScreen> createState() => _MultiplayerResultsScreenState();
}

class _MultiplayerResultsScreenState extends State<MultiplayerResultsScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);

  final RoomService _roomService = RoomService();
  Room? _room;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    _roomService.listenToRoom(widget.roomCode).listen((room) {
      if (mounted) {
        setState(() {
          _room = room;
          _isLoading = false;
        });
      }
    });
  }

  List<Player> _getSortedPlayers() {
    if (_room == null) return [];
    final players = _room!.players.values.toList();
    players.sort((a, b) => b.score.compareTo(a.score));
    return players;
  }

  Color _getPlayerColor(int index) {
    const colors = [Colors.purple, Colors.blue, Colors.green, Colors.orange];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _room == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sortedPlayers = _getSortedPlayers();
    final winner = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
    final isWinner = winner?.id == widget.playerId;

    return WillPopScope(
      onWillPop: () async {
        Navigator.popUntil(context, (route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFC0CB),
                Color(0xFFADD8E6),
                Color(0xFFE6E6FA),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: textPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Game Results",
                        style: TextStyle(
                          fontFamily: "Rubik",
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Winner Announcement
                if (winner != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade300,
                          Colors.amber.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          size: 60,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isWinner ? "🎉 You Won! 🎉" : "Winner",
                          style: TextStyle(
                            fontFamily: "Rubik",
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!isWinner)
                          Text(
                            winner.name,
                            style: const TextStyle(
                              fontFamily: "Rubik",
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          "Score: ${winner.score}",
                          style: TextStyle(
                            fontFamily: "Rubik",
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
                // Final Leaderboard
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Final Standings",
                    style: TextStyle(
                      fontFamily: "Rubik",
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sortedPlayers.length,
                    itemBuilder: (context, index) {
                      final player = sortedPlayers[index];
                      final isCurrentPlayer = player.id == widget.playerId;
                      final rank = index + 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrentPlayer ? textPink : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Rank
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: rank == 1
                                    ? Colors.amber
                                    : rank == 2
                                    ? Colors.grey.shade400
                                    : rank == 3
                                    ? Colors.brown
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '#$rank',
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Avatar
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: _getPlayerColor(index),
                              child: Text(
                                player.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: "Rubik",
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Player Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontFamily: "Rubik",
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Score: ${player.score}",
                                    style: TextStyle(
                                      fontFamily: "Rubik",
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentPlayer ? textPink : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Trophy for winner
                            if (rank == 1)
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 28,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: textPink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // Navigate back to home or room creation screen
                            Navigator.popUntil(context, (route) => route.isFirst);
                          },
                          child: const Text(
                            "Play Again",
                            style: TextStyle(
                              fontFamily: "Rubik",
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            Navigator.popUntil(context, (route) => route.isFirst);
                          },
                          child: const Text(
                            "Back to Home",
                            style: TextStyle(
                              fontFamily: "Rubik",
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}