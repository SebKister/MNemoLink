import 'package:flutter/material.dart';
import '../models/survey_quality.dart';

/// Widget that displays a 5-star rating with tooltip
class StarRatingWidget extends StatelessWidget {
  final SurveyQuality quality;
  final double size;
  final Color filledColor;
  final Color emptyColor;

  const StarRatingWidget({
    super.key,
    required this.quality,
    this.size = 16.0,
    this.filledColor = Colors.amber,
    this.emptyColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: quality.tooltipMessage,
      preferBelow: false,
      textStyle: const TextStyle(
        fontSize: 12,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      waitDuration: const Duration(milliseconds: 500),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          return Icon(
            index < quality.stars ? Icons.star : Icons.star_border,
            size: size,
            color: index < quality.stars ? filledColor : emptyColor,
          );
        }),
      ),
    );
  }
}