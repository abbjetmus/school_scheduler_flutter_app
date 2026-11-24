# Skolpunkten Bibliotek

Windows-appen som står i skolbiblioteket. En lärare loggar in en gång. Sedan
lånar och lämnar elever och lärare böcker genom att **blippa**:

1. Blippa **lånekortet** — personen blir låntagare och ser sina lån.
2. Blippa **böckerna** — en bok som finns lånas ut, en bok som är utlånad lämnas tillbaka.
3. Efter en stund utan blipp (45 s, går att ändra) släpps låntagaren.

Böckerna läggs in i Skolpunkten på webben (Bibliotek → Böcker: ISBN-uppslag,
kamera, CSV-import). I appen kopplas RFID-etiketter till exemplaren
(Böcker) och kort till personer (Lånekort). Allt sparas i Skolpunkten
(school-scheduler-pb, collections `libraryTitles`, `libraryCopies`,
`libraryLoans`, `userCards`); utlåningen går via `/api/library/*`.

Utan RFID fungerar biblioteket ändå: eleven lånar med knappen i webben, eller
så skannas bokens ISBN-streckkod här.

## Läsare

**Läsaren ni redan har** (Okeeyseda NFC-läsare, den som användes för närvaron,
se `docs/NFC_READER.md`) fungerar direkt. Den skriver kortets nummer som ett
tangentbord och trycker Enter, via USB-kabel eller Bluetooth. Appen fångar det
utan inställningar ("Läsare som skriver som ett tangentbord" är på som standard).

- **Lånekort:** elevernas kort (13,56 MHz MIFARE eller 125 kHz) läses som förut.
- **Böcker:** läsaren klarar enligt specen MIFARE-/IC-kort, inte ISO 15693
  (NXP ICODE), som vanliga biblioteksetiketter är. Appen använder bara
  etikettens nummer (UID), så etiketten behöver inte vara en biblioteksetikett:
  sätt **NFC-klistermärken av typen NTAG213 eller MIFARE Classic** i böckerna.
  De är billiga och läsaren läser dem. Prova först några av era befintliga
  etiketter, om skolan redan har sådana.
- Registrera kort och etiketter **med samma läsare** som används vid utlåningen,
  i webben eller appen. Läsare skriver ibland numret olika (hex eller decimalt),
  och då känns kortet inte igen.
- I Bluetooth-läge ska läsaren vara parad med datorn som ett tangentbord. Appen
  måste ha fokus, vilket den alltid har i kioskläget.

Andra läsare som fungerar:

| Läsare | Fungerar till | Kommentar |
| --- | --- | --- |
| Läsare som skriver som ett tangentbord (som Okeeyseda) | Det läsaren klarar | Ingen drivrutin. |
| PC/SC-läsare som klarar ISO 15693 och ISO 14443, t.ex. ACS ACR1552U | Riktiga biblioteksetiketter och kort | Bara om ni vill ha ISO 15693-etiketter. Ansluts under Inställningar. |
| RC522 (Arduino-läsaren) | Bara ISO 14443-kort | Inte kopplad till appen. |

Utan etiketter går det också: skanna bokens ISBN-streckkod (en streckkodsläsare
i tangentbordsläge fungerar på samma sätt), eller låna i webben.

## Lån, förlängning och påminnelser

- Lånetid, max antal lån, förlängning (standard 2 gånger) och e-postpåminnelser
  ställs in i Skolpunkten under Inställningar → Bibliotek.
- Förläng: låntagaren blippar sitt kort och trycker **Förläng** vid boken, eller
  förlänger under Mina lån i webben. Lärare förlänger under Lån.
- Påminnelser skickas automatiskt vardagar kl. 07 till den som har försenade
  böcker (ett mejl med alla, sedan en gång i veckan, högst fyra gånger). Under
  Utlåning → Försenade i webben finns "Skicka påminnelser nu".

## Kioskläge — så att elever inte kan gå ur appen

Under **Inställningar → Kioskläge**: välj en PIN-kod, slå på *Starta i
kioskläge* och tryck *Lås datorn nu*. Då gäller följande:

- Appen fyller skärmen, ligger överst och går inte att flytta, minimera eller stänga.
- Windows-tangenten, Alt+Tab, Alt+F4, Alt+Esc, Ctrl+Esc och Ctrl+Shift+Esc
  (Aktivitetshanteraren) är avstängda (`windows/runner/kiosk_mode.cpp`).
- Bara utlåningen visas. Ingen meny och ingen utloggning. Låntagaren kan inte
  väljas i en lista, och koder kan inte skrivas in för hand: man lånar bara med
  sitt eget kort.
- **Lås upp** (nere till vänster) frågar efter PIN-koden. Där går det också att avsluta appen.
- Har lärarens inloggning gått ut släpps låsningen, så att läraren kan logga in
  i webbläsaren. Efter inloggningen låser appen sig igen.

**Ctrl+Alt+Del kan inget program stänga av.** Därifrån kommer man åt att låsa
datorn, logga ut eller byta användare. Datorn låses helt med Windows egna
verktyg:

### Rekommenderat: eget kioskkonto med appen som skal

Det här kräver Windows 10/11 **Education, Enterprise eller IoT Enterprise**.
Skolans datorer brukar ha Education.

1. Skapa ett lokalt standardkonto (inte admin), t.ex. `bibliotek`.
2. Installera appen, t.ex. i `C:\Program Files\Skolpunkten Bibliotek\`.
3. Aktivera **Shell Launcher**: Kontrollpanelen → Program → Aktivera eller
   inaktivera Windows-funktioner → Device Lockdown → Shell Launcher.
4. Sätt appen som skal för kontot `bibliotek` (PowerShell som admin):

   ```powershell
   $sid = (Get-LocalUser -Name "bibliotek").SID.Value
   $ShellLauncher = [wmiclass]"\\localhost\root\standardcimv2\embedded:WESL_UserSetting"
   # 0 = starta om appen om den stängs
   $ShellLauncher.SetCustomShell($sid, "C:\Program Files\Skolpunkten Bibliotek\school_scheduler_flutter_app.exe", ($null), ($null), 0)
   $ShellLauncher.SetEnabled($true)
   ```

   Det finns då inget skrivbord, ingen aktivitetsfält och ingen Utforskaren för
   kontot. Stängs appen startar Windows om den.
5. Slå på automatisk inloggning för kontot (Sysinternals *Autologon*) så att
   datorn startar rakt in i biblioteket.
6. Gör det svårare via Ctrl+Alt+Del med gruppolicy (`gpedit.msc`, Användarkonfiguration →
   Administrativa mallar → System → Alternativ för Ctrl+Alt+Del): ta bort
   Aktivitetshanteraren, Byt lösenord och Logga ut.

Hanteras datorerna i **Intune** görs samma sak med en *Kiosk*-profil
(Enheter → Konfiguration → Kiosk → Enkelappskiosk med Win32-app) eller med
Shell Launcher-CSP.

Utan Education/Enterprise: lägg appen i kontots Autostart
(`shell:startup`), använd kioskläget i appen och gruppolicyerna i punkt 6.
Det stoppar elever som klickar runt, men inte någon som vet om Ctrl+Alt+Del →
Logga ut.

**Glömd PIN-kod:** logga in på datorn som admin och ta bort raden
`flutter.kiosk.pinHash` ur
`C:\Users\bibliotek\AppData\Roaming\se.skolpunkten\Skolpunkten Bibliotek\shared_preferences.json`.
Starta sedan appen och välj en ny kod.

## Hämta appen

Appen byggs på GitHub (`.github/workflows/build-windows.yml`, Windows-maskin i
GitHub Actions). Varje bygge ger två filer:

- `Skolpunkten-Bibliotek-setup-<version>.exe`: installationsprogram. Det
  installerar under `C:\Program Files\Skolpunkten Bibliotek`, skapar genvägar och
  kan lägga appen i Autostart.
- `Skolpunkten-Bibliotek-<version>.zip`: samma program utan installation.

**Hämta:**

- **Senaste bygget:** GitHub → *Actions* → *Build Windows* → senaste körningen →
  *Artifacts* längst ned. Filerna finns kvar i 30 dagar.
- **En version att behålla:** tagga den, så hamnar filerna under *Releases*:

  ```bash
  git tag v1.0.1
  git push origin v1.0.1
  ```

- **Mot en annan server:** *Actions* → *Build Windows* → *Run workflow*, och
  fyll i PocketBase-adressen.

Bygget körs automatiskt vid push till `main` när något i appen ändrats.
Programmet är inte signerat, så Windows kan visa "Windows skyddade datorn".
Välj *Mer information → Kör ändå*.

## Bygga själv (på Windows)

```powershell
flutter pub get
flutter build windows --release
# Mot en annan server:
flutter build windows --release --dart-define=PB_URL=http://127.0.0.1:8090
```

Appen hamnar i `build\windows\x64\runner\Release\`. Kopiera hela mappen.
Installationsprogrammet byggs med Inno Setup 6 från
`windows\installer\skolpunkten-bibliotek.iss`.

PocketBase-adressen ligger i `lib/core/pocketbase/pocketbase_client.dart`.
Microsoft- och Google-inloggningen är samma som i webben: PocketBase öppnar
webbläsaren och appen väntar på svaret. Flutter-versionen står i `.fvmrc` och
i arbetsflödet (3.41.5).
