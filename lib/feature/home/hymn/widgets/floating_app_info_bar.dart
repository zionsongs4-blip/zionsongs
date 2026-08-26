import 'package:flutter/material.dart';

class FloatingAppInfoBar extends StatelessWidget {
  final bool visible;
  final VoidCallback? onToggle;

  const FloatingAppInfoBar({
    super.key,
    required this.visible,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      top: visible ? MediaQuery.of(context).padding.top : -80,
      left: 0,
      right: 0,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Text(
                    'App Info',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  visible ? Icons.close : Icons.info_outline,
                ),
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}