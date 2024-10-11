import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  final List<FAQItem> faqItems = [
    FAQItem(
      question: "What is the purpose of this app?", 
      answer: "Saan Jo is created as a way for commuters to effortlessly travel around San Jose del Monte.",
      
    ),
    FAQItem(
      question: "How to route to a destination?", 
      answer: "You can route to destination in many ways, you can search a destination on the search bar or press one of our quick-access buttons, click the marker, and press the button to route there.",
      imagePath: 'https://firebasestorage.googleapis.com/v0/b/saan-jo.appspot.com/o/faqimages%2Fimage_2024-10-12_060609947.png?alt=media&token=71ed8ed4-eeaa-4721-a932-f3e0ca8ae974'
    ),
    FAQItem(
      question: "This route is inaccurate!", 
      answer: "Please help us improve by providing accurate information on the terminal, simply click the ticket button to submit a ticket!",
      imagePath: 'assets/inaccurate_route.png', 
    ),
    FAQItem(
      question: "Who made the app?", 
      answer: "The app is a capstone project of STI San Jose del Monte - BSIT Batch 2020-2024.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Frequently Asked Questions'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Adding the image at the top center
            Image.asset(
              'assets/logo2.png',
              height: 250,
            ),
            SizedBox(height: 16), // Space between image and FAQ list
            Expanded(
              child: ListView.builder(
                itemCount: faqItems.length,
                itemBuilder: (context, index) {
                  return FAQCard(faqItem: faqItems[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;
  final String? imagePath; // Optional image path

  FAQItem({required this.question, required this.answer, this.imagePath});
}

class FAQCard extends StatelessWidget {
  final FAQItem faqItem;

  FAQCard({required this.faqItem});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        title: Text(
          faqItem.question,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display image if it exists
                if (faqItem.imagePath != null)
                  Image.asset(
                    faqItem.imagePath!,
                    height: 150, // Set your desired height
                    fit: BoxFit.cover, // Adjust image fit
                  ),
                SizedBox(height: 10), // Space between image and text
                Text(
                  faqItem.answer,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: FAQPage(),
  ));
}
