import 'package:flutter/material.dart';
import 'package:jol_app/screens/score%20board/services/leadboard_services.dart';
import 'models/leadboard_entry.dart';

class ScoreBoardScreen extends StatefulWidget {
  const ScoreBoardScreen({super.key});

  @override
  State<ScoreBoardScreen> createState() => _ScoreBoardScreenState();
}

class _ScoreBoardScreenState extends State<ScoreBoardScreen> {
  static const Color textPink = Color(0xFFF82A87);
  static const Color textOrange = Color(0xFFfc6839);
  static const Color textGreen = Color(0xFF4CAF50);

  int selectedTab = 0;
  final LeaderboardService _leaderboardService = LeaderboardService();

  // API data
  bool isLoading = false;
  List<LeaderboardEntry> leaderboardData = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  // Map tab index to API period
  String _getPeriodFromTab(int tab) {
    switch (tab) {
      case 0:
        return 'this_week';
      case 1:
        return 'today';
      case 2:
        return 'this_month';
      case 3:
        return 'all_time';
      default:
        return 'this_week';
    }
  }

  // Get friendly period name for empty state
  String _getPeriodName(int tab) {
    switch (tab) {
      case 0:
        return 'this week';
      case 1:
        return 'today';
      case 2:
        return 'this month';
      case 3:
        return 'all time';
      default:
        return 'this week';
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final period = _getPeriodFromTab(selectedTab);
    final result = await _leaderboardService.getLeaderboard(
      period: period,
      page: 1,
      pageSize: 50,
    );

    if (mounted) {
      setState(() {
        isLoading = false;
        if (result.success && result.data != null) {
          leaderboardData = result.data!.results;
          errorMessage = null;
        } else {
          errorMessage = result.error ?? 'Failed to load leaderboard';
          leaderboardData = [];
        }
      });
    }
  }

  // Assign colors based on rank
  Color getColorForRank(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze

    // Cycle through colors for other ranks
    final colors = [
      textOrange,
      const Color(0xFF3A86FF),
      const Color(0xFF9E9E9E),
      const Color(0xFFF8D347),
    ];
    return colors[(rank - 1) % colors.length];
  }

  // Generate tag based on points
  String getTagForPoints(int points) {
    if (points >= 2000) return 'LEGEND';
    if (points >= 1500) return 'PRO';
    if (points >= 1000) return 'EXPERT';
    if (points >= 500) return 'SKILLED';
    return 'ROOKIE';
  }

  Color getTagColor(String tag) {
    switch (tag) {
      case 'LEGEND':
        return Colors.red.shade400;
      case 'PRO':
        return Colors.purple.shade400;
      case 'EXPERT':
        return Colors.blue.shade400;
      case 'SKILLED':
        return Colors.green.shade400;
      case 'ROOKIE':
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: textPink.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Column(
            children: [
              const Text(
                "LEADERBOARD",
                style: TextStyle(
                  fontFamily: 'Digitalt',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              _buildTabsRow(),
              Expanded(
                child: _buildLeaderboardContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 64),
              const SizedBox(height: 20),
              Text(
                'Oops!',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Digitalt',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Rubik',
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadLeaderboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: textGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'TRY AGAIN',
                  style: TextStyle(
                    fontFamily: 'Digitalt',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (leaderboardData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: Colors.white.withOpacity(0.8),
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'NO GAMES PLAYED ${_getPeriodName(selectedTab).toUpperCase()}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Digitalt',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Be the first to play and claim the #1 spot!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontFamily: 'Rubik',
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🎮 PLAY A GAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Digitalt',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start playing to appear on the leaderboard',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontFamily: 'Rubik',
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: leaderboardData.length,
      itemBuilder: (context, index) {
        final entry = leaderboardData[index];
        return LeaderboardCard(
          rank: entry.rank,
          name: entry.username,
          score: entry.totalPoints,
          leftColor: getColorForRank(entry.rank),
          tag: getTagForPoints(entry.totalPoints),
          tagColor: getTagColor(getTagForPoints(entry.totalPoints)),
          badge: entry.gamesPlayed,
          avatarUrl: entry.avatar,
        );
      },
    );
  }

  Widget _buildTabsRow() {
    final tabs = ["WEEK", "DAY", "MONTH", "ALL TIME"];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            tabs.length,
                (i) {
              final isSelected = i == selectedTab;
              return Container(
                margin: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => selectedTab = i);
                    _loadLeaderboard();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? textGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        tabs[i],
                        style: const TextStyle(
                          fontFamily: 'Digitalt',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// --------------------
// Leaderboard Card Widget
// --------------------
class LeaderboardCard extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final Color leftColor;
  final String tag;
  final Color tagColor;
  final int badge;
  final String? avatarUrl;

  const LeaderboardCard({
    super.key,
    required this.rank,
    required this.name,
    required this.score,
    required this.leftColor,
    required this.tag,
    required this.tagColor,
    required this.badge,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    const String baseUrl = "https://nonabstemiously-stocky-cynthia.ngrok-free.dev";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT RANK BAR
            Container(
              width: 32,
              decoration: BoxDecoration(
                color: leftColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: const TextStyle(
                    fontFamily: 'Digitalt',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
            ),

            // RIGHT WHITE CARD
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Avatar + Badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                              ? NetworkImage(baseUrl + avatarUrl!)
                              : const AssetImage("lib/assets/images/settings_emoji.png")
                          as ImageProvider,
                        ),
                        if (badge > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFfc4b81),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 1.2),
                              ),
                              child: Text(
                                badge.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Digitalt',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Name + Score
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: rank <= 3 ? leftColor : Colors.black87,
                            ),
                          ),
                          Text(
                            "SCORE: $score",
                            style: const TextStyle(
                              fontFamily: 'Digitalt',
                              fontSize: 16,
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tag
                    Container(
                      height: 35,
                      width: 70,
                      decoration: BoxDecoration(
                        color: tagColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white54, width: 1.2),
                      ),
                      child: Center(
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontFamily: 'Digitalt',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}