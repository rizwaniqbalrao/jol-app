import 'package:flutter/material.dart';
import 'package:jol_app/screens/dashboard/dashboard_screen.dart';
import 'package:jol_app/screens/group/group_screen.dart';
import 'package:jol_app/screens/score%20board/score_board_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../Affiliates/affiliates_screen.dart';
import '../play/paly_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    AffiliatesScreen(),
    PlayScreen(),
    GroupsScreen(),
    ScoreBoardScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],

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
            top: -25, // lifts above the nav bar
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
                      color: const Color(0xFFFFE6F0), // very light pink background
                    ),
                    child: Center(
                      child: Icon(
                        _selectedIndex == 2 ? MdiIcons.play : MdiIcons.playOutline,
                        size: 38,
                        color: const Color(0xFFF82A87), // main pink
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
}