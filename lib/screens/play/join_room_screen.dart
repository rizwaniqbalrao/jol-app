// join_room_screen.dart
import 'package:flutter/material.dart';
import 'package:jol_app/screens/play/services/room_service.dart';
import 'package:uuid/uuid.dart';
import 'waiting_lobby_screen.dart';

class JoinRoomScreen extends StatefulWidget {

  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textPink = Color(0xFFF82A87);

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final RoomService _roomService = RoomService();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _codeController.text = '';
    _nameController.text = '';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final roomCode = _codeController.text.trim().toUpperCase();
    final playerName = _nameController.text.trim();

    if (roomCode.isEmpty || playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter room code and name')),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      final playerId = const Uuid().v4();
      await _roomService.joinRoom(
        roomCode: roomCode,
        playerId: playerId,
        playerName: playerName,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingLobbyScreen(
              roomCode: roomCode,
              playerId: playerId,
              playerName: playerName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');
        
        // Map specific exceptions to more user-friendly messages
        if (errorMessage.contains('Room not found')) {
          errorMessage = "The code you entered is incorrect. To join a room, someone else must create a room first.";
        } else if (errorMessage.contains('Room is full')) {
          errorMessage = "This room is already full. You cannot join.";
        } else if (errorMessage.contains('Game already started')) {
          errorMessage = "This game has already started. You cannot join.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
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
                          "Join Private Room",
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
                  const SizedBox(height: 40),
                  const Text(
                    "Room Code",
                    style: TextStyle(
                      fontFamily: "Rubik",
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: "Enter 6-character code",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Your Name",
                    style: TextStyle(
                      fontFamily: "Rubik",
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "Enter your name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
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
                      onPressed: _isJoining ? null : _joinRoom,
                      child: _isJoining
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        "Join Room",
                        style: TextStyle(
                          fontFamily: "Rubik",
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}