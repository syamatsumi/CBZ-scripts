param(
    [string]$TgtRoot = $PSScriptRoot
)

$fromwd = '_Video'
$toword = '_Movie'
$fwEsc = [regex]::Escape($fromwd)
# 正規表現を使う場合は[regex]::Escape()を外す。
# $fwEsc = $fromwd

Get-ChildItem -LiteralPath $TgtRoot -Recurse |
  Sort-Object { $_.FullName.Length } -Descending |  # 深い階層から実施
  Where-Object Name -imatch $fwEsc |
  ForEach-Object {
    $renName = $_.Name -ireplace $fwEsc, $toword
    Write-Host "変更前名:  $($_.Name)"
    Write-Host "変更後名:  $renName"
    Write-Host ""
    Rename-Item -LiteralPath $_.FullName -NewName $renName
  }
