import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SubmitGameScreen extends StatefulWidget {
  const SubmitGameScreen({super.key});

  @override
  State<SubmitGameScreen> createState() => _SubmitGameScreenState();
}

class _SubmitGameScreenState extends State<SubmitGameScreen> {
  static const Color textBlue = Color(0xFF0734A5);
  static const Color textGreen = Color(0xFF43AC45);
  static const Color textPink = Color(0xFFF82A87);

  // fixed grid size = 5
  final int gridSize = 5;

  // fixed 5x5 grid (from your screenshot numbers)
  final List<List<String>> gridData = [
    ["+", "12", "10", "14", "4"],
    ["18", "3", "2", "5", "5"],
    ["1", "1", "25", "8", "25"],
    ["5", "8", "1", "9", "8"],
    ["1", "5", "2", "17", "2"],
  ];

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: textPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Game",
                        style: TextStyle(
                          fontFamily: "Rubik",
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: textGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
        
                const SizedBox(height: 12),
        
                /// Time & Score
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: textPink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Time Left: 00:00",
                          style: TextStyle(
                            fontFamily: "Rubik",
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "Score: 24/24",
                          style: TextStyle(
                            fontFamily: "Rubik",
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        
                const SizedBox(height: 20),
        
                /// Grid + Results Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // 5x5 Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: gridSize * gridSize,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemBuilder: (context, index) {
                          int row = index ~/ gridSize;
                          int col = index % gridSize;
                          String value = gridData[row][col];
        
                          // First pink cell with "+"
                          if (value == "+") {
                            return Container(
                              decoration: BoxDecoration(
                                color: textPink,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Text(
                                  "+",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }
        
                          // Regular number cell
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
        
                      const SizedBox(height: 12),
        
                      // Results Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Remaining Time: ",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold, // now more bold
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "260",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold, // now more bold
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Points:",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "24/24",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold, // now more bold
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Total:",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "260",
                                  style: TextStyle(
                                    fontFamily: "Rubik",
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold, // now more bold
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        
                const Spacer(),
        
                /// Submit Score Button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: textBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Submit Score",
                        style: TextStyle(
                          fontFamily: "Rubik",
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
