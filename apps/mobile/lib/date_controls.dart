import 'package:flutter/material.dart';

Future<void> chooseTime(
  BuildContext context,
  TextEditingController controller,
) async {
  final initial =
      DateTime.tryParse(controller.text)?.toLocal() ?? DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null || !context.mounted) return;
  controller.text = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).toUtc().toIso8601String();
}
