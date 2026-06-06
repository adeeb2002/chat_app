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
          const CircleAvatar(radius: 54, backgroundColor: Colors.white),
          const SizedBox(height: 14),
          Container(
              height: 20, width: 160, color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8)),
          Container(height: 14, width: 100, color: Colors.white),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
                  (_) => Column(children: [
                Container(
                    height: 22, width: 50,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 6)),
                Container(height: 12, width: 40, color: Colors.white),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerStoriesRow extends StatelessWidget {
  const ShimmerStoriesRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 5,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                const CircleAvatar(
                    radius: 32, backgroundColor: Colors.white),
                const SizedBox(height: 6),
                Container(
                    height: 10, width: 60, color: Colors.white),
              ],
            ),
          ),
        ),
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
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 9,
        itemBuilder: (_, __) => Container(color: Colors.white),
      ),
    );
  }
}