import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jol_app/screens/dashboard/dashboard_screen.dart';
import 'package:jol_app/screens/dashboard/notification_screen.dart';
import 'package:jol_app/screens/score%20board/score_board_screen.dart';
import 'package:jol_app/screens/settings/account_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../Affiliates/affiliates_screen.dart';
import '../group/group_screen.dart';
import '../play/paly_screen.dart';
import '../settings/services/user_profile_services.dart';
import '../auth/models/user.dart';
import '../auth/models/user_wallet.dart';
import '../auth/services/wallet_service.dart';
import '../onboarding/onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);

  int _selectedIndex = 0;

  final UserProfileService _profileService = UserProfileService();
  final WalletService _walletService = WalletService();

  // Static cache to persist across screen instances
  static UserProfile? _cachedProfile;
  static bool _hasLoadedOnce = false;

  // Wallet cache
  static Wallet? _cachedWallet;
  static bool _hasLoadedWalletOnce = false;

  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  Wallet? _wallet;
  bool _isLoadingWallet = true;

  // Store user details for GroupController
  String? _userId;
  String? _userName;

  // Update screens to use the wrapper for GroupsScreen
  List<Widget> get _screens {
    return [
      DashboardScreen(),
      AffiliatesScreen(),
      PlayScreen(),
      // Use the wrapper for GroupsScreen if we have user data
      _buildGroupsScreen(),
      ScoreBoardScreen(),
    ];
  }

  Widget _buildGroupsScreen() {
    // If we have user data, use the wrapper. Otherwise, show loading/error.
    if (_userId != null && _userName != null) {
      return GroupsScreenWrapper(
        userId: _userId!,
        userName: _userName!,
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading user data...'),
          ],
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadWallet();
  }

  Future<void> _loadUserProfile() async {
    // Check if we already have cached data
    if (_hasLoadedOnce && _cachedProfile != null && _userId != null && _userName != null) {
      setState(() {
        _userProfile = _cachedProfile;
        _isLoadingProfile = false;
      });
      return;
    }

    try {
      // Fetch both user details and profile in parallel
      final userDetailResult = await _profileService.getUserDetail();
      final profileResult = await _profileService.getUserProfile();

      if (mounted) {
        setState(() {
          _isLoadingProfile = false;

          if (userDetailResult.success && userDetailResult.user != null) {
            _userId = userDetailResult.user!.id.toString();
            _userName = userDetailResult.user!.username;
          }

          if (profileResult.success && profileResult.profile != null) {
            _userProfile = profileResult.profile;
            _cachedProfile = profileResult.profile;
          }

          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadWallet() async {
    // Check if we already have cached wallet data
    if (_hasLoadedWalletOnce && _cachedWallet != null) {
      setState(() {
        _wallet = _cachedWallet;
        _isLoadingWallet = false;
      });
      return;
    }

    try {
      final walletResult = await _walletService.getWallet();

      if (mounted) {
        setState(() {
          _isLoadingWallet = false;

          if (walletResult.success && walletResult.data != null) {
            _wallet = walletResult.data;
            _cachedWallet = walletResult.data;
            _hasLoadedWalletOnce = true;
          } else {
            // Handle error silently or show a snackbar
            print('Error loading wallet: ${walletResult.error}');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWallet = false;
        });
        print('Exception loading wallet: $e');
      }
    }
  }

  // Call this method when profile is updated
  static void refreshCache() {
    _hasLoadedOnce = false;
    _cachedProfile = null;
  }

  // Call this method when wallet is updated (e.g., after redeeming coins)
  static void refreshWalletCache() {
    _hasLoadedWalletOnce = false;
    _cachedWallet = null;
  }

  // Public method to refresh wallet data
  Future<void> refreshWallet() async {
    refreshWalletCache();
    await _loadWallet();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Format coins for display (e.g., 1500 -> "1.5K", 1500000 -> "1.5M")
  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 1000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    } else {
      return coins.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: Container(
        // Gradient background
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
              // 📌 Unified App Bar
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 6,
                  left: 12,
                  right: 12,
                  bottom: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔠 JOL Logo
                    _buildJolLogo(),

                    Row(
                      children: [
                        // ✅ HOW TO PLAY (pill button)
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const HelpDialog(),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: textGreen,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.9),
                                  width: 2.5),
                            ),
                            child: const Text(
                              "HOW TO PLAY",
                              style: TextStyle(
                                fontFamily: 'Digitalt',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 🔔 Notification Bell
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications,
                              size: 20,
                              color: textPink,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 💰 Coins (Updated with real data)
                        _buildCoinsDisplay(),

                        const SizedBox(width: 8),

                        // 👤 Profile Avatar
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AccountScreen(),
                              ),
                            );
                          },
                          child: _buildProfileAvatar(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 📱 Screen Content
              Expanded(
                child: _screens[_selectedIndex],
              ),
            ],
          ),
        ),
      ),

      // Bottom Navigation with Play Button
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem("History", MdiIcons.history, 0),
                _navItem("Affiliates", MdiIcons.podium, 1),
                const SizedBox(width: 60), // Space for center button
                _navItem("Group", MdiIcons.accountGroupOutline, 3),
                _navItem("Scores", MdiIcons.scoreboardOutline, 4),
              ],
            ),
          ),

          // Floating Play Button
          Positioned(
            top: -25,
            child: GestureDetector(
              onTap: () => _onItemTapped(2),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    height: 62,
                    width: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFE6F0),
                    ),
                    child: Center(
                      child: Icon(
                        _selectedIndex == 2 ? MdiIcons.play : MdiIcons.playOutline,
                        size: 38,
                        color: const Color(0xFFF82A87),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String label, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? const Color(0xFFF82A87) : Colors.black54,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: 10,
              fontWeight: FontWeight.w400,
              height: 1.0,
              color: isSelected ? const Color(0xFFF82A87) : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // 💰 Build Coins Display Widget (Updated with real data)
  Widget _buildCoinsDisplay() {
    // If still loading, show loading indicator
    if (_isLoadingWallet) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          color: textPink,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textPink),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "...",
              style: TextStyle(
                fontFamily: 'Digitalt',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }

    // Display real coin data
    final availableCoins = _wallet?.availableCoins ?? 0;
    final formattedCoins = _formatCoins(availableCoins);

    return GestureDetector(
      onTap: () async {
        // Refresh wallet on tap
        await refreshWallet();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          color: textPink,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            // Circle with "J"
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  "J",
                  style: TextStyle(
                    fontFamily: 'Digitalt',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPink,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                formattedCoins,
                style: const TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 👤 Build Profile Avatar Widget
  Widget _buildProfileAvatar() {
    // If still loading, show a placeholder
    if (_isLoadingProfile) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(textPink),
          ),
        ),
      );
    }

    // Check if user has an avatar URL
    final avatarUrl = _userProfile?.avatar;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Use network image if avatar exists
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: DecorationImage(
            image: NetworkImage(avatarUrl),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              print('Error loading avatar: $exception');
            },
          ),
        ),
      );
    } else {
      // Fall back to static emoji image
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          image: const DecorationImage(
            image: AssetImage("lib/assets/images/settings_emoji.png"),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  // 🔠 JOL logo builder
  Widget _buildJolLogo() {
    const letters = ["J", "O", "L"];
    const colors = [Color(0xFFf8bc64), textPink, Color(0xFFfc6839)];

    return Row(
      children: List.generate(
        letters.length,
            (index) => Text(
          letters[index],
          style: const TextStyle(
            fontFamily: 'Digitalt',
            fontWeight: FontWeight.w500,
            fontSize: 35,
            height: 0.82,
          ).copyWith(
            color: colors[index],
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}