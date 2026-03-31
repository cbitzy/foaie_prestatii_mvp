// /lib/whats_new_text.dart

const String whatsNewTitle = 'Ce este nou';
const String whatsNewVersion = 'v0.0.92';
const String whatsNewShownVersionKey = 'whats_new_shown_version';

class WhatsNewEntry {
  final String version;
  final String dateLabel;
  final List<String> changes;
  const WhatsNewEntry({
    required this.version,
    required this.dateLabel,
    required this.changes,
  });
}
// ==========================================================
// ADAUGĂ ÎNTOTDEAUNA AICI VERSIUNEA NOUĂ DE WHAT'S NEW
// - versiunea curentă trebuie să fie PRIMA în listă
// - modifică și const String whatsNewVersion de mai sus
// - păstrează versiunile vechi dedesubt
// ==========================================================

// Model pentru următoarea versiune:
// 1) modifici sus: const String whatsNewVersion = 'v0.0.87';
// 2) copiezi blocul de mai jos și îl inserezi PRIMUL în listă, deasupra versiunii curente
//
// WhatsNewEntry(
//   version: 'v0.0.87',
//   dateLabel: '10 mai 2026',
//   changes: [
//     'Primul punct nou.',
//     'Al doilea punct nou.',
//   ],
// ),

const List<WhatsNewEntry> whatsNewEntries = [
  // >>> INSEREAZĂ AICI VERSIUNEA NOUĂ, DEASUPRA CELOR VECHI >>>

  WhatsNewEntry(
    version: 'v0.0.9',
    dateLabel: '30 martie 2026',
    changes: [
      'A fost adaugat un buton dedicat pentru inchiderea aplicatiei',
    ],
  ),

  WhatsNewEntry(
    version: 'v0.0.92',
    dateLabel: '30 martie 2026',
    changes: [
      'A fost corectată problema de schimbare a orei la trecerea la ora de vară și la revenirea la ora standard (lunile martie/octombrie).',
      'Segmentele și serviciile care trec peste miezul nopții nu mai sunt despărțite greșit din cauza schimbării orei.',
      'Serviciile afectate deja salvate în noaptea 29–30 martie 2026 sunt reparate automat la pornirea aplicației după update.',
      'A fost ajustat fluxul de actualizare din aplicație pentru a evita blocarea instalării la pornire.',
      'Modificari/ajustari ale ecranelor UI.',
    ],
  ),

  WhatsNewEntry(
    version: 'v0.0.87',
    dateLabel: '28 martie 2026',
    changes: [
      'A fost îmbunătățită gestionarea fotografiilor din secțiunea „Avansat”.',
      'A fost adăugat în Setări sectiunea Utile, care contine butonul „Curăță fotografii orfane” pentru ștergerea fotografiilor rămase din versiuni mai vechi.',
    ],
  ),

  WhatsNewEntry(
    version: 'v0.0.86',
    dateLabel: '28 martie 2026',
    changes: [
      'A fost introdusă secțiunea „Ce este nou”, afișată la prima deschidere după actualizare.',
      'Secțiunea „Ce este nou” este disponibilă și din „Despre aplicație”.',
      'A fost adăugată afișarea versiunii Privacy Policy în aplicație.',
      'Reacceptarea Privacy Policy este controlată prin versiunea politicii.',
      'Fluxul de actualizare din Google Play a fost ajustat.',
      'Dialogul Setări a fost ajustat pentru afișare mai bună pe telefon și tabletă.',
      'Butonul „Check for Update” a fost compactat și repoziționat pentru o afișare mai curată.',
    ],
  ),

  WhatsNewEntry(
    version: 'v0',
    dateLabel: 'Versiune de bază',
    changes: [
      'Aici apar modificările făcute cu fiecare update începând cu update-ul 0.0.86.',
      'Versiunea inițială a istoricului What\'s New.',
    ],
  ),

  // <<< SFÂRȘIT ZONĂ INSERARE VERSIUNE NOUĂ <<<
];

String buildWhatsNewEntryText(WhatsNewEntry entry) {
  final buffer = StringBuffer();

  buffer.writeln('${entry.version} — ${entry.dateLabel}');
  for (final change in entry.changes) {
    buffer.writeln('- $change');
  }

  return buffer.toString().trimRight();
}

String buildWhatsNewOlderEntriesText() {
  if (whatsNewEntries.length <= 1) {
    return '';
  }

  final buffer = StringBuffer();

  for (int i = 1; i < whatsNewEntries.length; i++) {
    final entry = whatsNewEntries[i];

    buffer.writeln('${entry.version} — ${entry.dateLabel}');
    for (final change in entry.changes) {
      buffer.writeln('- $change');
    }

    if (i < whatsNewEntries.length - 1) {
      buffer.writeln();
    }
  }

  return buffer.toString().trimRight();
}

String buildWhatsNewText() {
  final buffer = StringBuffer();

  for (int i = 0; i < whatsNewEntries.length; i++) {
    final entry = whatsNewEntries[i];

    buffer.writeln('${entry.version} — ${entry.dateLabel}');
    for (final change in entry.changes) {
      buffer.writeln('- $change');
    }

    if (i < whatsNewEntries.length - 1) {
      buffer.writeln();
    }
  }

  return buffer.toString().trimRight();
}