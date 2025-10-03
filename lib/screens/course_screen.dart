import 'package:flutter/material.dart';

class CourseScreen extends StatefulWidget{
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen>{
  @override
  Widget build(BuildContext context){
    return Center(
      child: Text('Course Page 1'),
    );
  }
}