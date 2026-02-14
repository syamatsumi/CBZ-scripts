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
  if (Test-Path -LiteralPath $configPath) { $importconfig = Import-PowerShellDataFile $configPath }
  else {
    Write-Warning "設定ファイルが見つかりません: $configPath"
    exit 1
  }
  $ainit  = [PSCustomObject]$importconfig.aicfg
  $tinit  = [PSCustomObject]$importconfig.tinit
  $tinit2 = [PSCustomObject]$importconfig.tinit2
  $whVal  = [PSCustomObject]$importconfig.writehostVal

# パス設定
  $dirPath  = Split-Path -Parent $TgtFile
  $rltvPath = [System.IO.Path]::GetRelativePath($PSScriptRoot, $TgtFile)
  $today    = Get-Date -Format "yyyyMMdd"
# ここまで取得した設定値をまとめる
$dinit = [PSCustomObject]@{
  exeDir   = $ainit.exeDir
  # 処理対象ファイルの周辺情報を取得
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
  logfilePath3 = Join-Path $PSScriptRoot ("upscrlogWEBP_{0}.txt" -f $today)
  logBuffer1   = @()
  logBuffer2   = @()
  logBuffer3   = @()
  }

# Write-host用の変数。writehost init
$winit = [PSCustomObject]@{
  c   = "{0,9}" -f ("({0}/{1})" -f $dcount, $tcount)
  l   = "{0,-" + $whVal.l1 + "} {1,-" + $whVal.l2 + "}"
  try = 'try(0/0)'
  l1  = $whVal.l1  # 左列の幅
  l2  = $whVal.l2  # 右列の幅
  l3  = $whVal.l3  # 画面PSNR結果の桁
  l4  = $whVal.l4  # ログPSNR結果の桁
  l5  = $whVal.l5  # ログSSIM結果の桁
  nnl = $whVal.nnl # デバッグで改行させたい場合は $false に。
  log = "`t PSNR={0,$($whVal.l4)} / {1,$($whVal.l4)}dB `t SSIM={2,$($whVal.l5)} `t by {3} `t"
}
function Write-InfoLineErr ($msg1, $winit, $Errcode, $DistortionCause, $fileRltv, $msg2, [string]$color = $null, [switch]$newline) {
  # 改行と色のオプションを纏めておく
  $nnl = if ($newline) { $false } else { $winit.nnl }
  $options = @{ NoNewline = $nnl }
  if ([enum]::IsDefined([ConsoleColor], $color)) { $options['ForegroundColor'] = $color }
  # 第3カラムの内容
  $tmp3 = "(EXTCODE=${Errcode} by ${DistortionCause}) $($winit.try)"
  $pos3 = [Math]::Max(0, $tmp3.Length - $winit.l1)
  $col3 = $tmp3.Substring($pos3)
  # 第4カラムの内容
  $tmp4 = "${fileRltv} ${msg2}  "
  $pos4 = [Math]::Max(0, $tmp4.Length - $winit.l2)
  $col4 = $tmp4.Substring($pos4)
  # メッセージの集約と表示
  $message = ($msg1 + $winit.c + $winit.l) -f $col3, $col4
  Write-Host $message @options
}
function Write-InfoLinePSNR ($msg1, $winit, $PSNRmin, $fPSNR, $DistortionCause, $fileRltv, $msg2, [string]$color = $null, [switch]$newline) {
  # 改行と色のオプションを纏めておく
  $nnl = if ($newline) { $false } else { $winit.nnl }
  $options = @{ NoNewline = $nnl }
  if ([enum]::IsDefined([ConsoleColor], $color)) { $options['ForegroundColor'] = $color }
  # 第3カラムの内容
  $tmp3 = ("(PSNR={0,$($winit.l3)}/{1,2:F0}dB by {2})" + $winit.try) -f $PSNRmin, $fPSNR, $DistortionCause
  $pos3 = [Math]::Max(0, $tmp3.Length - $winit.l1)
  $col3 = $tmp3.Substring($pos3)
  # 第4カラムの内容
  $tmp4 = "${fileRltv} ${msg2}  "
  $pos4 = [Math]::Max(0, $tmp4.Length - $winit.l2)
  $col4 = $tmp4.Substring($pos4)
  # メッセージの集約と表示
  $message = ($msg1 + $winit.c + $winit.l) -f $col3, $col4
  Write-Host $message @options
}



######## MAIN ########
# 初期値を展開する。
  $ainit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  $dinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  $tinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  $mtcfg     = Get-Mediatype $srcPath
  $NoiseLv = $mtcfg.lv
  $quality = $mtcfg.qt
  $sinit = Resolve-Scale $dinit $tinit $winit $NoiseLv $quality
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
    $fPSNR = 81.0931072
    $fSSIM = 1.45141919
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
    $winit.try = "(try${retry}/${maxRetry})"
    Write-InfoLineErr '  [FAIL]  ' $winit $LASTEXITCODE $AImodel $upRltv 'Upscaling failed.' 'DarkRed'
    $logBuffer2 += (("[FAIL]`t(EXTCODE={0})`t" + $winit.try + "`t{1}`tUpscaling is fail.") -f $LASTEXITCODE, $upRltv)
    $altmode = Switch-altmodloop $dinit $AImodel $scaleratio $NoiseLv
    # (更新対象：$AImodel, $deNoiseLv, $ModelDir, $Namefx, $Upscaler, $scaleratio)
    $altmode.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
    if (Test-Path -LiteralPath $upPath) {
      try { Remove-Item -LiteralPath $upPath -Force -ErrorAction Stop }
      catch { Write-InfoLineErr '  [WARN]  ' $winit $LASTEXITCODE $AImodel $upRltv 'Failed to delete.' 'Yellow' }
    } continue
  }
  # まれに出力完了前に次に進むため出力待ちを実施
  $waitCount = 0
  while (-not (Test-Path -LiteralPath $upPath) -and $waitCount -lt 10) {
    Start-Sleep -Milliseconds 200; $waitCount++ 
  }
  # チェック画像の形式をRGBかYUVに揃える。デノイズ有効のパターンが大抵YUVのため。
  $YUVmode = ($deNoiseLv -ne -1)
  # アップスケール前後をタイル分割して部分毎にテストする
  $umtrx = Search-Metrics $srcPath $upPath $tinit $YUVmode $winit $AImodel
  $fPSNR = $umtrx.fPSNR
  $fSSIM = $umtrx.fSSIM
  $PSNRmin = $umtrx.PSNR
  $SSIMmin = $umtrx.SSIM

  $psnrFaNG  = ([double]$fPSNR -le $FApsnrTsh)
  $ssimFaNG  = ([double]$fSSIM -le $FAssimTsh)
  $psnrMinNG = ([double]$PSNRmin -le $psnrTshNG)
  $ssimMinNG = ([double]$SSIMmin -le $ssimTshNG)

  if ($psnrFaNG -or $ssimFaNG -or $psnrMinNG -or $ssimMinNG) {
    # 結果が閾値未満（不合格）だった場合
    $retry++
    $winit.try = "(try${retry}/${maxRetry})"
    if ($psnrFaNG -or $ssimFaNG) {
      Write-InfoLinePSNR "`r  [FAIL]  " $winit $PSNRmin $fPSNR $AImodel $upRltv 'Full Area PSNR is too low.' 'DarkRed' -newline
      $logBuffer2 += (("[FAIL]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tFull area PSNR too low.") -f $fPSNR, $fPSNR, $fSSIM, $AImodel, $upRltv)
    } else {
      Write-InfoLinePSNR "`r  [FAIL]  " $winit $PSNRmin $fPSNR $AImodel $upRltv 'Tile Area PSNR is too low.' 'DarkRed' -newline
      $logBuffer2 += (("[FAIL]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tTile area PSNR too low.") -f $PSNRmin, $fPSNR, $SSIMmin, $AImodel, $upRltv)
    }
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
    Write-InfoLinePSNR "`r  [WARN]  " $winit $PSNRmin $fPSNR $AImodel $upRltv 'Upscale is done.' 'DarkYellow'
    $logBuffer1 += (("[WARN]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tUpscale is done.") -f $PSNRmin, $fPSNR, $SSIMmin, $AImodel, $upRltv)
  } else { 
    $needupscl = $false
    Write-InfoLinePSNR "`r  [PASS]  " $winit $PSNRmin $fPSNR $AImodel $upRltv 'Upscale is done.' 'Green'
    $logBuffer1 += (("[PASS]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tUpscale is done.") -f $PSNRmin, $fPSNR, $SSIMmin, $AImodel, $upRltv)
  }
}
# ここに来て「要アプスケ＝異常事態」ということ。明らかに変なので、敢えて掃除もしない。
if ($needupscl) {
  Write-InfoLinePSNR "`r  [FAIL]  " $winit $PSNRmin $fPSNR $AImodel $upRltv 'Upscaling failed.(loop ended.)' 'Red' -newline
  $logBuffer2 += (("[FAIL]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tUpscaling failed. (loop ended before completion)") -f $PSNRmin, $fPSNR, $SSIMmin, $AImodel, $upRltv)
  for ($i=0; $i -lt 5; $i++) {
    try { $logBuffer2 | Add-Content -Path $logfilePath2 -Encoding UTF8; break }
    catch { Start-Sleep -Milliseconds (200 * ($i+1)) }
  } 
  # 後続のWebP変換処理に渡さずここで終了。
  return
}
# WebPに変換
  $wpFile = "${Namefx}.webp"
  $wpPath = Join-Path $dirPath $wpFile
  $wpRltv = [System.IO.Path]::GetRelativePath($ScrHome, $wpPath)
  if ($webplless) { magick "$upPath" -define webp:lossless=true "$wpPath" }
  else {
    magick "$upPath" `
      -quality $webpQual `
      -define webp:method=6 `
      -define webp:segments=4 `
      -define webp:sns-strength=0 `
      -define webp:filter-strength=0 `
      -define webp:alpha-quality=100 `
      "$wpPath"
  }
# 出力待ち
  Write-InfoLinePSNR "`r  [WAIT]  " $winit $PSNRmin $fPSNR $AImodel $wpRltv 'to be created...   ' 'DarkGray'
  $waitCount = 0
  while (-not [System.IO.File]::Exists($wpPath) -and $waitCount -lt 50) { Start-Sleep -Milliseconds 200; $waitCount++ }
  Write-InfoLinePSNR "`r  [PASS]  " $winit $PSNRmin $fPSNR $AImodel $wpRltv 'to be created...OK!' 'DarkGreen'
  $logBuffer1 += (("[PASS]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tcreated successfully.") -f $PSNRmin, $fPSNR, $SSIMmin, $AImodel, $wpRltv)

# アプスケ画像とWebPとのPSNRもみたい場合。$webpQtestで有効無効を切り替える。
  if ($webpQtest) {
    $YUVmode = $true  # 変換先WebPが必ずYUV420のためそちらに揃える。
    $wmtrx = Search-Metrics $upPath $wpPath $tinit2 $YUVmode $winit 'Webp_Lossy' 
    $wpPSNRmin = $wmtrx.PSNR
    $wpSSIMmin = $wmtrx.SSIM
    if ([double]$wpPSNRmin -ge $tinit2.psnrTshOK -and [double]$PSNRmin -ge $psnrTshOK) {
      Write-InfoLinePSNR "`r  [PASS]  " $winit $wpPSNRmin $fPSNR 'magick-webp' $wpRltv 'created successfully.' 'Green'
      $logBuffer3 += (("[PASS]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tcreated successfully.") -f $wpPSNRmin, $fPSNR, $wpSSIMmin, 'magick-webp', $wpRltv)
    } elseif ([double]$wpPSNRmin -gt $tinit2.psnrTshNG) {
      Write-InfoLinePSNR "`r  [WARN]  " $winit $wpPSNRmin $fPSNR 'magick-webp' $wpRltv 'created with inconsistent quality...' 'Yellow'
      $logBuffer3 += (("[WARN]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tcreated with inconsistent quality...") -f $wpPSNRmin, $fPSNR, $wpSSIMmin, 'magick-webp', $wpRltv)
    } else {
      Write-InfoLinePSNR "`r  [FAIL]  " $winit $wpPSNRmin $fPSNR 'magick-webp' $wpRltv 'created with poor quality!' 'Red'
      $logBuffer3 += (("[FAIL]`t" + $winit.c + $winit.log + $winit.try + "`t{4}`tcreated with poor quality!") -f $wpPSNRmin, $fPSNR, $wpSSIMmin, 'magick-webp', $wpRltv)
    }
  }
# 元画像と中間PNGを削除(デバッグ時は $deltemp を $false に。)
  if ($deltemp) {
    for ($i=0; $i -lt 5; $i++) {
      try   { [System.IO.File]::Delete($srcPath); break }
      catch { Start-Sleep -Milliseconds 200 }
    }
    if ($upPath -ne $srcPath) {
      for ($i=0; $i -lt 5; $i++) {
        try   { [System.IO.File]::Delete($upPath); break }
        catch { Start-Sleep -Milliseconds 200 }
  } } }
# ログ出力
  Write-InfoLinePSNR "`r  [PASS]  " $winit $PSNRmin $fPSNR $AImodel $wpRltv 'created successfully.' -Newline
  if ($logBuffer1.Count -gt 0) {
    for ($i=0; $i -lt 5; $i++) {
      try { $logBuffer1[-1] | Add-Content -Path $logfilePath1 -Encoding UTF8; break }
      catch { Start-Sleep -Milliseconds (200 * ($i+1)) }
  } }
  if ($logBuffer2.Count -gt 0) {
    for ($i=0; $i -lt 5; $i++) {
      try { $logBuffer2 | Add-Content -Path $logfilePath2 -Encoding UTF8; break }
      catch { Start-Sleep -Milliseconds (200 * ($i+1)) }
  } }
  if ($logBuffer3.Count -gt 0) {
    for ($i=0; $i -lt 5; $i++) {
      try { $logBuffer3 | Add-Content -Path $logfilePath3 -Encoding UTF8; break }
      catch { Start-Sleep -Milliseconds (200 * ($i+1)) }
  } }
