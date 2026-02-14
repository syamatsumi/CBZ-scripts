param(
    [string]$TgtRoot = $PSScriptRoot
)

$fromwd = '_Video'
$toword = '_Movie'
$fwEsc = [regex]::Escape($fromwd)
$twEsc = [regex]::Escape($toword)

Get-ChildItem -LiteralPath $TgtRoot -Directory -Recurse |
  Sort-Object { $_.FullName.Length } -Descending |  # 深い階層から実施
  Where-Object Name -imatch $fwEsc |
  ForEach-Object {
    $renName = $_.Name -ireplace $fwEsc, $twEsc
    Write-Host "変更前名:  $($_.Name)"
    Write-Host "変更後名:  $renName"
    Write-Host ""
    Rename-Item -LiteralPath $_.FullName -NewName $renName
  }
