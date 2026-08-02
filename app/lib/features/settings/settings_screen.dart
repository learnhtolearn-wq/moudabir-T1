import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr())),
      body: ListView(
        children: [
          ListTile(
            title: Text('settings.language'.tr()),
            subtitle: Text(context.locale.toString()),
            onTap: () => _showLanguagePicker(context),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: context.supportedLocales.map((locale) {
            return ListTile(
              title: Text(locale.languageCode.toUpperCase()),
              onTap: () {
                context.setLocale(locale);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
