param(
  [Parameter(Mandatory = $true)]
  [string]$TgtRoot,          # 処理対象フォルダ
  [Parameter(Mandatory = $true)]
  [string]$Worker,           # ワーカーPS1のフルパス
  [int]$MxPal = 6            # 並列実行数
)
# このスクリプト自身の場所
  $ScriptHome = Split-Path -Parent $MyInvocation.MyCommand.Path
# 開始時間計測
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
# 再帰的にファイルを列挙（例: 全ファイル対象）
  $targets = Get-ChildItem -LiteralPath $TgtRoot -File -Recurse |
    Sort-Object DirectoryName, Name
  $FileCount = $targets.Count
  $ccount = [System.Collections.Concurrent.ConcurrentBag[int]]::new()
# ファイルごとにワーカーを割り当て、最大 $MxPal 並列
  $targets | ForEach-Object -Parallel {
    Start-Sleep -Milliseconds (Get-Random -Min 300 -Max 1000)
    $dcount = $using:ccount
    $dcount.Add(1)
    $dcnt = $dcount.Count
    $tcnt = $using:FileCount
    Write-Host "`r(${dcnt}/${tcnt})[dispatch] assigning : $($_.Name)  " -NoNewline -ForegroundColor DarkGray
    & $using:Worker -TgtFile $_.FullName -ScriptHome $using:ScriptHome -dcount $dcnt -tcount $tcnt
  } -ThrottleLimit $MxPal
# 終了時間確定と表示
$sw.Stop()
Write-Host ("`r`n本サイクルの処理時間: {0:hh\:mm\:ss\.ff}    " -f $sw.Elapsed)
