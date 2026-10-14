@ECHO OFF
:: Copies this template into a sibling folder and renames everything in it.
:: Usage: create.bat ConsideraWeb.Ng.Some.Name app title port
::   name   the new folder and repo name; the folder is created next to this template
::   app    the URL segment the app is served under (/some-name/)
::   title  the browser tab title
::   port   the ng serve port
:: The new folder gets a fresh git repo (master) with .githooks enabled; nothing is committed or installed.
SETLOCAL

SET "Name=%~1"
IF NOT DEFINED Name (
    ECHO Usage: create.bat ConsideraWeb.Ng.Some.Name [app] [title] [port]
    ECHO Example: create.bat ConsideraWeb.Ng.Some.Name some-name "ConsideraWeb Some Name" 4200
    EXIT /B 1
)

SET "App=%~2"
IF NOT DEFINED App (
    ECHO Usage: create.bat ConsideraWeb.Ng.Some.Name [app] [title] [port]
    ECHO Example: create.bat ConsideraWeb.Ng.Some.Name some-name "ConsideraWeb Some Name" 4200
    EXIT /B 1
)

SET "Title=%~3"
IF NOT DEFINED Title (
    ECHO Usage: create.bat ConsideraWeb.Ng.Some.Name [app] [title] [port]
    ECHO Example: create.bat ConsideraWeb.Ng.Some.Name some-name "ConsideraWeb Some Name" 4200
    EXIT /B 1
)

SET "Port=%~4"
IF NOT DEFINED Port (
    ECHO Usage: create.bat ConsideraWeb.Ng.Some.Name [app] [title] [port]
    ECHO Example: create.bat ConsideraWeb.Ng.Some.Name some-name "ConsideraWeb Some Name" 4200
    EXIT /B 1
)

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

:: Copy the template into the target, leaving out git history, build output, installed packages and the template's own scripts.
::   /E                  include all subfolders, even empty ones
::   /XD ... /XF ...     skip these folder names / file names wherever they appear
::   /NFL /NDL /NJH /NJS /NP  no file list, folder list, header, summary or progress (silences the log)
:: Robocopy exit codes 0-7 mean success; 8 or higher means something failed to copy.
ROBOCOPY "%Template%" "%Target%" /E /XD .git .angular dist node_modules scripts /XF create.bat add-to-path.ps1 /NFL /NDL /NJH /NJS /NP >NUL
IF ERRORLEVEL 8 EXIT /B 1

:: Swap the template's own names for the new ones in every text file (images and fonts are skipped).
:: Each pair below is (text in the template, replacement); they read the variables above through $env:.
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

:: Start a fresh repo on master and point git at the shared hooks in .githooks.
git -C "%Target%" init -q -b master || EXIT /B 1
git -C "%Target%" config core.hooksPath .githooks || EXIT /B 1
npm run all:i || EXIT /B 1


:: Display the summary of the created project.
ECHO.
ECHO Created %Target%
ECHO   project: %Project%
ECHO   url:     /%App%/home
ECHO   title:   %Title%
ECHO   port:    %Port%
ECHO Next: work through TODO.md.
EXIT /B 0

:: Lowercases the variable named by %1. SET's find-and-replace ignores case, so replacing each letter with itself lowercases it.
:Lower
FOR %%L IN (a b c d e f g h i j k l m n o p q r s t u v w x y z) DO CALL SET "%1=%%%1:%%L=%%L%%"
EXIT /B

