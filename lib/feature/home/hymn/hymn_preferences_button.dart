import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';

import 'hymn_models.dart';
import 'hymn_preferences_logic.dart';

class HymnPreferencesButton extends StatelessWidget {
  final UserHymnPref pref;
  final Isar isar;
  final List<String> styles;
  final VoidCallback onChanged;

  const HymnPreferencesButton({
    super.key,
    required this.pref,
    required this.isar,
    required this.styles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 120,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(
              text: pref.style ?? '',
            ),
            optionsBuilder: (value) {
              if (value.text.isEmpty) {
                return styles;
              }
              return styles.where(
                (s) => s.toLowerCase().contains(
                  value.text.toLowerCase(),
                ),
              );
            },
            onSelected: (String value) async {
              await HymnPreferencesLogic.saveStyle(pref, value);
              onChanged();
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Style',
                  isDense: true,
                ),
              );
            },
          ),
        ),

        SizedBox(
          width: 80,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(
              text: pref.tempo.toString(),
            ),
            optionsBuilder: (value) {
              final bpms = HymnPreferencesLogic.getBpms();

              if (value.text.isEmpty) {
                return bpms;
              }

              return bpms.where(
                (b) => b.contains(value.text),
              );
            },
            onSelected: (String value) async {
              await HymnPreferencesLogic.saveTempo(pref, value);
              onChanged();
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'BPM',
                  isDense: true,
                ),
              );
            },
          ),
        ),

        SizedBox(
          width: 80,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(
              text: pref.beat ?? '',
            ),
            optionsBuilder: (value) {
              final beats = HymnPreferencesLogic.getBeats();

              if (value.text.isEmpty) {
                return beats;
              }

              return beats.where(
                (b) => b.contains(value.text),
              );
            },
            onSelected: (String value) async {
              await HymnPreferencesLogic.saveBeat(pref, value);
              onChanged();
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Beat',
                  isDense: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}