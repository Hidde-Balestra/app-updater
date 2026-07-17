import 'package:flutter/material.dart';

const _palette = [
  Color(0xFF5B4FE5),
  Color(0xFFE08A00),
  Color(0xFF1E9E5A),
  Color(0xFFD64545),
  Color(0xFF2F8FD1),
  Color(0xFF9B4FD1),
  Color(0xFF00A3A3),
  Color(0xFFC24F8F),
];

/// Deterministic colored circle with the app's initials, matching the
/// avatar style used throughout the Figma design.
class AppAvatar extends StatelessWidget {
  final String name;
  final String initials;
  final double size;

  const AppAvatar({super.key, required this.name, required this.initials, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
