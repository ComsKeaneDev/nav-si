import 'package:flutter/material.dart';

class ResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ResetButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      label: 'Reset context',
      button: true,
      hint: 'Press to start detection from the current frame',
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.deepPurple.shade100,
        foregroundColor: Colors.white,
        child: const Text(
          'R',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
