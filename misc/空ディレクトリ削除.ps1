# スクリプトのある場所に移動
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -LiteralPath $scriptDir

# 特定のファイルを事前に削除（掃除）
$wildcardPath = Join-Path $scriptDir '*'
Get-ChildItem -Path $wildcardPath -Recurse -File -Include "desktop.ini","Thumbs.db",".DS_Store" -Force -ErrorAction SilentlyContinue |
  ForEach-Object {
    # まれに属性が邪魔するので Normal にしてから削除
    try { $_.Attributes = 'Normal' } catch {}
    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
  }

# ツリー全体から __MACOSX ディレクトリを再帰的に削除
Get-ChildItem -LiteralPath $scriptDir -Recurse -Directory -Filter '__MACOSX' -Force -ErrorAction SilentlyContinue |
  ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

# 空ディレクトリを削除（末端から順に）
do {
  $deleted = 0
  Get-ChildItem -LiteralPath $scriptDir -Recurse -Directory -Force |
    Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) } |  # ジャンクション等は除外
    Sort-Object { $_.FullName.Split([IO.Path]::DirectorySeparatorChar).Count } -Descending |
    ForEach-Object {
      if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        try {
          Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
          $deleted++
          Write-Host "削除: $($_.FullName)"
        } catch {
          Write-Warning "削除失敗: $($_.FullName) -> $($_.Exception.Message)"
        }
      }
    }
} while ($deleted -gt 0)

