// lib/calcule_ore/calcul_minute.dart
import 'package:flutter/foundation.dart';
import '../utils/time_calc.dart';
import '../utils/holidays.dart';

/// Structură standard pentru totaluri.
/// Cheile rămân identice cu ce salvezi deja în storage (compatibilitate 1:1).
Map<String, int> emptyTotals() => <String, int>{
  'trenTotalMin': 0,
  'trenDayMin': 0,
  'trenNightMin': 0,
  'trenFestDayMin': 0,
  'trenFestNightMin': 0,
  'mvStatieMin': 0,
  'mvDepouMin': 0,
  'acarMin': 0,
  'regieMin': 0,
  'odihnaMin': 0,
  'revizorMin': 0,
  'sefTuraMin': 0,
  'alteMin': 0,
};

/// Adună b în a (in-place).
Map<String, int> addTotalsInPlace(Map<String, int> a, Map<String, int> b) {
  for (final e in b.entries) {
    a[e.key] = (a[e.key] ?? 0) + e.value;
  }
  return a;
}

/// Întoarce o nouă hartă = a + b (fără efecte secundare).
Map<String, int> sumTotals(Map<String, int> a, Map<String, int> b) {
  final out = Map<String, int>.from(a);
  return addTotalsInPlace(out, b);
}

/// Defalcarea pe un singur segment [start, end) pentru un [typeKey].
/// typeKey ∈ { tren, mvStatie, mvDepou, acar, regie, odihna, revizor, sefTura, alte }.
Map<String, int> totalsForSlice({
  required String typeKey,
  required DateTime start,
  required DateTime end,
  Set<DateTime>? holidays,
}) {
  assert(!end.isBefore(start), 'end trebuie să fie >= start');

  final out = emptyTotals();
  final mins = end.difference(start).inMinutes;
  final h = holidays ?? kRomanianLegalHolidays;

  switch (typeKey) {
    case 'tren': {
      final r = splitServiceTime(start, end, h);
      out['trenDayMin'] = r.dayWorkMin;
      out['trenNightMin'] = r.nightWorkMin;
      out['trenFestDayMin'] = r.festiveDayMin;
      out['trenFestNightMin'] = r.festiveNightMin;
      out['trenTotalMin'] =
          r.dayWorkMin + r.nightWorkMin + r.festiveDayMin + r.festiveNightMin;
      break;
    }

    case 'mvStatie':
      out['mvStatieMin'] = mins;
      break;
    case 'mvDepou':
      out['mvDepouMin'] = mins;
      break;
    case 'acar':
      out['acarMin'] = mins;
      break;
    case 'regie':
      out['regieMin'] = mins;
      break;
    case 'odihna':
      out['odihnaMin'] = mins;
      break;
    case 'revizor':
      out['revizorMin'] = mins;
      break;
    case 'sefTura':
      out['sefTuraMin'] = mins;
      break;
    case 'alte':
      out['alteMin'] = mins;
      break;

    default:
      if (kDebugMode) {
        debugPrint('[calcule_ore] typeKey necunoscut: $typeKey (mins=$mins)');
      }
      break;
  }

  return out;
}

/// Buckets de MUNCĂ (zi/noapte/festiv-zi/festiv-noapte) pentru un segment.
/// Considerăm muncă: tren, mvStatie, mvDepou, acar, regie, revizor, sefTura, alte.
/// Pentru odihna -> 0 pe toate aceste buckets (are contorizare separată).
Map<String, int> workedBucketsForSlice({
  required String typeKey,
  required DateTime start,
  required DateTime end,
  Set<DateTime>? holidays,
}) {
  final h = holidays ?? kRomanianLegalHolidays;

  // Nu contăm la buckets de „muncă” doar odihna:
  if (typeKey == 'odihna') {
    return <String, int>{
      'day': 0,
      'night': 0,
      'festDay': 0,
      'festNight': 0,
    };
  }

  // Pentru tipurile „muncă” folosim același split legal (zi/noapte/festive).
  final r = splitServiceTime(start, end, h);
  return <String, int>{
    'day': r.dayWorkMin,
    'night': r.nightWorkMin,
    'festDay': r.festiveDayMin,
    'festNight': r.festiveNightMin,
  };
}