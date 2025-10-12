param(
  [string]$TgtFile,     # 処理対象ファイル
  [string]$ScriptHome,  # 親スクリプトの場所
  [int]$dcount,         # 現在のワークのカウント
  [int]$tcount          # 取掛かり中ワークのファイル数カウント
)
Import-Module "$PSScriptRoot\CBZupsc" -Force
Import-Module "$PSScriptRoot\CBZupsc\Metrics.psm1" -Force

# 入力が無い場合は何もしないで終了。
  if (-not $TgtFile -or -not $ScriptHome) {
  Write-Host "Usage error: -TgtFile と -ScriptHome の両方を指定してください。  " -ForegroundColor Red
  exit 1
}
# 呼び出す関連ファイル群のプリフィクス取得
# $funcPrefix = ([System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)) -replace '_.*',''
  $ThisScriptName = Split-Path -Leaf $PSCommandPath
  $funcPrefix = ($ThisScriptName -split '_')[0]

# コンフィギュレーションファイルの参照
  $configPath = Join-Path $PSScriptRoot "${funcPrefix}_cfg.psd1"
  if (Test-Path $configPath) { $importconfig = Import-PowerShellDataFile $configPath }
  else {
    Write-Warning "設定ファイルが見つかりません: $configPath"
    exit 1
  }
  $ainit  = [PSCustomObject]$importconfig.aicfg
  $tinit  = [PSCustomObject]$importconfig.tinit
  $tinit2 = [PSCustomObject]$importconfig.tinit2
# パス設定
  $dirPath  = Split-Path -Parent $TgtFile
  $rltvPath = [System.IO.Path]::GetRelativePath($PSScriptRoot, $TgtFile)
  $today    = Get-Date -Format "yyyyMMdd"
# ここまで取得した設定値をまとめる
$dinit = [PSCustomObject]@{
  exeDir   = $ainit.exeDir
  # 処理対象ファイルの周辺情報を取得
  counter  = "{0,9}" -f ("({0}/{1})" -f $dcount, $tcount)
  scrHome  = $PSScriptRoot
  dirPath  = $dirPath
  dirName  = Split-Path -Leaf ($dirPath)
  srcPath  = $TgtFile
  srcName  = [System.IO.Path]::GetFileNameWithoutExtension($TgtFile)
  srcExt   = [System.IO.Path]::GetExtension($TgtFile).ToLower() 
  rltvPath = $rltvPath
  rltvDir  = [System.IO.Path]::GetDirectoryName($rltvPath)
  # ログファイルの保存先とバッファの設定
  today        = $today
  logfilePath1 = Join-Path $PSScriptRoot ("upscrlogPASS_{0}.txt" -f $today)
  logfilePath2 = Join-Path $PSScriptRoot ("upscrlogFAIL_{0}.txt" -f $today)
  logBuffer1   = @()
  logBuffer2   = @()
  }

######## MAIN ########
# 初期値を展開する。
  $ainit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  $dinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  $tinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  $mtcfg     = Get-Mediatype $srcPath
  $NoiseLv = $mtcfg.lv
  $quality = $mtcfg.qt
  $sinit = Resolve-Scale $dinit $tinit $NoiseLv $quality
# (更新対象：$AImodel, $width, $height, $needupscl, $scaleratio, $Upscaler, $ModelDir, $deNoiseLv, $Namefx)
  $sinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
# 値の受け渡し関連チェック（DEBUG）
  # Write-host "Width=${width} Height=${height} NoiseLv=${NoiseLv} deNoiseLv=${deNoiseLv} quality=${quality} Scale=${scaleratio}" 
  # Write-host "exedir=${exeDir} TH1=${LongSideThlen} TH2=${BothSideThlen} TH3=${ShortSideThlen} PSNRok=${psnrTshOK} PSNRng=${psnrTshNG}" 
  # Write-Host "configPath=$configPath"
  # Write-host "$Upscaler -i $srcPath -o $upPath -x -n $deNoiseLv -s $scaleratio -g $gpuselect -t $tilesize -j $threadset -m $ModelDir"
  # (Get-Module CBZupsc).ExportedCommands.Keys

# デノイズ処理スキップ用フラグ処理
  if ($x1denoSKIP -and $scaleratio -eq 1 -and $NoiseLv -le $x1dskipTsh) {
    $needupscl = $false
    $Namefx = $srcName
    }
# アップスケール出力前準備
  if ($needupscl) { $retry = 0 }
  else { 
    $upPath = $srcPath     # WebP変換後の元ファイル削除判断用の仕掛け
    $PSNRmin = 81.0931072  # アップスケールしない場合に向けてログに明確な異常値を残す。
    $SSIMmin = 1.45141919  # （桁揃えのため数値以外扱えず文言を残せないため）
    $AImodel = 'Skip-proc,dummy-val'
  }
# AIアップスケーリング。失敗したら設定を変えてリトライするためループ
while ($needupscl -and $retry -lt $maxRetry) {
  $upfile   = "${Namefx}_temp_ups.png"
  $upPath   = Join-Path $dirPath $upfile
  $upRltv = [System.IO.Path]::GetRelativePath($ScrHome, $upPath)

  # アップスケール実施行
  & $Upscaler -i $srcPath -o $upPath -x -n $deNoiseLv -s $scaleratio -g $gpuselect -t $tilesize -j $threadset -m $ModelDir 2> $null

  # 失敗したらアップスケールの設定を変更してリトライ。
  if ($LASTEXITCODE -ne 0) {
    $retry++
    Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ($msgtmp1 = "(EXTCODE=${LASTEXITCODE} by ${AImodel})").Substring([Math]::Max(0, $msgtmp1.Length - 32)),($msgtmp2 = "(try${retry}/${maxRetry}) ${upRltv} Upscaling failed.  ").Substring([Math]::Max(0, $msgtmp2.Length - 48)) ) -ForegroundColor DarkRed
    $logBuffer2 += ("$counter	[FAIL]	(EXTCODE={0})	{1}	Upscaling is fail.	(try {2}/{3})" -f $LASTEXITCODE, $upRltv, $retry, $maxRetry)
    $altmode = Switch-altmodloop $dinit $AImodel $scaleratio $NoiseLv
    # (更新対象：$AImodel, $deNoiseLv, $ModelDir, $Namefx, $Upscaler, $scaleratio)
    $altmode.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
    if (Test-Path $upPath) {
      try { Remove-Item -LiteralPath $upPath -Force -ErrorAction Stop }
      catch { Write-Host ("`r$counter  [WARN]  {0,-32} {1,-48}" -f ($msgtmp1 = "(EXTCODE=${LASTEXITCODE} by ${AImodel})").Substring([Math]::Max(0, $msgtmp1.Length - 32)),($msgtmp2 = "${upRltv} Failed to delete.  ").Substring([Math]::Max(0, $msgtmp2.Length - 48)) ) -ForegroundColor Yellow -NoNewline }
    } continue
  }
  # まれに出力完了前に次に進むため出力待ちを実施
  $waitCount = 0
  while (-not (Test-Path $upPath) -and $waitCount -lt 10) {
    Start-Sleep -Milliseconds 200; $waitCount++ 
  }
  # チェック画像の形式をRGBかYUVに揃える。デノイズ有効のパターンが大抵YUVのため。
  $YUVmode = ($deNoiseLv -ne -1)
  # アップスケール前後をタイル分割して部分毎にテストする
  $umtrx = Search-Metrics $srcPath $upPath $tinit $YUVmode $counter $AImodel
  $PSNRmin = $umtrx.PSNR
  $SSIMmin = $umtrx.SSIM
  if ([double]$PSNRmin -le $psnrTshNG -or [double]$SSIMmin -le $ssimTshNG) {
    # 結果が閾値未満（不合格）だった場合
    $retry++
    Write-Host ("`r$counter  [FAIL]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "(try${retry}/${maxRetry}) ${upRltv} PSNR is too low.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor DarkRed
    $logBuffer2 += ("$counter	[FAIL]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by {2})	{3}	PSNR too low.	(try {4}/{5})" -f $PSNRmin, $SSIMmin, $AImodel, $upRltv, $retry, $maxRetry)
    # リトライ前準備一式
    if ($retry -lt $maxRetry) {
      # アップスケール後の名前を変更する前に、ボツとなるデータを削除。
      if ($deltemp) {
        for ($i=0; $i -lt 5; $i++) {
          try   { [System.IO.File]::Delete($upPath); break }
          catch { Start-Sleep -Milliseconds 200 }
      } }
      # アップスケールの設定を変更する。
      $altmode = Switch-altmodloop $dinit $AImodel $scaleratio $NoiseLv
      # (更新対象：$AImodel, $deNoiseLv, $ModelDir, $Namefx, $Upscaler, $scaleratio)
      $altmode.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
    }
  } elseif ([double]$PSNRmin -lt $psnrTshOK) { 
    # 検査に合格したら要スケーリングフラグを降ろす
    $needupscl = $false
    Write-Host ("`r$counter  [WARN]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "(try${retry}/${maxRetry}) ${upRltv} Upscale is done.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor DarkYellow -NoNewline
    $logBuffer1 += ("$counter	[PASS]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by {2})	{3}	Upscale is done.	(try {4}/{5})" -f $PSNRmin, $SSIMmin, $AImodel, $wpRltv, $retry, $maxRetry)
  } else { 
    $needupscl = $false
    Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "(try${retry}/${maxRetry}) ${upRltv} Upscale is done.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Green -NoNewline
    $logBuffer1 += ("$counter	[PASS]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by {2})	{3}	Upscale is done.	(try {4}/{5})" -f $PSNRmin, $SSIMmin, $AImodel, $wpRltv, $retry, $maxRetry)
  }
}
# ここに来て「要アプスケ＝異常事態」ということ。明らかに変なので、敢えて掃除もしない。
if ($needupscl) {
  Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "(try${retry}/${maxRetry}) ${upRltv} Upscaling failed.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Red
  $logBuffer2 += ("$counter	[FAIL]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by {2})	{3}	Upscaling failed.	(try {4}/{5})" -f $PSNRmin, $SSIMmin, $AImodel, $upRltv, $retry, $maxRetry)
  for ($i=0; $i -lt 5; $i++) {
    try { $logBuffer2 | Add-Content -Path $logfilePath2 -Encoding UTF8; break }
    catch { Start-Sleep -Milliseconds (200 * ($i+1)) }
  } return  # この画像は拡大工程をスキップしてエラーを返す（処理を止めたいなら throw に変更）
}
# WebPに変換
  $wpFile = "${Namefx}.webp"
  $wpPath = Join-Path $dirPath $wpFile
  $wpRltv = [System.IO.Path]::GetRelativePath($ScrHome, $wpPath)
  magick "$upPath" `
    -quality 90 `
    -define webp:method=6 `
    -define webp:segments=4 `
    -define webp:sns-strength=0 `
    -define webp:filter-strength=0 `
    -define webp:alpha-quality=100 `
    "$wpPath"
# 出力待ち
  Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "${wpRltv}  to be created...     ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor DarkGray -NoNewline
  $waitCount = 0
  while (-not [System.IO.File]::Exists($wpPath) -and $waitCount -lt 50) { Start-Sleep -Milliseconds 200; $waitCount++ }
  Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "${wpRltv}  to be created...OK!  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor DarkGray -NoNewline
  $logBuffer1 += ("$counter	[PASS]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by {2})	{3}	created successfully.	(try {4}/{5})" -f $PSNRmin, $SSIMmin, $AImodel, $wpRltv, $retry, $maxRetry)

# アプスケ画像とWebPとのPSNRもみたい場合。$webpQtestで有効無効を切り替える。
  if ($webpQtest) {
    $YUVmode = $true  # 変換先WebPが必ずYUV420のためそちらに揃える。
    $wmtrx = Search-Metrics $upPath $wpPath $tinit2 $YUVmode $counter 'Webp_Lossy' 
    $wpPSNRmin = $wmtrx.PSNR
    $wpSSIMmin = $wmtrx.SSIM
    if ([double]$wpPSNRmin -ge $tinit2.psnrTshOK -and [double]$PSNRmin -ge $psnrTshOK) {
      Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by webp)" -f $wpPSNRmin),($msgtmp = "(try${retry}/${maxRetry}) ${wprltv} created successfully.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -NoNewline
      $logBuffer1 += ("$counter	[PASS]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by webp)	(PSNR={2,10:F7}dB,SSIM={3,10:F8} by {4})	{5}	created successfully.	(try {6}/{7})" -f $wpPSNRmin, $wpSSIMmin, $PSNRmin, $SSIMmin, $AImodel, $wpRltv, $retry, $maxRetry)
    } elseif ([double]$wpPSNRmin -gt $tinit2.psnrTshNG) {
      Write-Host ("`r$counter  [WARN]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by webp)" -f $wpPSNRmin),($msgtmp = "(try${retry}/${maxRetry}) ${wprltv} created successfully.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -NoNewline
      $logBuffer1 += ("$counter	[WARN]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by webp)	(PSNR={2,10:F7}dB,SSIM={3,10:F8} by {4})	{5}	created successfully.	(try {6}/{7})" -f $wpPSNRmin, $wpSSIMmin, $PSNRmin, $SSIMmin, $AImodel, $wpRltv, $retry, $maxRetry)
    } else {
      Write-Host ("`r$counter [※FAIL] {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by webp)" -f $wpPSNRmin),($msgtmp = "(try${retry}/${maxRetry}) ${wprltv} created successfully.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -NoNewline
      $logBuffer2 += ("$counter	[※FAIL]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by webp)	(PSNR={2,10:F7}dB,SSIM={3,10:F8} by {4})	{5}	created successfully.	(try {6}/{7})" -f $wpPSNRmin, $wpSSIMmin, $PSNRmin, $SSIMmin, $AImodel, $wpRltv, $retry, $maxRetry)
    }
  }
# 元画像と中間PNGを削除
  if ($deltemp) {
    for ($i=0; $i -lt 5; $i++) {
      try   { [System.IO.File]::Delete($srcPath); break }
      catch { Start-Sleep -Milliseconds 200 }
    }
    if ($upPath -ne $srcPath) {
      for ($i=0; $i -lt 5; $i++) {
        try   { [System.IO.File]::Delete($upPath); break }
        catch { Start-Sleep -Milliseconds 200 }
      }
    }
  }
# ログ出力
  Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "(try${retry}/${maxRetry}) ${wprltv} created successfully.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) )
  if ($logBuffer1.Count -gt 0) {
    for ($i=0; $i -lt 5; $i++) {
      try { $logBuffer1[-1] | Add-Content -Path $logfilePath1 -Encoding UTF8; break }
      catch { Start-Sleep -Milliseconds (200 * ($i+1)) }
    }
  }
  for ($i=0; $i -lt 5; $i++) {
    try { $logBuffer2 | Add-Content -Path $logfilePath2 -Encoding UTF8; break }
    catch { Start-Sleep -Milliseconds (200 * ($i+1)) }
  }