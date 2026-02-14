param(
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Container})]
    [string]$Root = $PSScriptRoot
)

# _数字 末尾の枝だけ抽出（大文字小文字/全角混在パスもOK）
Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
  $bn = $_.BaseName
  if ($bn -match '^(?<base>.+)_(?<n>[0-9]+)$') {
    $baseName = $Matches['base'] + $_.Extension
    $basePath = Join-Path $_.DirectoryName $baseName
    if (Test-Path -LiteralPath $basePath) {
      $h1 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
      $h2 = (Get-FileHash -Algorithm SHA256 -LiteralPath $basePath).Hash
      if ($h1 -eq $h2) {
        Remove-Item -LiteralPath $_.FullName -Force
      }
    }
  }
}