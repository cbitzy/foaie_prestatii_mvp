// /lib/privacy_policy_text.dart

const String privacyPolicyTitle = 'Privacy Policy – Program Prestatii Mecanic';
const String privacyPolicyEffectiveDate =
    'Data intrării în vigoare: 28.03.2026';
const String privacyPolicyDeveloper =
    'Creator/Dezvoltator: bitzy - (în măsura aplicabilă)';
const String privacyPolicyContact = 'Contact: cbitzy0220@gmail.com';
const String privacyPolicyVersion = 'v2';
const String privacyPolicyAcceptedKey = 'privacy_policy_accepted';
const String privacyPolicyAcceptedVersionKey = 'privacy_policy_accepted_version';
const String privacyPolicyAcceptedAtKey = 'privacy_policy_accepted_at';
const String privacyPolicyText = '''
1) Rezumat
Program Prestatii Mecanic este conceput astfel încât datele utilizatorului să fie procesate în principal local, pe dispozitiv. Aplicația nu transmite către serverele dezvoltatorului datele introduse de utilizator și nu include module de analytics, advertising, profilare comportamentală, crash reporting de tip terț sau servicii similare.

În configurația actuală, aplicația nu declară permisiunea Android INTERNET. Totuși, dacă aplicația este instalată/distribuită prin Google Play, anumite funcții de platformă (de exemplu verificarea actualizărilor prin Google Play) pot implica schimburi tehnice între dispozitiv, serviciile Google Play și infrastructura furnizorilor respectivi, fără ca aceste schimburi să fie servere controlate de dezvoltator.

2) Cine este operatorul / cine răspunde de această politică
Operatorul/creatorul/dezvoltatorul aplicației este persoana indicată mai sus la secțiunea de identificare și contact.

Pentru întrebări, solicitări sau sesizări privind protecția datelor și această politică, utilizatorul poate folosi adresa de contact menționată mai sus.

3) Ce date poate procesa aplicația local pe dispozitiv
Aplicația poate procesa local, pe dispozitiv, în funcție de modul în care este folosită, următoarele categorii de date:
- numele mecanicului introdus de utilizator;
- date de configurare și preferințe locale ale aplicației;
- date operaționale introduse de utilizator în aplicație, inclusiv servicii, segmente, date calendaristice, ore, observații, norme lunare, zile festive configurate, totaluri și alte înregistrări necesare funcționării aplicației;
- fotografii adăugate de utilizator în secțiunile aplicației care permit acest lucru;
- text extras local din fotografii/imagine prin OCR local pe dispozitiv;
- date incluse de utilizator în fișierele de backup sau restaurate din acestea.

Aceste date pot constitui, după caz, date cu caracter personal dacă utilizatorul introduce informații care identifică direct sau indirect o persoană.

4) Ce NU face aplicația
Aplicația nu transmite către serverele dezvoltatorului datele utilizatorului.
Aplicația nu vinde date și nu partajează datele utilizatorului cu rețele de publicitate.
Aplicația nu folosește Firebase Analytics, AdMob, Crashlytics sau SDK-uri similare pentru analytics, reclame ori crash reporting.
Aplicația nu creează conturi de utilizator și nu oferă autentificare cu cont propriu.

5) Scopurile prelucrării locale
Datele sunt procesate local pe dispozitiv exclusiv pentru:
- funcționarea aplicației și afișarea informațiilor introduse de utilizator;
- salvarea și editarea serviciilor, segmentelor și calculelor asociate;
- memorarea numelui mecanicului și a altor setări locale;
- generarea, salvarea, selectarea, restaurarea și, la cererea utilizatorului, ștergerea backup-urilor;
- adăugarea, decuparea, redenumirea, previzualizarea și ștergerea fotografiilor asociate unor înregistrări;
- extragerea locală de text din imagini prin OCR, atunci când utilizatorul folosește această funcție;
- verificarea disponibilității actualizărilor prin Google Play, dacă aplicația este instalată din Google Play și funcția este disponibilă.

6) Temeiul prelucrării
În măsura în care legislația privind protecția datelor este aplicabilă, prelucrarea descrisă în această politică se bazează, după caz, pe:
- executarea funcțiilor solicitate de utilizator în cadrul aplicației;
- interesul legitim de a asigura funcționarea tehnică, integritatea, securitatea și continuitatea aplicației;
- acțiunea voluntară a utilizatorului atunci când acesta introduce date, creează/restaurează backup-uri, adaugă fotografii sau folosește funcțiile disponibile.

7) Stocare locală și locațiile în care pot exista datele
În versiunea actuală, aplicația folosește stocare locală pe dispozitiv, inclusiv:
- spațiul intern al aplicației pentru date locale și fișiere necesare funcționării aplicației;
- stocare locală de tip preferințe/setări pentru anumite date precum numele mecanicului, acceptarea politicii și alte setări tehnice;
- directoare/fișiere locale alese sau folosite pentru operațiunile de backup și restore;
- directoare locale ale aplicației pentru fotografiile adăugate în fluxurile care permit atașarea de imagini.

8) Permisiuni și acces la fișiere / media / imagini
Aplicația poate solicita sau utiliza, în funcție de versiunea Android, de setările dispozitivului și de acțiunea utilizatorului:
- acces la stocare / media / fișiere pentru crearea și restaurarea backup-urilor;
- acces la directoare sau fișiere selectate de utilizator pentru import/export backup;
- acces la imagini selectate de utilizator din galerie;
- deschiderea camerei prin componentele sistemului pentru capturarea unei imagini, dacă utilizatorul alege această funcție;
- prelucrarea locală a imaginilor selectate/adăugate de utilizator în vederea decupării și OCR.

În versiunea actuală sunt declarate permisiuni Android legate de accesul la stocare, inclusiv pentru scenarii în care sistemul poate cere acces extins la fișiere, exclusiv pentru funcțiile de backup/restore și gestionarea fișierelor alese de utilizator.

9) Backup și restore
Aplicația oferă funcții de backup și restore local, la cererea utilizatorului.

Backup-ul poate include, în funcție de opțiunile alese de utilizator:
- zile festive;
- servicii și date asociate acestora;
- norme lunare;
- numele mecanicului.

Backup-ul este salvat local pe dispozitiv, într-o locație implicită sau într-un director ales de utilizator. Utilizatorul controlează în mod direct crearea, alegerea locației și ștergerea fișierelor de backup.

Important: în versiunea actuală, dacă utilizatorul include serviciile în backup și fișierele foto asociate există local la momentul creării backup-ului, fișierul de backup poate include și conținutul acestor fotografii, împreună cu datele și referințele/path-urile asociate înregistrărilor. La restaurare, aplicația poate recrea local aceste fișiere foto din datele incluse în backup. Dacă anumite fișiere foto nu mai există local, nu pot fi citite sau nu sunt disponibile la momentul creării backup-ului, ele pot lipsi din backup și, în consecință, nu vor putea fi restaurate ulterior.

10) OCR și fotografii
Aplicația poate permite adăugarea de fotografii și prelucrarea lor locală pe dispozitiv, inclusiv decupare și recunoaștere de text (OCR), pentru a extrage anumite informații utile utilizatorului.

OCR-ul este efectuat local pe dispozitiv în cadrul aplicației. Textul extras nu este trimis către serverele dezvoltatorului.

Fotografiile și rezultatele OCR depind de imaginea furnizată, calitatea acesteia, iluminare, claritate, orientare și limitările tehnologice. Dezvoltatorul nu garantează exactitatea OCR.

11) Google Play, Android și alte servicii de platformă
Dacă aplicația este instalată, actualizată sau utilizată prin Google Play ori pe un dispozitiv Android, anumite date tehnice pot fi colectate sau procesate independent de aplicație de către Google, Google Play, producătorul dispozitivului, furnizorul sistemului de operare ori alți furnizori de platformă. Aceste prelucrări pot privi, de exemplu, distribuirea aplicației, verificarea actualizărilor, instalarea, actualizarea, backup-ul la nivel de sistem, sincronizarea, securitatea platformei sau funcționarea serviciilor sistemului.

Aplicația nu controlează aceste prelucrări. Pentru ele se aplică politicile și responsabilitatea furnizorilor respectivi.

12) Backup/restore la nivel de sistem Android
În funcție de versiunea Android, setările dispozitivului, contul utilizatorului și comportamentul sistemului de operare, anumite date locale ale aplicației pot fi incluse în mecanismele de backup/restore oferite de Android sau de serviciile asociate contului dispozitivului.

Aceste mecanisme sunt operate de furnizorii platformei și nu sunt controlate direct de dezvoltator. Utilizatorul trebuie să verifice separat setările Android/Google relevante pentru backup, restore, transfer pe alt dispozitiv și sincronizare.

13) Partajarea datelor
Aplicația nu partajează în mod activ datele utilizatorului cu terți în scopuri comerciale și nu vinde date.

Datele pot ajunge la terți numai în măsura în care utilizatorul alege singur să exporte, să salveze, să mute, să sincronizeze, să trimită sau să stocheze fișierele rezultate (de exemplu backup-uri) în servicii, aplicații, foldere partajate sau medii controlate de alți furnizori.

14) Păstrarea datelor / retenție / ștergere
Datele locale rămân pe dispozitiv până când sunt șterse de utilizator, înlocuite, resetate, dezinstalate sau eliminate de sistemul de operare, după caz.

În mod concret, în versiunea actuală:
- datele introduse în aplicație rămân stocate local până la modificarea sau ștergerea lor ori până la resetarea/dezinstalarea aplicației;
- numele mecanicului și anumite preferințe locale rămân stocate local până la modificare, resetare sau dezinstalare;
- fișierele de backup rămân în locația în care au fost salvate până la ștergerea lor manuală de către utilizator sau de către sistem;
- fotografiile locale salvate de aplicație rămân pe dispozitiv până când sunt șterse din aplicație, eliminate prin resetare/dezinstalare sau în alt mod de sistem/ utilizator, după caz.

15) Securitate
Aplicația este proiectată astfel încât datele să rămână în principal local pe dispozitiv. Cu toate acestea, niciun sistem nu poate fi garantat ca fiind absolut sigur.

Securitatea datelor depinde și de:
- parola/PIN-ul/blocarea ecranului dispozitivului;
- criptarea dispozitivului;
- securitatea contului Google sau a altor conturi folosite pe dispozitiv;
- aplicațiile, serviciile și mediile de stocare alese de utilizator;
- accesul fizic la dispozitiv și la fișierele exportate.

Dacă utilizatorul salvează backup-uri sau alte fișiere în spații accesibile altor aplicații, pe carduri externe, în servicii cloud, în foldere partajate sau pe alte medii externe, securitatea și confidențialitatea acelor copii depind și de setările și politicile respectivelor medii.

16) Drepturile utilizatorului
În măsura în care legislația aplicabilă îi conferă astfel de drepturi, utilizatorul poate avea dreptul la informare, acces, rectificare, ștergere, restricționare, opoziție, portabilitate și dreptul de a depune plângere la autoritatea competentă de protecție a datelor.

Deoarece aplicația nu transmite în mod obișnuit către serverele dezvoltatorului datele introduse de utilizator și majoritatea prelucrării are loc local pe dispozitiv, exercitarea practică a unor drepturi se realizează în principal prin controlul direct al utilizatorului asupra dispozitivului și datelor sale, inclusiv prin modificare, ștergere, resetare, dezinstalare și administrarea fișierelor de backup.

Pentru întrebări privind această politică sau prelucrarea datelor în contextul aplicației, utilizatorul poate contacta dezvoltatorul la adresa indicată mai sus. Utilizatorul poate, de asemenea, să se adreseze autorității competente de protecție a datelor din jurisdicția sa.

17) Confidențialitatea copiilor
Aplicația nu este destinată în mod special copiilor sub 13 ani și nu urmărește colectarea intenționată de date de la copii.

18) Declarație de declinare a răspunderii
Aplicația este oferită „ca atare” (as-is), în măsura permisă de lege.

Creatorul/dezvoltatorul nu garantează că aplicația va funcționa fără erori, fără întreruperi sau fără incompatibilități și nu garantează exactitatea, corectitudinea, completitudinea ori disponibilitatea permanentă a datelor, calculelor, OCR-ului sau a altor rezultate generate în cadrul aplicației.

Utilizatorul este responsabil pentru verificarea datelor introduse, pentru păstrarea propriilor copii de siguranță și pentru utilizarea prudentă a aplicației. În măsura maximă permisă de lege, dezvoltatorul nu răspunde pentru pierderi de date, indisponibilități, erori, incompatibilități, rezultate inexacte sau orice daune directe/indirecte rezultate din instalarea, utilizarea, imposibilitatea utilizării aplicației ori din utilizarea serviciilor și infrastructurilor terților (inclusiv Google Play, Android, cloud, sisteme de backup sau alte medii alese de utilizator).

19) Modificări ale politicii
Această politică poate fi actualizată periodic. Versiunea afișată în aplicație este versiunea curentă a politicii pentru versiunea respectivă a aplicației, cu excepția cazului în care este indicat altfel.

Ultima actualizare: 04 aprilie 2026

20) Contact
cbitzy0220@gmail.com
''';
