import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.transactions'.tr())),
      body: Center(child: Text('transactions.placeholder'.tr())),
    );
  }
}
