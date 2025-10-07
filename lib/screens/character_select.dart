import 'package:flutter/material.dart';
import 'home.dart';
//var ChosenCharacter = 'assets/images/${characters[selectedCharacterIndex!]}';
class CharSel extends StatelessWidget {
  List<String> characters = [
    'panda.png',
    'lion.png',
    'pig.png',
    'monkey.png',
    'dino.png',
    'deer.png'
  ];
  static var chosenCharacter ='';
  int? selectedCharacterIndex;
  static const String routeName = '/character_select';

  CharSel({super.key});



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text("Character Selection"),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "Choose your character",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                  ),
                  itemCount: characters.length, // Number of characters
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        // Set the selected character and move to home page
                        selectedCharacterIndex = index;
                        CharSel.chosenCharacter = 'assets/images/${characters[index]}';
                        Navigator.pushNamed(context, HomePage.routeName);
                      },
                      child: GridTile(
                        child: Image.asset(
                          'assets/images/${characters[index]}', // Character images in the grid
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
