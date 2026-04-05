# TODO

## Must Fix Now

- [ ] Restrange listarea si stergerea backup-urilor la fisiere validate semantic, nu la orice `.json`.
    - Fisier(e): `lib/screens/setari/actiune_backup_aplicatie.dart`
    - Context: filtrul actual din `_listBackupFilesInDir` accepta practic orice `.json`, iar dialogul de stergere opereaza direct pe lista respectiva.

- [ ] Unifica validarea formatului de backup intr-un helper comun.
    - Fisier(e): `lib/screens/setari/actiune_backup_aplicatie.dart`, `lib/screens/setari/actiune_restore_aplicatie.dart`
    - Context: semnatura si schema sunt duplicate, iar validarea reala se face doar in flow-ul de restore.

- [ ] Aliniaza calculul de overtime/norma cu aceeasi normalizare folosita in sumarul lunar.
    - Fisier(e): `lib/screens/afisare_program/afisare_program_screen.dart`, `lib/screens/afisare_program/sumar_program.dart`
    - Context: totalul lunar foloseste segmente normalizate, dar bucket-urile norma/suplimentare folosesc segmente brute.

## Should Fix Soon

- [ ] Extrage `mergeMidnightSlices` intr-un utilitar comun.
    - Fisier(e): `lib/screens/afisare_program/afisare_program_screen.dart`, `lib/screens/Adauga_modifica_serviciu/adauga_modifica_serviciu.dart`, `lib/screens/monthly_report_by_train_screen.dart`

- [ ] Extrage intr-un helper comun prioritatile de normalizare overlap.
    - Fisier(e): `lib/screens/afisare_program/afisare_program_screen.dart`, `lib/screens/Adauga_modifica_serviciu/adauga_serviciu.dart`

- [ ] Muta calculul `computeNormOvertimeBuckets` din widget intr-un helper pur.
    - Fisier(e): `lib/screens/afisare_program/sumar_program.dart`

- [ ] Corecteaza comentariile interne care nu mai corespund comportamentului real.
    - Fisier(e): `lib/screens/setari/actiune_backup_aplicatie.dart`

## Cleanup Later

- [ ] Decide explicit ce faci cu `MonthlyNormsEvents`.
    - Fisier(e): `lib/services/monthly_norms_events.dart`, `lib/screens/setari/norma_lunara.dart`
    - Context: exista emitere de evenimente, dar nu s-au identificat subscriberi vizibili in `lib`.

- [ ] Decide explicit ce faci cu `OcrService`.
    - Fisier(e): `lib/services/ocr_service.dart`
    - Context: serviciul exista, dar nu s-au identificat apeluri vizibile in `lib`.

- [ ] Decide explicit ce faci cu method channel-ul Android pentru uninstall.
    - Fisier(e): `android/app/src/main/kotlin/ro/bitzy/program_salvare_prestatii_mecanic/MainActivity.kt`
    - Context: `requestUninstall` exista, dar nu s-a identificat apel Dart vizibil in fisierele citite.

- [ ] Elimina sau conecteaza parametrii ramasi nefolositi.
    - Fisier(e): `lib/screens/Adauga_modifica_serviciu/adauga_segment.dart`
    - Context: `isFirstInService` este trecut mai departe, dar nu s-a identificat utilizare efectiva.

## Teste De Adaugat Prima Data

- [ ] Teste pentru validarea backup-urilor.
    - Tinta: helper-ul comun de validare extras din flow-ul de restore.
    - Cazuri: backup valid primar, backup valid legacy, fisier fara semnatura, schema incompatibila.

- [ ] Teste pentru filtrarea/listarea fisierelor de backup.
    - Tinta: logica de listare din backup/restore.
    - Cazuri: listeaza doar backup-uri valide, ignora alte `.json`, stergerea selectiva nu vede alte fisiere.

- [ ] Teste pentru `mergeMidnightSlices`.
    - Tinta: helper comun nou.
    - Cazuri: lipire corecta la `00:00`, nelipire la `trainNo` diferit, nelipire la foaie diferita, nelipire la campuri avansate diferite.

- [ ] Teste pentru invariantul fara overlap.
    - Tinta: validarea din `lib/screens/Adauga_modifica_serviciu/adauga_serviciu.dart`
    - Cazuri: overlap intern respins, atingere la limita acceptata, overlap peste alt serviciu respins, editarea propriului serviciu permisa.

- [ ] Teste pentru recalcul lunar.
    - Tinta: `lib/services/recalculator.dart`
    - Cazuri: `#svc` reconstruit corect din `#seg`, totaluri lunare corecte, overtime corect pe norma manuala si pe norma automata.

- [ ] Test de consistenta sumar vs overtime buckets.
    - Tinta: sumarul lunar si calculul bucket-urilor de overtime.
    - Cazuri: pe date curate `totalWorkedMin == normBuckets + overtimeBuckets`; pe date cu overlap artificial exista un test de regresie pentru comportamentul decis.

- [ ] Teste pentru migrarea DST martie 2026.
    - Tinta: `lib/services/migrations/dst_march_2026_split_fix_migration.dart`
    - Cazuri: segmente afectate reunite, segmente neafectate pastrate, `serviceMonth` si `serviceName` pastrate.

- [ ] Teste pentru naming de serviciu.
    - Tinta: `lib/screens/Adauga_modifica_serviciu/nume_serviciu.dart`
    - Cazuri: cu trenuri, fara trenuri, `odihna` exclusa corect, `alte` cu descriere corecta.

## Ordine Recomandata De Lucru

1. backup validation + backup filtering
2. `mergeMidnightSlices`
3. tests no-overlap
4. tests recalculator
5. consistency test sumar/overtime
6. cleanup code neconectat