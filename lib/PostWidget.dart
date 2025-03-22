import 'package:flutter/material.dart';
import 'package:stattrak/models/Post.dart';

class PostWidget extends StatelessWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("${post.date} - ${post.location}"),
            const SizedBox(height: 8),
            Text(post.title, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text("Distance: ${post.distance} km"),
                const SizedBox(width: 16),
                Text("Elev Gain: ${post.elevation} m"),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: post.imageUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Image.network(url),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text("${post.likes} gave like ❤️"),
          ],
        ),
      ),
    );
  }
}
