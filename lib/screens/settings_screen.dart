import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final time = TimeOfDay(hour: state.alertHour, minute: state.alertMinute);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          _Header(s.language),
          _langTile(state, s, AppLang.en, s.english),
          _langTile(state, s, AppLang.fi, s.finnish),
          const Divider(),
          _Header(s.dataSource),
          ...state.sources.map((src) {
            final selected = src.id == state.sourceId;
            return ListTile(
              leading: Icon(selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off),
              title: Text(src.label),
              subtitle: Text(src.attribution),
              onTap: () => state.setSource(src.id),
            );
          }),
          const Divider(),
          _Header(s.notifications),
          SwitchListTile(
            value: state.dailyAlert,
            onChanged: state.setDailyAlert,
            title: Text(s.dailyAlert),
            subtitle: Text(s.dailyAlertSub),
          ),
          ListTile(
            enabled: state.dailyAlert,
            leading: const Icon(Icons.schedule),
            title: Text(s.reminderTime),
            trailing: Text(time.format(context)),
            onTap: state.dailyAlert
                ? () async {
                    final picked =
                        await showTimePicker(context: context, initialTime: time);
                    if (picked != null) {
                      await state.setAlertTime(picked.hour, picked.minute);
                    }
                  }
                : null,
          ),
          ListTile(
            enabled: state.dailyAlert,
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(s.sendTest),
            onTap: state.dailyAlert
                ? () async {
                    final w = state.worstToday();
                    await state.notifications.showHeadsUp(
                      w == null
                          ? s.notifications
                          : s.summaryHeadline(
                              s.level(w.level), s.allergenName(w.allergen)),
                      w == null
                          ? s.dailyAlertSub
                          : '${state.currentLocation.nameFi}: ${s.levelAdvice(w.level)}',
                    );
                  }
                : null,
          ),
          const Divider(),
          _Header(s.homeWidget),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: Text(s.addWidget),
            subtitle: Text(s.addWidgetSub),
            onTap: () async {
              final ok = await state.widgetService.pinWidget();
              if (!context.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.addWidgetUnsupported)),
                );
              }
            },
          ),
          const Divider(),
          _Header(s.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Pollen FI'),
            subtitle: Text(s.aboutBody),
          ),
        ],
      ),
    );
  }

  Widget _langTile(AppState state, L10n s, AppLang lang, String label) {
    final selected = state.lang == lang;
    return ListTile(
      leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off),
      title: Text(label),
      onTap: () => state.setLang(lang),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
