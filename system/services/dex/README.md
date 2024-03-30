[Dex](https://dexidp.io/)

DATE: 2023-12-13
CHART VERSION: 1.13.1

To generate passwords for cookie secrets in PowerShell, something like this will work

```powershell
$ValidChars = @('a'..'z') + @('A'..'Z') + @(0..9) + @('-','_',',',':','!','@','#','%','^','*','(',')')
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([char[]]$ValidChars[(Get-Random -Max ($ValidChars.Count - 1) -Count 32)]))
```
