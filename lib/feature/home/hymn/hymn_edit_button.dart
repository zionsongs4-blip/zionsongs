import 'package:flutter/material.dart'; 
import 'package:isar/isar.dart';
import 'hymn_auth_service.dart';

class EditButton extends StatelessWidget { 
  final Isar isar; 
  final String hymnId; 
  final String lyrics; 
  final VoidCallback onEditTogether; 
  final bool hasError; 
  
  const EditButton({
    super.key, 
    required this.isar, 
    required this.hymnId, 
    required this.lyrics, 
    required this.onEditTogether, 
    this.hasError = false
  }); 
  
  @override 
  Widget build(BuildContext context) { 
    return Stack(children: [
      IconButton(
        icon: const Icon(Icons.edit),
        onPressed: onEditTogether,
      ), 
      if(hasError) 
        Positioned(
          right: 0, 
          top: 0, 
          child: Icon(Icons.error, size: 12, color: Colors.red)
        )
    ]); 
  } 
}