"""Replace ALL relative theme/* and root-level screen/* imports with package: equivalents."""
from pathlib import Path

THEME_MAP = {
    'app_state.dart':   'package:pigio_app/core/state/app_state.dart',
    'app_models.dart':  'package:pigio_app/core/models/app_models.dart',
    'constants.dart':   'package:pigio_app/core/config/constants.dart',
    'pigio_theme.dart': 'package:pigio_app/core/theme/pigio_theme.dart',
    'i18n.dart':        'package:pigio_app/core/i18n/i18n.dart',
}

SCREEN_MAP = {
    'screens/add_profile_sheet.dart':       'package:pigio_app/screens/contacts/sheets/add_profile_sheet.dart',
    'screens/contact_profile_screen.dart':  'package:pigio_app/features/contacts/presentation/contact_profile_screen.dart',
    'screens/activity_history_screen.dart': 'package:pigio_app/screens/activity/activity_history_screen.dart',
    'screens/wish_editor_sheet.dart':       'package:pigio_app/screens/wishes/sheets/wish_editor_sheet.dart',
    'screens/add_event_sheet.dart':         'package:pigio_app/screens/events/sheets/add_event_sheet.dart',
    'screens/add_group_sheet.dart':         'package:pigio_app/screens/groups/sheets/add_group_sheet.dart',
    'screens/size_editor_sheet.dart':       'package:pigio_app/screens/sizes/sheets/size_editor_sheet.dart',
    'screens/wizz_sheet.dart':              'package:pigio_app/screens/wishes/sheets/wizz_sheet.dart',
    'screens/mascot_settings_screen.dart':  'package:pigio_app/screens/mascot/mascot_settings_screen.dart',
    'screens/mascot_wardrobe_screen.dart':  'package:pigio_app/screens/mascot/mascot_wardrobe_screen.dart',
    'screens/know_thyself_screen.dart':     'package:pigio_app/screens/mascot/know_thyself_screen.dart',
    'screens/mondial_relay_screen.dart':    'package:pigio_app/screens/contacts/mondial_relay_screen.dart',
    'screens/wardrobe_screen.dart':         'package:pigio_app/screens/sizes/wardrobe_screen.dart',
    'screens/wishes_screen.dart':           'package:pigio_app/screens/wishes/wishes_screen.dart',
    'screens/profile_screen.dart':          'package:pigio_app/screens/profile/profile_screen.dart',
    'screens/home_screen.dart':             'package:pigio_app/features/home/presentation/home_screen.dart',
    'screens/calendar_screen.dart':         'package:pigio_app/screens/events/calendar_screen.dart',
    'screens/contacts_screen.dart':         'package:pigio_app/screens/contacts/contacts_screen.dart',
    'screens/settings_screen.dart':         'package:pigio_app/screens/settings/settings_screen.dart',
    'screens/welcome_screen.dart':          'package:pigio_app/screens/welcome/welcome_screen.dart',
}

DOTS = ['../', '../../', '../../../', '../../../../', '../../../../../']

lib_root = Path('lib')
changed = 0

for dart_file in lib_root.rglob('*.dart'):
    text = dart_file.read_text(encoding='utf-8')
    new_text = text
    for kw in ('import', 'export'):
        for fname, core_path in THEME_MAP.items():
            for dots in DOTS:
                old = kw + " '" + dots + 'theme/' + fname + "'"
                new_text = new_text.replace(old, kw + " '" + core_path + "'")
            old_pkg = kw + " 'package:pigio_app/theme/" + fname + "'"
            new_text = new_text.replace(old_pkg, kw + " '" + core_path + "'")
        for screen_suffix, pkg_path in SCREEN_MAP.items():
            for dots in DOTS:
                old = kw + " '" + dots + screen_suffix + "'"
                new_text = new_text.replace(old, kw + " '" + pkg_path + "'")
            # also handle package: imports of root-level screen facades
            old_pkg = kw + " 'package:pigio_app/" + screen_suffix + "'"
            new_text = new_text.replace(old_pkg, kw + " '" + pkg_path + "'")
    if new_text != text:
        dart_file.write_text(new_text, encoding='utf-8')
        print('  updated:', dart_file)
        changed += 1

print('Done -', changed, 'file(s) updated.')
