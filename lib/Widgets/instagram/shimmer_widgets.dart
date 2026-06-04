import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerProfileHeader extends StatelessWidget {
  const ShimmerProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          const CircleAvatar(radius: 52, backgroundColor: Colors.white),
          const SizedBox(height: 12),
          Container(height: 18, width: 150, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 14, width: 100, color: Colors.white),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              3,
                  (_) => Column(
                children: [
                  Container(height: 22, width: 50, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 12, width: 60, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerPostsGrid extends StatelessWidget {
  const ShimmerPostsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemCount: 9,
        itemBuilder: (_, __) => Container(color: Colors.white),
      ),
    );
  }
}