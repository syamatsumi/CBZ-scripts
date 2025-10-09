param(
  [string]$TgtFile,     # 処理対象ファイル
  [string]$ScriptHome,  # 親スクリプトの場所
  [int]$dcount,         # 現在のワークのカウント
  [int]$tcount          # 取掛かり中ワークのファイル数カウント
)
# 入力が無い場合は何もしないで終了。
  if (-not $TgtFile -or -not $ScriptHome) {
  Write-Host "Usage error: -TgtFile と -ScriptHome の両方を指定してください。  " -ForegroundColor Red
  exit 1
}
# パス設定
  $dirPath  = Split-Path -Parent $TgtFile
  $rltvPath = [System.IO.Path]::GetRelativePath($ScriptHome, $TgtFile)
  $today    = Get-Date -Format "yyyyMMdd"

# 設定値をまとめる
$ainit = [PSCustomObject]@{
  # アップスケーラの設定
  # マルチGPU時はカンマ区切りで複数指定が必要なパラメータがある。
  # $tilesize（ex."256,256"）と$threadset（ex."1:4,4:2"）
  exeDir    = '#exe'       # exeを格納したディレクトリの名前
  gpuselect = 'auto'       # 利用するGPUの選択（auto,"0","0,1"など）
  tilesize  = '256'        # 画像を分割するサイズ。大きいほどメモリ食う。
  threadset = '1:4:4'      # スレッド割当てと比率（load:proc:save）
  # その他の挙動について
  maxRetry   = 8       # アップスケールの再試行許容回数
  deltemp    = $true   # テンポラリと元画像の削除の実施
  x1denoSKIP = $true   # 等倍判定時にデノイズ処理を強制スキップする。
  x1dskipTsh = 1       # 上記有効時、デノイズ処理をスキップする下限。
  webpQtest  = $false  # Webp出力の品質検査・有効無効
  # 処理対象ファイルの周辺情報を取得
  counter  = "{0,9}" -f ("({0}/{1})" -f $dcount, $tcount)
  scrHome  = $ScriptHome
  dirPath  = $dirPath
  dirName  = Split-Path -Leaf ($dirPath)
  srcPath  = $TgtFile
  srcName  = [System.IO.Path]::GetFileNameWithoutExtension($TgtFile)
  srcExt   = [System.IO.Path]::GetExtension($TgtFile).ToLower() 
  rltvPath = $rltvPath
  rltvDir  = [System.IO.Path]::GetDirectoryName($rltvPath)
  # ログファイルの保存先とバッファの設定
  today        = $today
  logfilePath1 = Join-Path $ScriptHome ("upscrlogPASS_{0}.txt" -f $today)
  logfilePath2 = Join-Path $ScriptHome ("upscrlogFAIL_{0}.txt" -f $today)
  logBuffer1   = @()
  logBuffer2   = @()
}
# テストに関する閾値。
$tinit = [PSCustomObject]@{ 
  TotalPixelTsh  = 6.0   # 拡大を省略する総画素数(メガピクセル指定)
  LongSideThlen  = 3840  # 拡大を省略する長辺の閾値
  BothSideThlen  = 2048  # 拡大を省略する両辺の閾値
  ShortSideThlen = 1024  # 倍率x2が確定する短辺の閾値（これ未満は3倍）
  psnrTshOK      = 32    # 拡大後PSNRの閾値（再検査ライン）
  psnrTshVE      = 28    # 拡大後PSNRの閾値（要検証ライン）
  psnrTshNG      = 16    # 拡大後PSNRの閾値（不合格ライン）
  ssimTshOK      = 0.96  # 拡大後SSIMの閾値（再検査ライン）
  ssimTshVE      = 0.93  # 拡大後SSIMの閾値（要検証ライン）
  ssimTshNG      = 0.80  # 拡大後SSIMの閾値（不合格ライン）
  tilesizeL      = 256   # PSNR検査用のタイルサイズ
  tilesizeR      = 128   # 再検査時のタイルサイズ
  tilesizeS      = 32    # 要検証時のタイルサイズ
}
$tinit2 = [PSCustomObject]@{ 
  psnrTshOK      = 40    # WebP後PSNRの閾値（再検査ライン）
  psnrTshVE      = 30    # WebP後PSNRの閾値（要検証ライン）
  psnrTshNG      = 20    # WebP後PSNRの閾値（不合格ライン）
  ssimTshOK      = 0.97  # 拡大後SSIMの閾値（再検査ライン）
  ssimTshVE      = 0.95  # 拡大後SSIMの閾値（要検証ライン）
  ssimTshNG      = 0.80  # 拡大後SSIMの閾値（不合格ライン）
  tilesizeL      = 1024  # PSNR検査用のタイルサイズ
  tilesizeR      = 512   # 再検査時のタイルサイズ
  tilesizeS      = 128   # 要検証時用のタイルサイズ
}
# ロッシー形式ならデノイズON、ロスレス形式はデノイズOFF
function Chk-Mediatype ($srcPath) {
  $srcExt  = [System.IO.Path]::GetExtension($srcPath).ToLower()
  $NoiseLv = 0
  $quality = 'Unknown'
  switch -Regex ($srcExt) {
    '\.jpe?g' {
      $magickinfo = & magick identify -verbose "$srcPath"
      $line = $magickinfo | Select-String "Quality: (\d+)"
      if ($line) {
        $quality = [int]$line.Matches[0].Groups[1].Value
        if     ($quality -lt 70) { $NoiseLv = 3 }
        elseif ($quality -lt 80) { $NoiseLv = 2 }
        elseif ($quality -lt 90) { $NoiseLv = 1 }
      }
    }
    '\.webp' {
      $magickinfo = & magick identify -verbose "$srcPath"
      $line = $magickinfo | Select-String 'WebP Lossless'
      if ($line) {
        $NoiseLv = -1
        $quality = 'Lossless'
      }
    }
    '\.(bmp|png)$' {
      $NoiseLv = -1
      $quality = 'Lossless'
    }
    default { exit 0 }  # 処理対象外はスキップして正常終了
  }
  [PSCustomObject]@{ lv=$NoiseLv; qt=$quality }
}

# ディレクトリパスの再作成、および、実行不能な設定の組み合わせを回避する。
function Generate-Paths ($ainit, $AImodel, $ratio, $NoiseLv) {
  # (ここで必要な変数：$srcName, $scrHome, $exeDir)
  $ainit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }

  if ($AImodel -eq 'realcugan-pro') {
    $Upscaler = Join-Path $scrHome $exeDir 'realcugan-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-pro'
    if     ($NoiseLv -eq  0) { $deNoiseLv = 0; $Namefx = "${srcName}_dn0pro${ratio}x" }
    elseif ($NoiseLv -eq  1) { $deNoiseLv = 0; $Namefx = "${srcName}_dn0pro${ratio}x" }
    elseif ($NoiseLv -eq  2) { $deNoiseLv = 3; $Namefx = "${srcName}_dn3pro${ratio}x" }
    elseif ($NoiseLv -eq  3) { $deNoiseLv = 3; $Namefx = "${srcName}_dn3pro${ratio}x" }
    else                    { $deNoiseLv = -1; $Namefx = "${srcName}_nodpro${ratio}x" }
  }
  elseif ($AImodel -eq 'realcugan-se') {
    $Upscaler = Join-Path $scrHome $exeDir 'realcugan-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-se'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodse${ratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}se${ratio}x" }
  }
  elseif ($AImodel -eq 'waifu2x-cunet') {
    if ($ratio -eq 3) { $ratio = 2 }
    $Upscaler = Join-Path $scrHome $exeDir 'waifu2x-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-cunet'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodcunet${ratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}cunet${ratio}x" }
  }
  elseif ($AImodel -eq 'waifu2x-art') {
    if ($ratio -eq 3) { $ratio = 2 }
    $Upscaler = Join-Path $scrHome $exeDir 'waifu2x-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-art'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodart${ratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}art${ratio}x" }
  }
  elseif ($AImodel -eq 'waifu2x-photo') {
    if ($ratio -eq 3) { $ratio = 2 }
    $Upscaler = Join-Path $scrHome $exeDir 'waifu2x-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-photo'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodphoto${ratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}photo${ratio}x" }
  }
  else {
    Write-Warning "Unknown model '$AImodel'. Defaulting to realcugan-se."
    $AImodel  = 'realcugan-se'
    $Upscaler = Join-Path $scrHome $exeDir 'realcugan-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-se'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodse${ratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}se${ratio}x" }
  }
  [PSCustomObject]@{
    ai = $AImodel
    lv = $deNoiseLv
    m  = $ModelDir
    n  = $Namefx
    u  = $Upscaler
    x  = $ratio
  }
}

# 拡大倍率とデノイズ有無の組み合わせ設定。 ##### 兼第一選択の控え #####
function Resolve-Scale ($ainit, $tinit, $NoiseLv, $quality, $counter) {
  # (ここで必要な変数：srcName, srcExt, $srcPath, $rltvPath)
  $ainit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  # (ここで必要な変数：$TotalPixelTsh, $LongSideThlen, $BothSideThlen, $ShortSideThlen)
  $tinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  $AImodel = 'realcugan-pro'  # 初期選択のAIモデルを設定。

  # magick identify を使って 画像のサイズを確認する。
  $width  = & magick identify -format "%w" "$srcPath"
  $height = & magick identify -format "%h" "$srcPath"
  $width  = [int]$width
  $height = [int]$height

  if ( ((($width * $height) / 1e6) -ge $TotalPixelTsh) -or
         ($width -ge $LongSideThlen -or  $height -ge $LongSideThlen) -or
         ($width -ge $BothSideThlen -and $height -ge $BothSideThlen) ) {
    # 元からLossyのWebpは加工するメリット無さそうなので、全ての処理をスキップ。
    if ($srcExt -eq ".webp" -and $NoiseLv -ne -1) {
      Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is No need to process.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Blue -NoNewline
      exit 0  # このままupscale.ps1スクリプトごと正常終了。
    # 拡大対象外かつロスレス形式
    } elseif ($srcExt -eq ".bmp" -or $srcExt -eq ".png" -or $srcExt -eq ".webp") {
      $needupscl = $false
      $scaleratio = 1
      $genpath = Generate-Paths $ainit 'waifu2x-cunet' 1 $NoiseLv
      Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is large enough.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Blue -NoNewline
    # 拡大対象外かつWebp形式以外（実質JPEG等倍）
    } else {
      $needupscl  = $true
      $scaleratio = 1
      $genpath = Generate-Paths $ainit 'waifu2x-cunet' 1 $NoiseLv
      Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is large enough.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Blue -NoNewline
    }
  # 拡大対象x2（短辺が閾値以上）
  } elseif ($width -ge $ShortSideThlen -and $height -ge $ShortSideThlen) {
    $needupscl = $true
    $scaleratio = 2
    $genpath = Generate-Paths $ainit $AImodel 2 $NoiseLv
    Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is Enlarge to x2.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Green -NoNewline
  # 拡大対象x3（短辺が閾値より小さい）
  } else {
    $needupscl = $true
    $scaleratio = 3
    $genpath = Generate-Paths $ainit $AImodel 3 $NoiseLv
    Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is Enlarge to x3.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Magenta -NoNewline
  }
  [PSCustomObject]@{
    width      = $width
    height     = $height
    needupscl  = $needupscl
    scaleratio = $scaleratio
    AImodel    = $genpath.ai
    deNoiseLv  = $genpath.lv
    ModelDir   = $genpath.m
    Namefx     = $genpath.n
    Upscaler   = $genpath.u
  }
}

# モデルの切り替えループ関数。モデルや倍率を順に切り替える
function Switch-altmodloop ($ainit, $AImodel, $scaleratio, $NoiseLv) {
  if ($scaleratio -eq 1) {
    # RealCuGANのデノイズのみモデルは開発中のためWaifu2xのみで実施
    if     ($AImodel -eq 'waifu2x-cunet') { $genpath = Generate-Paths $ainit 'waifu2x-art'   1 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-art')   { $genpath = Generate-Paths $ainit 'waifu2x-photo' 1 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-photo') { $genpath = Generate-Paths $ainit 'waifu2x-cunet' 1 $NoiseLv }
  }
  elseif ($scaleratio -eq 2) {
    if     ($AImodel -eq 'realcugan-pro') { $genpath = Generate-Paths $ainit 'realcugan-se'  2 $NoiseLv }
    elseif ($AImodel -eq 'realcugan-se')  { $genpath = Generate-Paths $ainit 'waifu2x-cunet' 2 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-cunet') { $genpath = Generate-Paths $ainit 'waifu2x-art'   2 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-art')   { $genpath = Generate-Paths $ainit 'waifu2x-photo' 2 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-photo') { $genpath = Generate-Paths $ainit 'realcugan-pro' 2 $NoiseLv }
  }
  elseif ($scaleratio -eq 3) {
    if     ($AImodel -eq 'realcugan-pro') { $genpath = Generate-Paths $ainit 'realcugan-se'  3 $NoiseLv }
    elseif ($AImodel -eq 'realcugan-se')  { $genpath = Generate-Paths $ainit 'realcugan-pro' 4 $NoiseLv }
    # Waifu2xの3倍モデルは無いので4倍（x2モデル2回）にして回避できないかトライ。
  }
  elseif ($scaleratio -eq 4) {
    if     ($AImodel -eq 'realcugan-pro') { $genpath = Generate-Paths $ainit 'realcugan-se'  4 $NoiseLv }
    elseif ($AImodel -eq 'realcugan-se')  { $genpath = Generate-Paths $ainit 'waifu2x-cunet' 4 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-cunet') { $genpath = Generate-Paths $ainit 'waifu2x-art'   4 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-art')   { $genpath = Generate-Paths $ainit 'waifu2x-photo' 4 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-photo') { $genpath = Generate-Paths $ainit 'realcugan-pro' 4 $NoiseLv }
  }
  [PSCustomObject]@{
    AImodel    = $genpath.ai
    deNoiseLv  = $genpath.lv
    ModelDir   = $genpath.m
    Namefx     = $genpath.n
    Upscaler   = $genpath.u
    scaleratio = $genpath.x
  }
}

# PSNR/SSIMのテスト関数。
# PSNRは通常行頭（括弧外）がPSNRと想定、SSIMは括弧内がSSIMと想定。
# SSIMはなぜか相関が高いほど0に近似する値が返ってくるため相補値で返しています。
function Get-MTRX($srcPath,$tstPath,$tstarea,$SSIMchk) {
  $result = [ordered]@{ PSNR = 0.0; SSIM = 0.0 }
  # 共通引数（クロップなど）
  $cropArgs = @('(', "$srcPath", '-crop', $tstarea, '+repage', ')', 
                '(', "$tstPath", '-crop', $tstarea, '+repage', ')', 'null:')
  # --- PSNR ---
  $rPSNR = & magick @('compare','-metric','PSNR') + $cropArgs 2>&1
  if ($rPSNR -match 'inf') { $result.PSNR = 100.0 }
  elseif ($rPSNR -match '^([\d\.]+)') {
    $result.PSNR = [double]$matches[1]
    $matches.Clear()
  }
  # --- SSIM ---
  if ($SSIMchk) {
    $rSSIM = & magick @('compare','-metric','SSIM') + $cropArgs 2>&1
    if ($rSSIM -match 'inf') { $result.SSIM = 0.0 }
    elseif ($rSSIM -match '\(([\d\.]+)\)') {
      [double]$SSIMval = 0
      [void][double]::TryParse($matches[1], [ref]$SSIMval)
      $matches.Clear() 
      $result.SSIM = 1.0 - $SSIMval
    } else {
      $result.SSIM = 1.0
  } }
  return $result  # 戻り値: [ordered]@{ PSNR = <double>; SSIM = <double> }
}

# ループ検査
function ChkLoop-Metrics ($srcPath, $chkPath, $tVal, $YUVmode, $counter, $DistortionCause) {
  # ($psnrTshOK $psnrTshVE $psnrTshNG $ssimTshOK $ssimTshVE $ssimTshNG $tilesizeL $tilesizeR $tilesizeSの展開)
  $tVal.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }

  $chkName   = [System.IO.Path]::GetFileNameWithoutExtension($chkPath)
  $chkDir    = Split-Path -Parent $chkPath
  $dirName   = Split-Path -Leaf $chkDir
  $tstfileA  = "temp_tstA_${chkName}.png"
  $tstfileB  = "temp_tstB_${chkName}.png"

  $tstPathA  = Join-Path $chkDir $tstfileA
  $tstPathB  = Join-Path $chkDir $tstfileB

  $width  = & magick identify -format "%w" "$srcPath"
  $height = & magick identify -format "%h" "$srcPath"
  $width  = [int]$width
  $height = [int]$height

  # クロマサブサンプリングの違いで値が大きく暴れるのでソースや比較先に合わせて条件を揃える。
  # アーティファクトの検出にあたってアルファチャンネルが邪魔なので削除する。
  if ($YUVmode){
    & magick "$srcPath" -alpha remove -alpha off -define png:color-type=2 -colorspace YUV -set colorspace Rec601YCbCr -sampling-factor 4:2:0 -depth 8 "$tstPathA"
    & magick "$chkPath" -alpha remove -alpha off -define png:color-type=2 -colorspace YUV -set colorspace Rec601YCbCr -sampling-factor 4:2:0 -depth 8 `
      -filter Box -resize ${width}x${height}! "$tstPathB"
  } else {
    & magick "$srcPath" -alpha remove -alpha off -define png:color-type=2 -colorspace sRGB -set colorspace sRGB -channel RGB -depth 8 "$tstPathA"
    & magick "$chkPath" -alpha remove -alpha off -define png:color-type=2 -colorspace sRGB -set colorspace sRGB -channel RGB -depth 8 `
      -filter Box -resize ${width}x${height}! "$tstPathB"
  }
  $result = [ordered]@{ PSNR = 0.0; SSIM = 0.0 }
  $mtrx = Get-MTRX $tstPathA $tstPathB "${width}x${height}+0+0" -SSIMchk:$true
  $PSNRmin = $PSNR = $mtrx.PSNR
  $SSIMmin = $SSIM = $mtrx.SSIM

  :Tileloop
  for ($lx = 0; $lx -lt $width; $lx += $tilesizeL) {
    for ($ly = 0; $ly -lt $height; $ly += $tilesizeL) {
      $tstareaL = "${tilesizeL}x${tilesizeL}+${lx}+${ly}"
      $mtrx = Get-MTRX $tstPathA $tstPathB $tstareaL -SSIMchk $true
      $PSNR = $mtrx.PSNR
      $SSIM = $mtrx.SSIM
      if ($PSNR -lt $PSNRmin) { $PSNRmin = $PSNR }
      if ($SSIM -lt $SSIMmin) { $SSIMmin = $SSIM }
      if ([double]$PSNR -lt $psnrTshNG) { break Tileloop }
      if ([double]$SSIM -lt $ssimTshNG) { break Tileloop }
      if ([double]$PSNR -lt $psnrTshOK -or [double]$SSIM -lt $ssimTshOK ) {
        Write-Host ("`r$counter [CheckL] {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $DistortionCause),($msgtmp = "${dirName}\${chkName} PSNR Check now.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -NoNewline
        if ($lx + $tilesizeL -gt $width) { $endposRx = $width }
        else { $endposRx = $lx + $tilesizeL }
        if ($ly + $tilesizeL -gt $height) { $endposRy = $height }
        else { $endposRy = $ly + $tilesizeL }
        for ($rx = $lx; $rx -lt $endposRx; $rx += $tilesizeR) {
          for ($ry = $ly; $ry -lt $endposRy; $ry += $tilesizeR) {
            $tstareaR = "${tilesizeR}x${tilesizeR}+${rx}+${ry}"
            $mtrx = Get-MTRX $tstPathA $tstPathB $tstareaR -SSIMchk $false
            $PSNR = $mtrx.PSNR  # SSIMのOKとVEを同値にしておくと一番細かいタイルサイズまでチェックできる。
          # $SSIM = $mtrx.SSIM  # この際、-SSIMchk $false時は戻り値なしとなるためこの行をコメントアウトしておく。
            if ($PSNR -lt $PSNRmin) { $PSNRmin = $PSNR }
            if ($SSIM -lt $SSIMmin) { $SSIMmin = $SSIM }
            if ([double]$PSNR -lt $psnrTshNG) { break Tileloop }
            if ([double]$SSIM -lt $ssimTshNG) { break Tileloop }
            if ([double]$PSNR -lt $psnrTshVE -or [double]$SSIM -lt $ssimTshVE ) {
              Write-Host ("`r$counter [CheckR] {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $DistortionCause),($msgtmp = "${dirName}\${chkName} PSNR Check now.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -NoNewline
              if ($rx + $tilesizeR -gt $width) { $endposSx = $width }
              else { $endposSx = $rx + $tilesizeR }
              if ($ry + $tilesizeR -gt $height) { $endposSy = $height }
              else { $endposSy = $ry + $tilesizeR }
              for ($sx = $rx; $sx -lt $endposSx; $sx += $tilesizeS) {
                for ($sy = $ry; $sy -lt $endposSy; $sy += $tilesizeS) {
                  $tstareaS = "${tilesizeS}x${tilesizeS}+${sx}+${sy}"
                  $mtrx = Get-MTRX $tstPathA $tstPathB $tstareaS -SSIMchk $false
                  $PSNR = $mtrx.PSNR
                # $SSIM = $mtrx.SSIM  # -SSIMchk $false時は戻り値なしとなるためコメントアウトしておく。
                  if ($PSNR -lt $PSNRmin) { $PSNRmin = $PSNR }
                  if ($SSIM -lt $SSIMmin) { $SSIMmin = $SSIM }
                  if ([double]$PSNR -lt $psnrTshNG) { break Tileloop }
                  if ([double]$SSIM -lt $ssimTshNG) { break Tileloop }
                  else {
                    Write-Host ("`r$counter [CheckS] {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $DistortionCause),($msgtmp = "${dirName}\${chkName} PSNR Check now.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor DarkRed -NoNewline
  } } } } } } } } }
  for ($di=0; $di -lt 5; $di++) {
    try { [System.IO.File]::Delete($tstPathA); break }
    catch { Start-Sleep -Milliseconds 200 }
  }
  for ($di=0; $di -lt 5; $di++) {
    try { [System.IO.File]::Delete($tstPathB); break }
    catch { Start-Sleep -Milliseconds 200 }
  }
  $result.PSNR = $PSNRmin
  $result.SSIM = $SSIMmin
  return $result  # 戻り値: [ordered]@{ PSNR = <double>; SSIM = <double> }
}



######## MAIN ########
# 初期値を展開する。
$ainit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
# (参照対象：$psnrTshNG）
$tinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
$mtcfg = Chk-Mediatype  $srcPath
$NoiseLv = $mtcfg.lv
$quality = $mtcfg.qt
$sinit = Resolve-Scale $ainit $tinit $NoiseLv $quality
# (更新対象：$AImodel, $width, $height, $needupscl, $scaleratio, $Upscaler, $ModelDir, $deNoiseLv, $Namefx)
$sinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }

# デノイズ処理のみを省略する設定
  if ($x1denoSKIP -and $scaleratio -eq 1 -and $NoiseLv -le $x1dskipTsh) {
    $needupscl = $false
    $Namefx = $srcName
    }
# アップスケール出力前準備
  if ($needupscl) { $retry = 0 }
  else { 
    $upPath = $srcPath  # WebP変換後の元ファイル削除判断用の仕掛け
    $PSNRmin = 81.0931072  # ログに明確な異常値を残す。
    $SSIMmin = 1.45141919  # （桁揃えのため数値以外扱えない）
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
    $altmode = Switch-altmodloop $ainit $AImodel $scaleratio $NoiseLv
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
  $umtrx = ChkLoop-Metrics $srcPath $upPath $tinit $YUVmode $counter $AImodel
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
      $altmode = Switch-altmodloop $ainit $AImodel $scaleratio $NoiseLv
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
  Write-Host ("`r$counter  [WAIT]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),(("${wpRltv}  to be created...     ")[-48..-1] -join '')) -NoNewline -ForegroundColor DarkGray
  Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "${wpRltv}  to be created...     ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor DarkGray
  $waitCount = 0
  while (-not [System.IO.File]::Exists($wpPath) -and $waitCount -lt 50) { Start-Sleep -Milliseconds 200; $waitCount++ }
  Write-Host ("`r$counter  [PASS]  {0,-32} {1,-48}" -f ("(PSNR={0,5:F2}dB by {1})" -f $PSNRmin, $AImodel),($msgtmp = "${wpRltv}  to be created...OK!  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor DarkGray
  $logBuffer1 += ("$counter	[PASS]	(PSNR={0,10:F7}dB,SSIM={1,10:F8} by {2})	{3}	created successfully.	(try {4}/{5})" -f $PSNRmin, $SSIMmin, $AImodel, $wpRltv, $retry, $maxRetry)

# アプスケ画像とWebPとのPSNRもみたい場合。$webpQtestで有効無効を切り替える。
  if ($webpQtest) {
    $YUVmode = $true  # 変換先WebPが必ずYUV420のためそちらに揃える。
    $wmtrx = ChkLoop-Metrics $upPath $wpPath $tinit2 $YUVmode $counter 'Webp_Lossy' 
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