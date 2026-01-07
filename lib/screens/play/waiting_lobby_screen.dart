import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jol_app/screens/play/services/room_service.dart';
import 'package:share_plus/share_plus.dart';
import 'models/room_models.dart';
import 'multiplayer_game_screen.dart';

class WaitingLobbyScreen extends StatefulWidget {
  final String roomCode;
  final String playerId;
  final String playerName;

  const WaitingLobbyScreen({
    super.key,
    required this.roomCode,
    required this.playerId,
    required this.playerName,
  });

  @override
  State<WaitingLobbyScreen> createState() => _WaitingLobbyScreenState();
}

class _WaitingLobbyScreenState extends State<WaitingLobbyScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);

  final RoomService _roomService = RoomService();
  Room? _room;
  bool _isLoading = true;
  StreamSubscription<Room?>? _roomSubscription;

  @override
  void initState() {
    super.initState();
    _listenToRoom();
  }

  void _listenToRoom() {
    _roomSubscription = _roomService.listenToRoom(widget.roomCode).listen(
          (room) {
        if (!mounted) return; // 👈 Prevents setState after dispose
        setState(() {
          _room = room;
          _isLoading = false;
        });

        if (room.gameState.status == 'playing') {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MultiplayerGameScreen(
                roomCode: widget.roomCode,
                playerId: widget.playerId,
              ),
            ),
          );
        }

        if (room.gameState.status == 'abandoned') {
          if (mounted) _showAbandonedDialog();
        }
      },
      onError: (error) async {
        // 🧹 Try to clean up the room safely
        try {
          final exists = await _roomService.roomExists(widget.roomCode);
          if (exists) {
            await _roomService.cleanupRoom(widget.roomCode);
          }
        } catch (_) {
          // ignore cleanup errors
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Room error: $error')),
          );
          Navigator.pop(context);
        }
      },
    );
  }

  void _showAbandonedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Room Closed'),
        content: const Text('The host has left the room.'),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReady() async {
    final currentPlayer = _room!.players[widget.playerId];
    if (currentPlayer == null) return;

    await _roomService.togglePlayerReady(
      widget.roomCode,
      widget.playerId,
      !currentPlayer.isReady,
    );
  }

  Future<void> _startGame() async {
    await _roomService.startGame(widget.roomCode);
  }

  Future<void> _leaveRoom() async {
    if (_room == null) return;

    final isHost = _room!.gameState.hostId == widget.playerId;
    await _roomService.leaveRoom(widget.roomCode, widget.playerId);

    if (isHost) {
      await _roomService.cleanupRoom(widget.roomCode);
    } else {
      await _roomService.removePlayer(widget.roomCode, widget.playerId);
      final exists = await _roomService.roomExists(widget.roomCode);
      if (exists) {
        final remaining = await _roomService.getPlayerCount(widget.roomCode);
        if (remaining == 0) {
          await _roomService.cleanupRoom(widget.roomCode);
        }
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmLeaveRoom() async {
    final isHost = _room?.gameState.hostId == widget.playerId;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room?'),
        content: Text(
          isHost
              ? 'You are the host. Leaving will delete this room for everyone. Are you sure you want to exit?'
              : 'Are you sure you want to leave this room?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await _leaveRoom();
    }
  }

  void _shareRoomCode() {
    Share.share(
      'Join my Jaloo Puzzle game_screen!\nRoom Code: ${widget.roomCode}',
      subject: 'Join Jaloo Puzzle Game',
    );
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room code copied!')),
      );
    }
  }

  Color _getPlayerColor(int index) {
    const colors = [Colors.purple, Colors.blue, Colors.green, Colors.orange];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    _roomSubscription?.cancel(); // 👈 Proper cleanup
    super.dispose();
  }

  // 👇 replace your build() method body with this one
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isHost = _room?.gameState.hostId == widget.playerId;
    final canStart = isHost && (_room?.canStart ?? false);

    return WillPopScope(
      onWillPop: () async {
        await _confirmLeaveRoom();
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
                // 🧩 Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _confirmLeaveRoom,
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
                        "Lobby",
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

                const SizedBox(height: 12),

                // 🔹 Room Code Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Room Code",
                              style: TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.roomCode,
                              style: const TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: textBlue,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, color: textBlue),
                              onPressed: _copyRoomCode,
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: textPink),
                              onPressed: _shareRoomCode,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 Room Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: textPink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Grid: ${_room?.settings.gridSize ?? 4}x${_room?.settings.gridSize ?? 4}",
                              style: const TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Mode: ${_room?.settings.mode ?? 'untimed'}",
                              style: const TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Operation: ${_room?.settings.operation ?? 'addition'}",
                              style: const TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Players: ${_room?.playerCount ?? 0}/${_room?.settings.maxPlayers ?? 4}",
                              style: const TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 Player List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _room?.players.length ?? 0,
                    itemBuilder: (context, index) {
                      final player = _room!.players.values.elementAt(index);
                      final isCurrentPlayer = player.id == widget.playerId;
                      final isHostPlayer = player.id == _room!.gameState.hostId;

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
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: _getPlayerColor(index),
                              child: Text(
                                player.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
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
                                      if (isHostPlayer)
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            "HOST",
                                            style: TextStyle(
                                              fontFamily: "Rubik",
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    player.isReady ? "Ready ✓" : "Not Ready",
                                    style: TextStyle(
                                      fontFamily: "Rubik",
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: player.isReady ? textGreen : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (player.isReady)
                              const Icon(Icons.check_circle, color: textGreen, size: 28),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 🔹 Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      if (!isHost)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _room?.players[widget.playerId]?.isReady == true
                                  ? Colors.orange
                                  : textGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _toggleReady,
                            child: Text(
                              _room?.players[widget.playerId]?.isReady == true
                                  ? "Not Ready"
                                  : "I'm Ready",
                              style: const TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (isHost) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canStart ? textPink : Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: canStart ? _startGame : null,
                            child: Text(
                              canStart
                                  ? "Begin Match Now"
                                  : "Waiting for players to be ready...",
                              style: const TextStyle(
                                fontFamily: "Rubik",
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Minimum 2 players required",
                          style: TextStyle(
                            fontFamily: "Rubik",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
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
