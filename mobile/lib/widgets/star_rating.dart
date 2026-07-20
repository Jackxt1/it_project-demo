import 'package:flutter/material.dart';

/// Read-only star row for a (possibly fractional) [rating] 0–5. Renders full,
/// half and empty stars.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 18,
    this.color = Colors.amber,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final position = i + 1;
        IconData icon;
        if (rating >= position) {
          icon = Icons.star;
        } else if (rating >= position - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}

/// Tappable 1–5 star selector. Calls [onChanged] with the tapped value.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final position = i + 1;
        return IconButton(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
          onPressed: () => onChanged(position),
          icon: Icon(
            position <= value ? Icons.star : Icons.star_border,
            size: size,
            color: position <= value ? Colors.amber : Colors.grey,
          ),
        );
      }),
    );
  }
}
