param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string]$Root = $PSScriptRoot
)

$fromwd = '_Video'
$toword = '_Movie'
$fwEsc = [regex]::Escape($fromwd)
$twEsc = [regex]::Escape($toword)

Get-ChildItem -LiteralPath $Root -File |
  Where-Object Name -imatch $fwEsc |
  ForEach-Object {
    $renName = $_.Name -ireplace $fwEsc, $twEsc
    Write-Host "変更前名:  $($_.Name)"
    Write-Host "変更後名:  $renName"
    Write-Host ""
    Rename-Item -LiteralPath $_.FullName -NewName $renName
  }
