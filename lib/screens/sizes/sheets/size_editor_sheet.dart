import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';

class SizeEditorSheet extends StatefulWidget {
  final PigioAppState state;
  final String initialCategoryKey;
  final Map<String, Map<String, dynamic>> allMeta;
  final String? contactId;

  const SizeEditorSheet({
    super.key,
    required this.state,
    required this.initialCategoryKey,
    required this.allMeta,
    this.contactId,
  });

  @override
  State<SizeEditorSheet> createState() => _SizeEditorSheetState();
}

class _SizeEditorSheetState extends State<SizeEditorSheet> {
  late String _currentCategory;
  final Map<String, String?> _values = {};
  String? _fit;
  String _visibility = 'full_access';

  static const Map<String, List<String>> _standardOptions = {
    'standard': ['-', 'XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL'],
    'eu_clothes': ['-', '32', '34', '36', '38', '40', '42', '44', '46', '48', '50', '52'],
    'eu_shoes': ['-', '35', '35.5', '36', '37', '37.5', '38', '38.5', '39', '40', '41', '42', '43', '44', '45', '46', '47', '48'],
    'us_shoes': ['-', '4', '4.5', '5', '5.5', '6', '6.5', '7', '7.5', '8', '8.5', '9', '9.5', '10', '10.5', '11', '11.5', '12', '13'],
    'uk_shoes': ['-', '3', '3.5', '4', '4.5', '5', '5.5', '6', '6.5', '7', '7.5', '8', '8.5', '9', '10', '11', '12'],
    'cm_shoes': ['-', '22', '22.5', '23', '23.5', '24', '24.5', '25', '25.5', '26', '26.5', '27', '27.5', '28', '28.5', '29', '29.5', '30'],
    'eu_bottoms': ['-', '32', '34', '36', '38', '40', '42', '44', '46', '48', '50', '52', '54'],
    'us_waist': ['-', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '36', '38', '40', '42'],
    'us_length': ['-', '28', '30', '32', '34', '36'],
    'ring_eu_left': ['-', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '70'],
    'ring_eu_right': ['-', '44', '45', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '70'],
    'ring_us_left': ['-', '3', '3.5', '4', '4.5', '5', '5.5', '6', '6.5', '7', '7.5', '8', '8.5', '9', '9.5', '10', '10.5', '11', '11.5', '12', '12.5', '13'],
    'ring_us_right': ['-', '3', '3.5', '4', '4.5', '5', '5.5', '6', '6.5', '7', '7.5', '8', '8.5', '9', '9.5', '10', '10.5', '11', '11.5', '12', '12.5', '13'],
    'ring_diameter_mm': ['-', '14', '14.5', '15', '15.5', '16', '16.5', '17', '17.5', '18', '18.5', '19', '19.5', '20', '20.5', '21', '21.5', '22'],
    'wrist_cm': ['-', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23'],
    'wrist_in': ['-', '5', '5.5', '6', '6.5', '7', '7.5', '8', '8.5', '9'],
    'watch_size': ['-', '36', '38', '40', '42', '44', '46', '49'],
    'necklace_cm': ['-', '35', '40', '42', '45', '50', '55', '60', '65', '70', '80'],
    'necklace_in': ['-', '14', '16', '17', '18', '20', '22', '24', '26', '28', '32'],
    'necklace_diameter': ['-', '12', '13', '14', '15', '16', '17', '18'],
  };

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.initialCategoryKey;
    _loadCategoryData();
  }

  void _loadCategoryData() {
    final profile = widget.state.sizes.where((s) => s.categoryKey == _currentCategory && s.contactId == widget.contactId).firstOrNull;
    _values.clear();
    if (profile != null) {
      profile.values.forEach((key, value) => _values[key] = value);
      _fit = profile.fitKey;
      _visibility = profile.visibilityKey;
    } else {
      _fit = null;
      _visibility = 'full_access';
    }
  }

  Map<String, String> get _availableFormats {
    final isEn = widget.state.locale.languageCode == 'en';
    switch (_currentCategory) {
      case 'clothes': return {'standard': 'fmt_international', 'eu_clothes': 'fmt_europe'};
      case 'shoes': return {'eu_shoes': 'fmt_europe', 'us_shoes': 'fmt_us', 'uk_shoes': 'fmt_uk', 'cm_shoes': 'fmt_cm'};
      case 'bottoms': return {'eu_bottoms': 'fmt_europe', 'us_waist': 'fmt_us_waist', 'us_length': 'fmt_us_length', 'standard': 'fmt_international'};
      case 'rings': 
        return isEn 
            ? {'ring_us_left': 'fmt_ring_l_us', 'ring_us_right': 'fmt_ring_r_us', 'ring_diameter_mm': 'fmt_ring_diam'}
            : {'ring_eu_left': 'fmt_ring_l_eu', 'ring_eu_right': 'fmt_ring_r_eu', 'ring_diameter_mm': 'fmt_ring_diam'};
      case 'bracelets': 
        return isEn 
            ? {'wrist_in': 'fmt_wrist_in', 'watch_size': 'fmt_watch_size'}
            : {'wrist_cm': 'fmt_wrist_cm', 'watch_size': 'fmt_watch_size'};
      case 'necklaces': 
        return isEn 
            ? {'necklace_in': 'fmt_necklace_in', 'necklace_diameter': 'fmt_necklace_diam'}
            : {'necklace_cm': 'fmt_necklace_cm', 'necklace_diameter': 'fmt_necklace_diam'};
      default: return {'standard': 'fmt_size'};
    }
  }

  void _saveCurrent() {
    final cleanValues = <String, String>{};
    _values.forEach((key, value) {
      if (value != null && value.isNotEmpty && value != '-') cleanValues[key] = value;
    });

    if (cleanValues.isNotEmpty || _fit != null) {
      widget.state.saveSizeProfile(
        _currentCategory,
        cleanValues,
        contactId: widget.contactId,
        fitKey: _fit,
        visibilityKey: _visibility,
      );
    }
  }

  void _onNext() {
    _saveCurrent();
    final keys = widget.allMeta.keys.toList();
    final nextIdx = (keys.indexOf(_currentCategory) + 1) % keys.length;
    setState(() {
      _currentCategory = keys[nextIdx];
      _loadCategoryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final meta = widget.allMeta[_currentCategory]!;
    final color = meta['visColor'] as Color;
    final keys = widget.allMeta.keys.toList();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: theme.light.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(t(context, 'edit_sizes'), style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: theme.mid),
                  onPressed: () { _saveCurrent(); Navigator.pop(context, true); },
                ),
              ],
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: keys.map((key) {
                final isCurrent = key == _currentCategory;
                final m = widget.allMeta[key]!;
                return GestureDetector(
                  onTap: () {
                    _saveCurrent();
                    setState(() { _currentCategory = key; _loadCategoryData(); });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrent ? (m['visColor'] as Color).withValues(alpha: 0.15) : theme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: isCurrent ? Border.all(color: m['visColor'] as Color, width: 1.5) : null,
                    ),
                    child: Row(
                      children: [
                        Text(m['emoji'], style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(t(context, key), style: fw(size: 13, w: isCurrent ? FontWeight.w800 : FontWeight.w600, color: isCurrent ? (m['visColor'] as Color) : theme.mid)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("VALEURS", style: fw(size: 11, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  
                  // Use a Wrap for Dropdowns so they look nice side-by-side or stacked
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: _availableFormats.entries.map((entry) {
                      final formatKey = entry.key;
                      final options = _standardOptions[formatKey] ?? [];
                      final selectedVal = _values[formatKey] ?? '-';
                      
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 56) / 2, // 2 columns
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(t(context, entry.value), style: fw(size: 12, w: FontWeight.w700, color: theme.mid)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: theme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selectedVal != '-' ? color.withValues(alpha: 0.5) : theme.divider,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedVal,
                                  isExpanded: true,
                                  icon: Icon(Icons.expand_more, color: selectedVal != '-' ? color : theme.mid),
                                  style: fw(size: 15, w: FontWeight.w700, color: selectedVal != '-' ? color : theme.ink),
                                  items: options.map((opt) {
                                    return DropdownMenuItem(
                                      value: opt,
                                      child: Text(opt == '-' ? 'Sélectionner...' : opt),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _values[formatKey] = val == '-' ? null : val;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 32),

                  if (meta['fits'] != null) ...[
                    Text(t(context, 'fit_pref').toUpperCase(), style: fw(size: 11, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.1)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: (meta['fits'] as List).map((fit) {
                        final fitKey = fit as String;
                        final isSelected = _fit == fitKey;
                        return GestureDetector(
                          onTap: () => setState(() => _fit = isSelected ? null : fitKey),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(color: isSelected ? color : theme.surface, borderRadius: BorderRadius.circular(14)),
                            child: Text(t(context, fitKey), style: fw(size: 13, w: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? theme.onAccent : theme.mid)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Text("CONFIDENTIALITÉ", style: fw(size: 11, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _visibility,
                        isExpanded: true,
                        icon: const Icon(Icons.lock_outline, size: 18),
                        items: [
                          DropdownMenuItem(value: 'full_access', child: Text(t(context, 'full_access'), style: fw(size: 14, w: FontWeight.w700, color: theme.ink))),
                          DropdownMenuItem(value: 'limited_view', child: Text(t(context, 'limited_view'), style: fw(size: 14, w: FontWeight.w700, color: theme.ink))),
                        ],
                        onChanged: (val) { if (val != null) setState(() => _visibility = val); },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  Row(
                    children: [
                      Expanded(
                        child: PigioButton(
                          label: t(context, 'save_and_next'),
                          color: color,
                          onTap: _onNext,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () { _saveCurrent(); Navigator.pop(context, true); },
                      child: Text(t(context, 'finish'), style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
