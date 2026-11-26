# Ställa i ordning bibliotekets kioskdator

Så här gör du en Windows-dator i biblioteket till en obemannad lånestation.
Eleverna ska bara kunna blippa sitt kort och sina böcker. De ska inte komma åt
något annat, och datorn ska inte låsa sig eller somna.

**Det här behövs:**

- Windows 10/11 **Education, Enterprise eller IoT Enterprise**. Shell Launcher
  finns inte i Home eller Pro.
- Ett administratörskonto på datorn.
- Appen `skolpunkten.exe` med hela sin mapp. Se [Hämta appen](../README.md#hämta-appen).
- Kortläsaren, t.ex. ACS ACR122 (PC/SC) eller en läsare som skriver som ett
  tangentbord.
- Ett lärarkonto i Skolpunkten.

Räkna med ungefär 30 minuter. Gör stegen i den här ordningen. När Shell
Launcher har slagits på i steg 5 har kioskkontot inget skrivbord längre, så det
som måste göras på kontot görs före det.

> Hanterar IT datorn i **Intune**? Då kan IT göra steg 1 och 5–7 med en
> kioskprofil (Enheter → Konfiguration → Kiosk → Enkelappskiosk med Win32-app).
> Steg 3 och 4 behöver du fortfarande göra.

---

## 1. Skapa kioskkontot

Logga in som administratör. Kör det här i PowerShell som administratör:

```powershell
$pw = Read-Host -AsSecureString "Lösenord för bibliotek"
New-LocalUser -Name "bibliotek" -Password $pw -FullName "Bibliotek" -PasswordNeverExpires
Add-LocalGroupMember -Group "Users" -Member "bibliotek"
```

Kontot ska vara ett **standardkonto**, inte administratör. Skriv upp lösenordet.
Det behövs i steg 6.

## 2. Installera appen

Använd installationsprogrammet eller kopiera **hela** mappen
`build\windows\x64\runner\Release\` till:

```
C:\Program Files\Skolpunkten Bibliotek\
```

Det räcker inte att kopiera bara `skolpunkten.exe`. Appen behöver DLL-filerna
och mappen `data` som ligger bredvid.

## 3. Ställ in Windows på kioskkontot

Sätt i kortläsaren. Logga ut och logga in som **bibliotek**.

**Lås inte datorn när den väcks:**

- **Inställningar → Konton → Inloggningsalternativ**
  - "Om du har varit borta, när ska Windows kräva att du loggar in igen?": välj **Aldrig**.
  - **Dynamiskt lås**: av.
- **Skärmsläckare** (sök på "skärmsläckare" i Start): välj **(Ingen)** och
  avmarkera "Visa inloggningsskärmen vid återupptagning".

## 4. Ställ in appen

Fortfarande inloggad som **bibliotek**:

1. Starta `C:\Program Files\Skolpunkten Bibliotek\skolpunkten.exe`.
2. Logga in med ditt lärarkonto. Webbläsaren öppnas för inloggningen.
3. Gå till **Inställningar**.
   - **USB-läsare (PC/SC):** läsaren ska synas, t.ex. "ACS ACR122 0". Syns den
     inte, tryck på uppdatera (↻). Sitter bara en läsare i ansluts den av sig själv.
   - **Testa läsaren:** blippa ett kort. Det ska stå "Läst: …".
4. **Inställningar → Kioskläge:**
   1. Välj en **PIN-kod** med minst 4 siffror, skriv den en gång till och tryck **Spara**.
      Skriv upp koden och förvara den säkert.
   2. Slå på **Starta i kioskläge**.
   3. Tryck **Lås datorn nu** och kontrollera att det fungerar: blippa ett kort,
      prova Windows-tangenten och Alt+Tab. Inget ska hända.
   4. Lås upp med **Lås upp** nere till vänster och PIN-koden, och välj **Avsluta appen**.

Inställningarna sparas för Windows-kontot `bibliotek`. Därför görs det här
på det kontot och inte på administratörskontot.

Logga ut från `bibliotek` och logga in som administratör igen.

## 5. Gör appen till det enda på kioskkontot (Shell Launcher)

I PowerShell som administratör:

```powershell
# Slå på Shell Launcher (kan kräva omstart)
Enable-WindowsOptionalFeature -Online -FeatureName Client-EmbeddedShellLauncher -All

# Appen blir skal för kontot bibliotek. 0 = starta om appen om den stängs.
$sid = (Get-LocalUser -Name "bibliotek").SID.Value
$ShellLauncher = [wmiclass]"\\localhost\root\standardcimv2\embedded:WESL_UserSetting"
$ShellLauncher.SetCustomShell($sid, "C:\Program Files\Skolpunkten Bibliotek\skolpunkten.exe", ($null), ($null), 0)
$ShellLauncher.SetEnabled($true)
```

Om `Enable-WindowsOptionalFeature` ber om omstart: starta om och kör de sista
fyra raderna igen.

Kontot `bibliotek` har sedan inget skrivbord, inget aktivitetsfält och ingen
Utforskaren. Administratörskontot fungerar som vanligt.

## 6. Logga in automatiskt

1. Ladda ned **Autologon** från Microsoft Sysinternals:
   <https://learn.microsoft.com/sysinternals/downloads/autologon>
2. Kör `Autologon64.exe` och fyll i användarnamn `bibliotek`, domän (datornamnet)
   och lösenordet från steg 1. Tryck **Enable**.

Datorn startar nu rakt in i appen, även efter strömavbrott och Windows-uppdateringar.

## 7. Låt datorn vara vaken och läsaren ha ström

I PowerShell som administratör. Det här gäller hela datorn:

```powershell
# Skärmen släcks aldrig, aldrig viloläge
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# Kräv inte inloggning när datorn vaknar
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0

# Stäng av USB-selektiv avstängning, så att läsaren inte förlorar strömmen
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

powercfg /setactive SCHEME_CURRENT
```

Är det en bärbar dator: kör samma rader med `-dc`/`setdcvalueindex` i stället
för `-ac`/`setacvalueindex`, eller låt den alltid sitta i laddaren.

**Enhetshanteraren:** öppna kortläsaren (under *Smartkortsläsare*) och varje
*USB-rotnav*. Avmarkera "Tillåt att datorn stänger av enheten för att spara
energi" på fliken **Energihantering**.

Vill du hellre att skärmen släcks för att spara ström? Sätt
`monitor-timeout-ac` till t.ex. `30` för 30 minuter. Datorn låses ändå inte,
men skärmen tänds först när någon rör musen eller tangentbordet. Ett blipp
tänder den inte.

## 8. Gör Ctrl+Alt+Del-menyn snålare

Ctrl+Alt+Del kan inget program stänga av. Öppna `gpedit.msc` och gå till
**Användarkonfiguration → Administrativa mallar → System → Alternativ för Ctrl+Alt+Del**.
Sätt följande till **Aktiverad**:

- Ta bort Aktivitetshanteraren
- Ta bort Byt lösenord
- Ta bort Logga ut

Policyn gäller alla konton på datorn, även administratören. Det går fortfarande
att byta användare för att komma till administratörskontot.

## 9. Kontrollera

Starta om datorn och vänta. Det här ska hända:

- [ ] Datorn loggar in som `bibliotek` av sig själv.
- [ ] Appen startar i helskärm och i kioskläge, med utlåningen.
- [ ] Ett blipp med ett kort visar låntagaren.
- [ ] Windows-tangenten, Alt+Tab och Alt+F4 gör ingenting.
- [ ] Efter 15 minuter utan någon vid datorn är den fortfarande igång och olåst.

---

## Felsökning

| Problem | Gör så här |
| --- | --- |
| **"Ingen läsare hittades"** | Kontrollera att läsaren sitter i. Lås upp appen, gå till Inställningar och tryck på uppdatera. Se också att USB-strömsparandet är avstängt (steg 7). |
| **Datorn låser sig ändå** | IT har troligen en gruppolicy som tvingar fram låsning. Kontrollera med `reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v InactivityTimeoutSecs`. Finns värdet behöver IT göra ett undantag för datorn. |
| **Appen visar inloggningen** | Lärarens inloggning har gått ut. Då släpps låsningen så att du kan logga in i webbläsaren, och appen låser sig igen efteråt. |
| **Glömd PIN-kod** | Logga in som administratör. Ta bort raden `flutter.kiosk.pinHash` ur `C:\Users\bibliotek\AppData\Roaming\se.skolpunkten\Skolpunkten Bibliotek\shared_preferences.json`. Välj en ny kod när appen startar. |
| **Komma åt administratörskontot** | Ctrl+Alt+Del → **Byt användare**. |

## Uppdatera appen

1. Ctrl+Alt+Del → Byt användare och logga in som administratör.
2. Avsluta appen om den körs (Aktivitetshanteraren → `skolpunkten.exe` → Avsluta aktivitet).
3. Ersätt innehållet i `C:\Program Files\Skolpunkten Bibliotek\` med den nya
   versionen, eller kör det nya installationsprogrammet.
4. Starta om datorn.

Inställningar, PIN-kod och läsarval finns kvar. De sparas på kontot `bibliotek`
och inte i programmappen.

## Ta bort kioskläget

I PowerShell som administratör:

```powershell
$sid = (Get-LocalUser -Name "bibliotek").SID.Value
$ShellLauncher = [wmiclass]"\\localhost\root\standardcimv2\embedded:WESL_UserSetting"
$ShellLauncher.RemoveCustomShell($sid)
```

Stäng av automatisk inloggning i Autologon (**Disable**) och återställ
policyerna i `gpedit.msc` till **Inte konfigurerad**. I appen: lås upp och stäng
av **Starta i kioskläge**.
