# Adds this template's folder to the current user's PATH so create.bat can be run from anywhere.
# Usage: powershell -ExecutionPolicy Bypass -File add-to-path.ps1
# Safe to run again: it does nothing if the folder is already on PATH. Open a new terminal afterwards to pick it up.
$ErrorActionPreference = 'Stop'

$dir = $PSScriptRoot.TrimEnd('\')

# Read the raw value so entries like %USERPROFILE%\bin are kept as written rather than expanded.
$key = Get-Item 'HKCU:\Environment'
$path = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
$entries = $path -split ';' | Where-Object { $_ }

if ($entries | Where-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -eq $dir }) {
    Write-Host "$dir is already on PATH."
    exit 0
}

Set-ItemProperty 'HKCU:\Environment' -Name Path -Value (($entries + $dir) -join ';') -Type ExpandString

# Tell Windows the environment changed, so new terminals see it without signing out.
Add-Type -Namespace Win32 -Name Native -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'
$result = [UIntPtr]::Zero
[Win32.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null

Write-Host "Added $dir to PATH. Open a new terminal to use it."
