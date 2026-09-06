import 'package:flutter/material.dart';

import '../models/admin_alert_topic.dart';
import '../services/admin_alert_preferences_service.dart';

/// Checkbox chips to pick which alert topics to focus on (sound + badge).
class AdminAlertFocusSelector extends StatelessWidget {
  const AdminAlertFocusSelector({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdminAlertPreferencesService.instance,
      builder: (context, _) {
        final prefs = AdminAlertPreferencesService.instance;
        if (!prefs.isLoaded) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.tune_rounded, size: 18, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'โฟกัสหัวข้อแจ้งเตือน',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF9A3412),
                          ),
                    ),
                  ),
                  if (!prefs.isAllFocused)
                    TextButton(
                      onPressed: prefs.setAllFocused,
                      child: const Text('เลือกทั้งหมด'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'แสดงทุกรายการด้านล่าง — ติ๊กหัวข้อที่ต้องการเน้นเสียงและ badge',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: AdminAlertTopic.allTypes.map((type) {
                  final focused = prefs.isFocused(type);
                  return FilterChip(
                    label: Text(AdminAlertTopic.shortLabel(type)),
                    selected: focused,
                    showCheckmark: true,
                    selectedColor: const Color(0xFFFFE0B2),
                    checkmarkColor: const Color(0xFF9A3412),
                    labelStyle: TextStyle(
                      fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                      color: focused ? const Color(0xFF9A3412) : const Color(0xFF6B7280),
                      fontSize: compact ? 12 : 13,
                    ),
                    onSelected: (_) => prefs.toggle(type),
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Settings list variant with full labels.
class AdminAlertFocusSettingsSection extends StatelessWidget {
  const AdminAlertFocusSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdminAlertPreferencesService.instance,
      builder: (context, _) {
        final prefs = AdminAlertPreferencesService.instance;
        if (!prefs.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'เลือกหัวข้อที่ต้องการเน้นแจ้งเตือน (เสียง + badge) — รายการทั้งหมดยังแสดงในศูนย์แจ้งเตือน',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            ...AdminAlertTopic.allTypes.map((type) {
              final focused = prefs.isFocused(type);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: focused,
                activeColor: const Color(0xFFE65100),
                title: Text(
                  AdminAlertTopic.label(type),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onChanged: (_) => prefs.toggle(type),
              );
            }),
            if (!prefs.isAllFocused)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: prefs.setAllFocused,
                  icon: const Icon(Icons.select_all_rounded, size: 18),
                  label: const Text('เลือกทั้งหมด'),
                ),
              ),
          ],
        );
      },
    );
  }
}
