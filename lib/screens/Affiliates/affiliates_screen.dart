import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jol_app/screens/dashboard/notification_screen.dart';

import '../auth/models/user.dart';
import '../onboarding/onboarding_screen.dart';
import '../settings/account_screen.dart';
import '../settings/services/user_profile_services.dart';


class AffiliatesScreen extends StatefulWidget {
  const AffiliatesScreen({super.key});

  @override
  State<AffiliatesScreen> createState() => _AffiliatesScreenState();
}

class _AffiliatesScreenState extends State<AffiliatesScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);

  final UserProfileService _profileService = UserProfileService();

  // Static cache to persist across screen instances
  static UserProfile? _cachedProfile;
  static bool _hasLoadedOnce = false;

  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    // Check if we already have cached profile
    if (_hasLoadedOnce && _cachedProfile != null) {
      setState(() {
        _userProfile = _cachedProfile;
        _isLoadingProfile = false;
      });
      return;
    }

    // Fetch from API only if not cached
    final result = await _profileService.getUserProfile();
    if (mounted) {
      setState(() {
        _isLoadingProfile = false;
        if (result.success) {
          _userProfile = result.profile;
          // Cache the profile
          _cachedProfile = result.profile;
          _hasLoadedOnce = true;
        }
      });
    }
  }

  // Call this method when profile is updated
  static void refreshCache() {
    _hasLoadedOnce = false;
    _cachedProfile = null;
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
        // 📌 Gradient background (same as PlayScreen)
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
              _buildAppBar(context),

              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF4CA1), // pink header
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      /// 🔖 Pink Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: const Text(
                          "AFFILIATES",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Digitalt',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 240,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                            ),
                            child: Column(
                              children: [
                                /// 🚫 No Affiliates Found text
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                                  child: Text(
                                    "NO AFFILIATES FOUND RIGHT NOW",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Digitalt',
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE6005C), // dark pink
                                    ),
                                  ),
                                ),

                                /// Divider
                                Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                  indent: 20,
                                  endIndent: 20,
                                ),

                                const SizedBox(height: 12),

                                /// 📢 Invite Info
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    "Invite affiliates and earn 10% commission by clicking the button below",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Rubik',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: textPink,
                                      height: 1.4,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                /// 🔘 Custom Invite Button
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: InviteAffiliatesButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => const InviteAffiliateDialog(),
                                      );
                                    },

                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 👤 Build Profile Avatar Widget
  Widget _buildProfileAvatar() {
    // If still loading, show a placeholder
    if (_isLoadingProfile) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textPink),
        ),
      );
    }

    // Check if user has an avatar URL
    final avatarUrl = _userProfile?.avatar;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Use network image if avatar exists
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // If network image fails to load, it will show the default
          print('Error loading avatar: $exception');
        },
        child: Container(), // Empty container as child
      );
    } else {
      // Fall back to static emoji image
      return const CircleAvatar(
        radius: 18,
        backgroundImage: AssetImage("lib/assets/images/settings_emoji.png"),
      );
    }
  }

  /// 🔠 JOL Logo
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

  /// 📌 App Bar (copied from PlayScreen)
  Widget _buildAppBar(BuildContext context) {
    return Container(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: textGreen,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 2.5,
                    ),
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
                    MaterialPageRoute(builder: (context) => NotificationScreen()),
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

              // 💰 Coins
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        "5M",
                        style: TextStyle(
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
              const SizedBox(width: 8),

              // 👤 Profile Avatar - UPDATED WITH DYNAMIC IMAGE
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
    );
  }
}

/// 🎨 Custom Gradient Invite Button
class InviteAffiliatesButton extends StatelessWidget {
  final VoidCallback onPressed;

  const InviteAffiliatesButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B3CFF), Color(0xFFFF4CA1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        ),
        onPressed: onPressed,
        child: const Text(
          "INVITE AFFILIATE",
          style: TextStyle(
            fontFamily: 'Digitalt',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 📌 Invite Affiliate Dialog
class InviteAffiliateDialog extends StatelessWidget {
  const InviteAffiliateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// 🧑 Avatar floating on top
            Align(
              alignment: Alignment.topCenter,
              child: CircleAvatar(
                radius: 28,
                backgroundImage: const AssetImage("lib/assets/images/settings_emoji.png"),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Invite Affiliate",
              style: TextStyle(
                fontFamily: "Rubik",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFfc6839),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: const Text(
                "REFER & GET 10% COMMISSION",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Digitalt",
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE6005C), // dark pink
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "Invite your friend to get 10% commission. "
                  "You receive a 10% off coupon after their first purchase.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFF82A87),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            /// 🔗 Input + Copy button
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      "https://james23ajol",
                      style: TextStyle(
                        fontFamily: "Rubik",
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B3CFF), Color(0xFFFF4CA1)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: () {
                      // TODO: Copy link logic
                    },
                    child: const Text(
                      "COPY LINK",
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// 🌍 Social Icons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Image.asset("lib/assets/images/google.png", height: 28),
                Image.asset("lib/assets/images/apple.png", height: 28),
                Icon(Icons.facebook, size: 28),
              ],
            ),
          ],
        ),
      ),
    );
  }
}