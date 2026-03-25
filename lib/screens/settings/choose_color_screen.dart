import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChooseColorScreen extends StatelessWidget {
  const ChooseColorScreen({super.key});

  static const Color textPink = Color(0xFFF82A87);
  static const Color accentPurple = Color(0xFFC42AF8);

  final List<Map<String, dynamic>> colors = const [
    {"name": "GREEN", "color": Color(0xFF4CAF50)},
    {"name": "PINK", "color": Color(0xFFF82A87)},
    {"name": "BLACK", "color": Colors.black},
    {"name": "PURPLE", "color": Color(0xFF9B4BFF)},
    {"name": "LIGHT BLUE", "color": Color(0xFF87CEFA)},
    {"name": "DARK BLUE", "color": Color(0xFF00008B)},
    {"name": "TEAL BLUE", "color": Color(0xFF008080)},
    {"name": "BABY BLUE", "color": Color(0xFFBFEFFF)},
    {"name": "HONEY ORANGE", "color": Color(0xFFFFA500)},
    {"name": "SAGE GREEN", "color": Color(0xFF9DC183)},
    {"name": "TAUPE BROWN", "color": Color(0xFF8B8589)},
    {"name": "LIGHT PINK", "color": Color(0xFFFFB6C1)},
    {"name": "BEIGE", "color": Color(0xFFF5F5DC)},
    {"name": "ORANGE", "color": Color(0xFFFF5722)},
    {"name": "AZURE BLUE", "color": Color(0xFF007FFF)},
    {"name": "DARK GREEN", "color": Color(0xFF006400)},
    {"name": "BROWN", "color": Color(0xFF8B4513)},
    {"name": "YELLOW", "color": Color(0xFFFFFF00)},
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFC0CB), // pink
              Color(0xFFADD8E6), // light blue
              Color(0xFFE6E6FA), // lavender
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: textPink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        //features comming soon
                        Center(
                          child: Text(
                            "Colour Changing Feature Coming Soon!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Digitalt',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: accentPurple,
                            ),
                          ),
                        ),

                        // Heading

                        // Text(
                        //   "COLOURS",
                        //   style: TextStyle(
                        //     fontFamily: 'Digitalt',
                        //     fontSize: 24,
                        //     fontWeight: FontWeight.bold,
                        //     color: textPink,
                        //     letterSpacing: 1,
                        //   ),
                        // ),
                        // const SizedBox(height: 12),

                        // // Current color
                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //   children: [
                        //     const Text(
                        //       "CURRENT COLOUR: PINK",
                        //       style: TextStyle(
                        //         fontFamily: 'Digitalt',
                        //         fontSize: 20,
                        //         fontWeight: FontWeight.bold,
                        //         color: Color(0xFFC42AF8),
                        //       ),
                        //     ),
                        //     Container(
                        //       width: 20,
                        //       height: 20,
                        //       decoration: BoxDecoration(
                        //         color: textPink,
                        //         borderRadius: BorderRadius.circular(4),
                        //       ),
                        //     )
                        //   ],
                        // ),

                        // const SizedBox(height: 20),

                        // // More options
                        // Text(
                        //   "MORE OPTIONS",
                        //   style: TextStyle(
                        //     fontFamily: 'Digitalt',
                        //     fontSize: 20,
                        //     fontWeight: FontWeight.bold,
                        //     color: Color(0xFFC42AF8),
                        //   ),
                        // ),
                        // // Grid of colors
                        // GridView.builder(
                        //   padding: const EdgeInsets.only(top: 12),
                        //   shrinkWrap: true,
                        //   physics: const NeverScrollableScrollPhysics(),
                        //   gridDelegate:
                        //   const SliverGridDelegateWithFixedCrossAxisCount(
                        //     crossAxisCount: 4,
                        //     crossAxisSpacing: 10,
                        //     mainAxisSpacing: 10,
                        //     childAspectRatio: 1,
                        //   ),
                        //   itemCount: colors.length,
                        //   itemBuilder: (context, index) {
                        //     final item = colors[index];
                        //     return Container(
                        //       decoration: BoxDecoration(
                        //         color: item["color"],
                        //         borderRadius: BorderRadius.circular(8),
                        //       ),
                        //       child: Center(
                        //         child: Text(
                        //           item["name"],
                        //           textAlign: TextAlign.center,
                        //           style: TextStyle(
                        //             fontFamily: 'Digitalt',
                        //             fontSize: 16,
                        //             fontWeight: FontWeight.bold,
                        //             color: Colors.white,
                        //           ),
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),

                        // const SizedBox(height: 20),

                        // // Colour changing cost
                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //   children: [
                        //     const Text(
                        //       "COLOUR CHANGING COST",
                        //       style: TextStyle(
                        //         fontFamily: 'Digitalt',
                        //         fontSize: 20,
                        //         fontWeight: FontWeight.bold,
                        //         color: textPink,
                        //       ),
                        //     ),
                        //     const Text(
                        //       "£1",
                        //       style: TextStyle(
                        //         fontFamily: 'Digitalt',
                        //         fontSize: 20,
                        //         fontWeight: FontWeight.bold,
                        //         color: textPink,
                        //         letterSpacing: 1
                        //       ),
                        //     ),
                        //   ],
                        // ),

                        // const SizedBox(height: 20),

                        // // Button
                        // SizedBox(
                        //   width: double.infinity,
                        //   child: ElevatedButton(
                        //     onPressed: () {},
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Color(0xFFC42AF8),
                        //       padding: const EdgeInsets.symmetric(vertical: 14),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(8),
                        //       ),
                        //     ),
                        //     child: const Text(
                        //       "Pay Now To Change Colour",
                        //       style: TextStyle(
                        //         fontFamily: 'Digitalt',
                        //         fontSize: 16,
                        //         fontWeight: FontWeight.bold,
                        //         color: Colors.white,
                        //       ),
                        //     ),
                        //   ),
                        // )
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

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
            "Color",
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
    );
  }
}
