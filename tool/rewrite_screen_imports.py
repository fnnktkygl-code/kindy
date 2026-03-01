from pathlib import Path
import re

moved = [
    'lib/screens/activity/activity_history_screen.dart',
    'lib/screens/events/calendar_screen.dart',
    'lib/screens/events/sheets/add_event_sheet.dart',
    'lib/screens/groups/sheets/add_group_sheet.dart',
    'lib/screens/contacts/sheets/add_profile_sheet.dart',
    'lib/screens/contacts/mondial_relay_screen.dart',
    'lib/screens/contacts/contacts_screen.dart',
    'lib/screens/profile/profile_screen.dart',
    'lib/screens/settings/settings_screen.dart',
    'lib/screens/sizes/wardrobe_screen.dart',
    'lib/screens/sizes/sheets/size_editor_sheet.dart',
    'lib/screens/wishes/wishes_screen.dart',
    'lib/screens/wishes/sheets/wish_editor_sheet.dart',
    'lib/screens/wishes/sheets/wizz_sheet.dart',
    'lib/screens/mascot/mascot_settings_screen.dart',
    'lib/screens/mascot/mascot_wardrobe_screen.dart',
    'lib/screens/mascot/know_thyself_screen.dart',
    'lib/screens/welcome/welcome_screen.dart',
]

pattern = re.compile(r"^(\s*)(import|export)\s+'([^']+)';")
lib_root = (Path.cwd() / 'lib').resolve()

for file_path in moved:
    path = Path(file_path)
    content = path.read_text(encoding='utf-8').splitlines()
    updated = []

    for line in content:
        match = pattern.match(line)
        if not match:
            updated.append(line)
            continue

        indent, kind, target = match.groups()
        if target.startswith('dart:') or target.startswith('package:'):
            updated.append(line)
            continue

        resolved = (path.parent / target).resolve()
        try:
            rel = resolved.relative_to(lib_root)
        except ValueError:
            updated.append(line)
            continue

        updated.append(f"{indent}{kind} 'package:pigio_app/{rel.as_posix()}';")

    path.write_text('\n'.join(updated) + '\n', encoding='utf-8')

print('done')
