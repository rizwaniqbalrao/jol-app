import 'package:flutter/material.dart';
import 'package:jol_app/screens/settings/edit_profile_screen.dart';
import 'package:jol_app/screens/settings/services/user_profile_services.dart';
import 'package:shimmer/shimmer.dart';
import '../auth/models/user.dart';
import 'choose_color_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // ──────────────────────────────────────────────────────────────
  // Colours
  // ──────────────────────────────────────────────────────────────
  static const Color textPink = Color(0xFFF82A87);
  static const Color textGreen = Color(0xFF4CAF50);
  static const Color accentPurple = Color(0xFF9B4BFF);

  // ──────────────────────────────────────────────────────────────
  // Controllers & Service
  // ──────────────────────────────────────────────────────────────
  final TextEditingController _couponController = TextEditingController();
  final UserProfileService _profileService = UserProfileService();

  // ──────────────────────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;
  UserProfile? _profile;
  User? _userData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // Load profile AND user data from separate endpoints
  // ──────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final profileResult = await _profileService.getUserProfile();
    final userResult = await _profileService.getUserDetail();

    if (profileResult.success && profileResult.profile != null) {
      setState(() {
        _profile = profileResult.profile;
        _userData = userResult.user;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = profileResult.error ?? 'Failed to load profile';
        _isLoading = false;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────
  User? get _user => _userData;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _sectionCard({required Widget child, double vertical = 8}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: vertical),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: child,
    );
  }

  Widget _headerRow(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Digitalt',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPink,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Shimmer Widgets
  // ──────────────────────────────────────────────────────────────
  Widget _shimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _shimmerCircle(double radius) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // UI Cards (data-driven with shimmer)
  // ──────────────────────────────────────────────────────────────
  Widget _myCoinsCard() {
    if (_isLoading) {
      return _sectionCard(
        child: Column(
          children: [
            _headerRow("My Coins"),
            const Divider(height: 1, color: Colors.black12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  _shimmerCoinRow(),
                  const SizedBox(height: 8),
                  _shimmerCoinRow(),
                  const SizedBox(height: 8),
                  _shimmerCoinRow(),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    final wallet = _profile?.wallet;
    final total = wallet?.totalCoins ?? 0;
    final used = wallet?.usedCoins ?? 0;
    final available = wallet?.availableCoins ?? 0;

    return _sectionCard(
      child: Column(
        children: [
          _headerRow("My Coins"),
          const Divider(height: 1, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              children: [
                _coinRow("TOTAL COINS:", total.toString(), accentPurple),
                const SizedBox(height: 8),
                _coinRow("USED COINS:", used.toString(), accentPurple),
                const SizedBox(height: 8),
                _coinRow("AVAILABLE COINS:", available.toString(), textGreen),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _shimmerCoinRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _shimmerBox(width: 120, height: 16),
        _shimmerBox(width: 60, height: 18),
      ],
    );
  }

  Widget _coinRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Digitalt', fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(value, style: TextStyle(fontFamily: 'Digitalt', fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _referralCard() {
    if (_isLoading) {
      return _sectionCard(
        child: Column(
          children: [
            _headerRow("Referral"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentPurple.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_membership_outlined, color: accentPurple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "YOUR REFERRAL ID",
                                style: TextStyle(fontFamily: 'Digitalt', fontSize: 12, fontWeight: FontWeight.bold, color: textPink),
                              ),
                              const SizedBox(height: 4),
                              _shimmerBox(width: 150, height: 18),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: accentPurple.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.copy, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: textGreen.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, color: textGreen),
                        const SizedBox(width: 12),
                        const Text(
                          "TOTAL REFERRALS:",
                          style: TextStyle(fontFamily: 'Digitalt', fontSize: 14, fontWeight: FontWeight.bold, color: textPink),
                        ),
                        const Spacer(),
                        _shimmerBox(width: 40, height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    }

    final referral = _profile?.referralCode ?? '';
    final totalRefs = _profile?.totalReferrals ?? 0;

    return _sectionCard(
      child: Column(
        children: [
          _headerRow("Referral"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentPurple.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_membership_outlined, color: accentPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "YOUR REFERRAL ID",
                              style: TextStyle(fontFamily: 'Digitalt', fontSize: 12, fontWeight: FontWeight.bold, color: textPink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              referral,
                              style: const TextStyle(fontFamily: 'Digitalt', fontSize: 18, fontWeight: FontWeight.bold, color: accentPurple),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _showSnack('Referral ID copied!'),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: accentPurple, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.copy, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: textGreen.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, color: textGreen),
                      const SizedBox(width: 12),
                      const Text(
                        "TOTAL REFERRALS:",
                        style: TextStyle(fontFamily: 'Digitalt', fontSize: 14, fontWeight: FontWeight.bold, color: textPink),
                      ),
                      const Spacer(),
                      Text(
                        totalRefs.toString(),
                        style: const TextStyle(fontFamily: 'Digitalt', fontSize: 18, fontWeight: FontWeight.bold, color: textGreen),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _profileInfoCard() {
    if (_isLoading) {
      return _sectionCard(
        child: Column(
          children: [
            _headerRow(
              "Profile Info",
              trailing: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: textPink.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(Icons.edit, color: Colors.white, size: 18)),
              ),
            ),
            const SizedBox(height: 6),
            _shimmerInfoRow(),
            _shimmerInfoRow(),
            _shimmerInfoRow(),
            _shimmerInfoRow(),
            _shimmerInfoRow(),
            _shimmerInfoRow(),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    final fullName = [_user?.firstName ?? '', _user?.lastName ?? ''].where((e) => e.isNotEmpty).join(' ');
    final username = _user?.username ?? '';
    final email = _user?.email ?? '';
    final bio = _profile?.bio ?? '';
    final location = _profile?.location ?? '';
    final birthDate = _profile?.birthDate;

    return _sectionCard(
      child: Column(
        children: [
          _headerRow(
            "Profile Info",
            trailing: InkWell(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (result == true) {
                  _loadProfile();
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: textPink, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(Icons.edit, color: Colors.white, size: 18)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _infoRow(Icons.person_outline, fullName.isEmpty ? '—' : fullName, label: 'Full Name'),
          _infoRow(Icons.alternate_email, username.isEmpty ? '—' : username, label: 'Username'),
          _infoRow(Icons.email_outlined, email.isEmpty ? '—' : email, label: 'Email'),
          _infoRow(Icons.description_outlined, bio.isEmpty ? '—' : bio, label: 'Bio'),
          _infoRow(Icons.location_on_outlined, location.isEmpty ? '—' : location, label: 'Location'),
          _infoRow(
            Icons.cake_outlined,
            birthDate != null ? '${birthDate.day}/${birthDate.month}/${birthDate.year}' : '—',
            label: 'Birth Date',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _shimmerInfoRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentPurple.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, color: accentPurple.withOpacity(0.3)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(width: 80, height: 11),
                const SizedBox(height: 4),
                _shimmerBox(width: double.infinity, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String value, {String? label}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentPurple.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Digitalt',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textPink,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Digitalt',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accentPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coloursCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(
            "Colours",
            trailing: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChooseColorScreen())),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: textPink, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(Icons.edit, color: Colors.white, size: 18)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              "CURRENT COLOR: PINK",
              style: TextStyle(fontFamily: 'Digitalt', fontSize: 18, fontWeight: FontWeight.bold, color: accentPurple),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Main build
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFC0CB), Color(0xFFADD8E6), Color(0xFFE6E6FA)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildAppBar(context),
              const SizedBox(height: 12),

              // Big pink profile card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: textPink, borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  child: Column(
                    children: [
                      // Avatar + edit
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _isLoading
                              ? _shimmerCircle(44)
                              : CircleAvatar(
                            radius: 44,
                            backgroundImage: _profile?.avatar != null
                                ? NetworkImage(
                              _profile!.avatar!.startsWith('http')
                                  ? _profile!.avatar!
                                  : 'https://nonabstemiously-stocky-cynthia.ngrok-free.dev${_profile!.avatar}',
                            )
                                : const AssetImage("lib/assets/images/settings_emoji.png") as ImageProvider,
                          ),
                          Positioned(
                            right: -2,
                            top: -6,
                            child: InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                                );
                                if (result == true) {
                                  _loadProfile();
                                }
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                                ),
                                child: const Center(child: Icon(Icons.edit, size: 18, color: textPink)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Username
                      _isLoading
                          ? _shimmerBox(width: 150, height: 20, borderRadius: 4)
                          : Text(
                        _user?.username ?? '',
                        style: const TextStyle(fontFamily: 'Rubik', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),

                      // Email
                      _isLoading
                          ? _shimmerBox(width: 200, height: 14, borderRadius: 4)
                          : Text(
                        _user?.email ?? '',
                        style: const TextStyle(fontFamily: 'Rubik', fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 20),

                      // Error handling
                      if (_error != null)
                        Center(
                          child: Column(
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.white)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: textPink,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _myCoinsCard(),
                        _referralCard(),
                        _profileInfoCard(),
                        _coloursCard(),
                        const Padding(
                          padding: EdgeInsets.only(top: 12.0),
                          child: Text(
                            "CLICK THE EDIT ICON TO CHANGE COLOUR AND YOU'LL BE CHARGED FOR CHANGING COLOUR",
                            style: TextStyle(fontFamily: 'Digitalt', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // AppBar
  // ──────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6, left: 12, right: 12, bottom: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: textPink, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14),
              ),
            ),
            const Spacer(),
            const Text(
              "Profile",
              style: TextStyle(fontFamily: "Rubik", fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}