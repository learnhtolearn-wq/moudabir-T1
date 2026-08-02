import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.goals'.tr())),
      body: Center(child: Text('goals.placeholder'.tr())),
    );
  }
}
