@ECHO OFF
:: Copies this template into a sibling folder and renames everything in it.
:: Usage: Create-Ng ConsideraWeb.Ng.Some.Name app title port
::   name   the new folder and repo name; the folder is created next to this template
::   app    the URL segment the app is served under (/some-name/)
::   title  the browser tab title
::   port   the ng serve port
:: Anything listed in .templateignore is left out. The new folder gets a fresh git repo (master) with .githooks
:: enabled and its packages installed; nothing is committed.
SETLOCAL

IF "%~4"=="" (
    ECHO Usage: Create-Ng ConsideraWeb.Ng.Some.Name app title port
    ECHO Example: Create-Ng ConsideraWeb.Ng.Some.Name some-name "ConsideraWeb Some Name" 4200
    EXIT /B 1
)
SET "Name=%~1"
SET "App=%~2"
SET "Title=%~3"
SET "Port=%~4"

:: The npm/Angular project name: the folder name lowercased, dots turned into dashes (ConsideraWeb.Ng.Foo -> consideraweb-ng-foo).
SET "Project=%Name:.=-%"
CALL :Lower Project

:: Template is this script's folder; Target is a sibling folder named after the new project.
:: The FOR loops just turn each into a clean full path, with the ".." resolved and no trailing backslash.
FOR %%I IN ("%~dp0.") DO SET "Template=%%~fI"
FOR %%I IN ("%~dp0..\%Name%") DO SET "Target=%%~fI"
IF EXIST "%Target%" (
    ECHO %Target% already exists.
    EXIT /B 1
)

:: Turn .templateignore into robocopy's skip lists: names ending in / go to /XD (folders), the rest to /XF (files).
SET "XD="
SET "XF="
FOR /F "usebackq eol=# delims=" %%L IN ("%Template%\.templateignore") DO CALL :Ignore "%%L"

:: Copy the template into the target, skipping the ignored names wherever they appear.
::   /E                       include all subfolders, even empty ones
::   /NFL /NDL /NJH /NJS /NP  no file list, folder list, header, summary or progress (silences the log)
:: Robocopy exit codes 0-7 mean success; 8 or higher means something failed to copy.
ROBOCOPY "%Template%" "%Target%" /E /XD %XD% /XF %XF% /NFL /NDL /NJH /NJS /NP >NUL
IF ERRORLEVEL 8 EXIT /B 1

:: Swap the template's own names for the new ones in every text file (images and fonts are skipped).
:: Each pair below is (text in the template, replacement); they read the variables above through $env:.
:: SyncNg.ps1 uses the same pairs, so keep the two in step.
:: package-lock.json only gets the project-name swap, because its hashes could happen to contain the other strings.
:: Files are rewritten only when something changed, as UTF-8 without a BOM.
POWERSHELL -NoProfile -Command ^
    "$rules = @(('ConsideraWeb.Ng.Template', $env:Name), ('consideraweb-ng-template', $env:Project), ('ConsideraWeb Template', $env:Title), ('/template/', \"/$env:App/\"), ('4299', $env:Port));" ^
    "Get-ChildItem -LiteralPath $env:Target -Recurse -File | Where-Object { $_.Name -notmatch '\.(ico|png|jpe?g|gif|woff2?|ttf|eot)$' } | ForEach-Object {" ^
    "  $lock = $_.Name -eq 'package-lock.json';" ^
    "  $before = [IO.File]::ReadAllText($_.FullName); $after = $before;" ^
    "  foreach ($r in $rules) { if (-not $lock -or $r[0] -eq 'consideraweb-ng-template') { $after = $after.Replace($r[0], $r[1]) } }" ^
    "  if ($after -cne $before) { [IO.File]::WriteAllText($_.FullName, $after); '  renamed in ' + $_.FullName.Substring($env:Target.Length + 1) }" ^
    "}"
IF ERRORLEVEL 1 EXIT /B 1

:: Start a fresh repo on master, point git at the shared hooks in .githooks, and install packages.
:: npm is itself a batch file, so it needs CALL or this script would end when it does.
git -C "%Target%" init -q -b master || EXIT /B 1
git -C "%Target%" config core.hooksPath .githooks || EXIT /B 1
PUSHD "%Target%"
CALL npm run all:i
IF ERRORLEVEL 1 (POPD & EXIT /B 1)
POPD

ECHO.
ECHO Created %Target%
ECHO   project: %Project%
ECHO   url:     https://local.considera.dev:%Port%/%App%/home
ECHO   title:   %Title%
ECHO Next: work through TODO.md.
EXIT /B 0

:: Adds one .templateignore entry (%1) to XD or XF.
:Ignore
SET "Entry=%~1"
IF "%Entry:~-1%"=="/" (SET XD=%XD% "%Entry:~0,-1%") ELSE (SET XF=%XF% "%Entry%")
EXIT /B

:: Lowercases the variable named by %1. SET's find-and-replace ignores case, so replacing each letter with itself lowercases it.
:Lower
FOR %%L IN (a b c d e f g h i j k l m n o p q r s t u v w x y z) DO CALL SET "%1=%%%1:%%L=%%L%%"
EXIT /B
