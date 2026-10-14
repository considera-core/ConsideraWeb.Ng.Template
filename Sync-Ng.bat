@ECHO OFF
:: Steps through the template's files and syncs each one that differs with a sibling repo, renamed for it.
:: Usage: Sync-Ng ConsideraWeb.Ng.Some.Name [-Reverse]
::   -Reverse  sync from the repo back into the template
:: See SyncNg.ps1 for the details.

SET "Name=%~1"
SET "Reverse=%~2"

IF NOT DEFINED Name (
    ECHO Usage: Sync-Ng ConsideraWeb.Ng.Some.Name [-Reverse]
    EXIT /B 1
)

POWERSHELL -NoProfile -ExecutionPolicy Bypass -File "%~dp0SyncNg.ps1" "%Name%" %Reverse%
