import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jol_app/screens/play/create_room_screen.dart';
import 'package:jol_app/screens/play/game_screen/game_screen.dart';

import '../../constants/add_manager.dart';
import 'join_room_screen.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);
  static const Color textOrange = Color(0xFFfc6839);

  final AdManager _adManager = AdManager();
  bool _isShowingAd = false;

  @override
  void initState() {
    super.initState();
    _adManager.loadInterstitial(); // Preload ad
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity,
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
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Compact Title Section
                            Text(
                              "SELECT GRID SIZE",
                              style: TextStyle(
                                fontFamily: 'Digitalt',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.1),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Compact Grid Selection Cards
                            _buildCompactGridCard(
                              context,
                              gridSize: "4x4",
                              title: "BEGINNER",
                              color: textGreen,
                              isUnlocked: true,
                              icon: Icons.grid_4x4,
                            ),
                            const SizedBox(height: 10),

                            _buildCompactGridCard(
                              context,
                              gridSize: "5x5",
                              title: "INTERMEDIATE",
                              color: textOrange,
                              isUnlocked: false,
                              icon: Icons.grid_on,
                            ),
                            const SizedBox(height: 10),

                            _buildCompactGridCard(
                              context,
                              gridSize: "6x6",
                              title: "ADVANCED",
                              color: textPink,
                              isUnlocked: false,
                              icon: Icons.grid_3x3,
                            ),

                            const SizedBox(height: 20),

                            // Compact Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withOpacity(0.4),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    "MULTIPLAYER",
                                    style: TextStyle(
                                      fontFamily: 'Digitalt',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withOpacity(0.4),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Compact Multiplayer Buttons
                            _buildCompactMultiplayerButton(
                              context,
                              title: "ENTER MATCH CODE",
                              icon: Icons.login_rounded,
                              color: textBlue,
                              onTap: () => _handleJoinRoom(context),
                            ),
                            const SizedBox(height: 10),

                            _buildCompactMultiplayerButton(
                              context,
                              title: "CREATE PRIVATE TABLE",
                              icon: Icons.add_circle_outline,
                              color: textPink,
                              onTap: () => _handleCreateRoom(context),
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading Overlay to prevent double-clicks and show ad progress
          if (_isShowingAd)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REFACTORED AD & NAVIGATION LOGIC
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleJoinRoom(BuildContext context) async {
    await _showAdThenNavigate(context, const JoinRoomScreen());
  }

  Future<void> _handleCreateRoom(BuildContext context) async {
    await _showAdThenNavigate(context, const CreateRoomScreen());
  }

  Future<void> _handleStartGame(BuildContext context) async {
    await _showAdThenNavigate(context, const GameScreen());
  }

  /// Unified method to handle Ad and guaranteed navigation
  Future<void> _showAdThenNavigate(BuildContext context, Widget nextScreen) async {
    if (_isShowingAd) return;

    setState(() => _isShowingAd = true);

    try {
      // Show the ad with a timeout fallback
      await _adManager.showInterstitial().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint("Ad timed out - moving to next screen");
          return false;
        },
      );
    } catch (e) {
      debugPrint('Ad show error: $e');
    } finally {
      // Reset ad state
      if (mounted) {
        setState(() => _isShowingAd = false);
      }

      // Preload next ad
      _adManager.loadInterstitial();

      // ALWAYS navigate here, ensuring the ad session is complete
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => nextScreen),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UI BUILDING METHODS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCompactGridCard(
      BuildContext context, {
        required String gridSize,
        required String title,
        required Color color,
        required bool isUnlocked,
        required IconData icon,
      }) {
    return InkWell(
      onTap: () {
        if (isUnlocked) {
          _showConfirmDialog(context, gridSize, color);
        } else {
          _showUnlockDialog(context, gridSize);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        gridSize,
                        style: TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Digitalt',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  if (!isUnlocked) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.lock, size: 12, color: Colors.orange),
                        SizedBox(width: 4),
                        Text(
                          "TAP TO UNLOCK",
                          style: TextStyle(
                            fontFamily: 'Digitalt',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: textGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "FREE",
                  style: TextStyle(
                    fontFamily: 'Digitalt',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              )
            else
              const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMultiplayerButton(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String gridSize, Color color) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(Icons.grid_4x4, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                "START $gridSize GAME?",
                style: TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Are you sure you want to play $gridSize grid?",
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.7),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Colors.black26, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("CANCEL", style: TextStyle(fontFamily: 'Digitalt', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // 1. Close the dialog first using dialogContext
                        Navigator.pop(dialogContext);

                        // 2. Trigger the ad and navigation using the main screen's context
                        _handleStartGame(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("START", style: TextStyle(fontFamily: 'Digitalt', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnlockDialog(BuildContext context, String gridSize) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [textOrange, textPink], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                "UNLOCK $gridSize",
                style: const TextStyle(fontFamily: 'Digitalt', fontSize: 18, fontWeight: FontWeight.bold, color: textPink, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Unlock to enjoy more challenging puzzles!",
                style: TextStyle(fontFamily: 'Rubik', fontSize: 12, color: Colors.black.withOpacity(0.7), height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Colors.black26, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("CANCEL", style: TextStyle(fontFamily: 'Digitalt', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Feature coming soon!'), backgroundColor: textGreen),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: textPink,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("UNLOCK", style: TextStyle(fontFamily: 'Digitalt', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}