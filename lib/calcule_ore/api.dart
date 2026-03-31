// lib/calcule_ore/api.dart

// Re-export din implementarea existentă (NU schimbăm logica de split).
export '../utils/time_calc.dart' show SplitResult, splitServiceTime;

// Re-export sărbători legale / helpers, exact cum le foloseai înainte.
export '../utils/holidays.dart'
    show kRomanianLegalHolidays, loadLegalHolidaysFromDb, isLegalHoliday;

// API-ul unificat pentru totaluri/defalcări:
export 'calcul_minute.dart';
