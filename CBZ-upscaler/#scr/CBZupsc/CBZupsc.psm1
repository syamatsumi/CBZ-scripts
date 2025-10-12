# ロッシー形式ならデノイズON、ロスレス形式はデノイズOFF
function Get-Mediatype ($srcPath) {
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

# 実行不能な設定の組み合わせを回避する。
function Update-Paths ($dinit, $AImodel, $scaleratio, $NoiseLv) {
  # (ここで必要な変数：$srcName, $scrHome, $exeDir)
  $dinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }

  if ($AImodel -eq 'realcugan-pro') {
    $Upscaler = Join-Path $scrHome $exeDir 'realcugan-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-pro'
    if     ($NoiseLv -eq  0) { $deNoiseLv = 0; $Namefx = "${srcName}_dn0pro${scaleratio}x" }
    elseif ($NoiseLv -eq  1) { $deNoiseLv = 0; $Namefx = "${srcName}_dn0pro${scaleratio}x" }
    elseif ($NoiseLv -eq  2) { $deNoiseLv = 3; $Namefx = "${srcName}_dn3pro${scaleratio}x" }
    elseif ($NoiseLv -eq  3) { $deNoiseLv = 3; $Namefx = "${srcName}_dn3pro${scaleratio}x" }
    else                    { $deNoiseLv = -1; $Namefx = "${srcName}_nodpro${scaleratio}x" }
  }
  elseif ($AImodel -eq 'realcugan-se') {
    $Upscaler = Join-Path $scrHome $exeDir 'realcugan-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-se'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodse${scaleratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}se${scaleratio}x" }
  }
  elseif ($AImodel -eq 'waifu2x-cunet') {
    if ($scaleratio -eq 3) { $scaleratio = 2 }
    $Upscaler = Join-Path $scrHome $exeDir 'waifu2x-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-cunet'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodcunet${scaleratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}cunet${scaleratio}x" }
  }
  elseif ($AImodel -eq 'waifu2x-art') {
    if ($scaleratio -eq 3) { $scaleratio = 2 }
    $Upscaler = Join-Path $scrHome $exeDir 'waifu2x-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-art'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodart${scaleratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}art${scaleratio}x" }
  }
  elseif ($AImodel -eq 'waifu2x-photo') {
    if ($scaleratio -eq 3) { $scaleratio = 2 }
    $Upscaler = Join-Path $scrHome $exeDir 'waifu2x-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-photo'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodphoto${scaleratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}photo${scaleratio}x" }
  }
  else {
    Write-Warning "Unknown model '$AImodel'. Defaulting to realcugan-se."
    $AImodel  = 'realcugan-se'
    $Upscaler = Join-Path $scrHome $exeDir 'realcugan-ncnn-vulkan.exe'
    $ModelDir = Join-Path $scrHome $exeDir 'models-se'
    if ($NoiseLv -eq -1) { $deNoiseLv = -1; $Namefx = "${srcName}_nodse${scaleratio}x" }
    else  { $deNoiseLv = $NoiseLv; $Namefx = "${srcName}_dn${NoiseLv}se${scaleratio}x" }
  }
  [PSCustomObject]@{
    ai = $AImodel
    lv = $deNoiseLv
    m  = $ModelDir
    n  = $Namefx
    u  = $Upscaler
    x  = $scaleratio
  }
}

# 拡大倍率とデノイズ有無の組み合わせ設定。 ##### 兼第一選択の控え #####
function Resolve-Scale ($dinit, $tinit, $NoiseLv, $quality, $counter) {
  # (ここで必要な変数：srcName, srcExt, $srcPath, $rltvPath)
  $dinit.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
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
      $genpath = Update-Paths $dinit 'waifu2x-cunet' 1 $NoiseLv
      Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is large enough.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Blue -NoNewline
    # 拡大対象外かつWebp形式以外（実質JPEG等倍）
    } else {
      $needupscl  = $true
      $scaleratio = 1
      $genpath = Update-Paths $dinit 'waifu2x-cunet' 1 $NoiseLv
      Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is large enough.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Blue -NoNewline
    }
  # 拡大対象x2（短辺が閾値以上）
  } elseif ($width -ge $ShortSideThlen -and $height -ge $ShortSideThlen) {
    $needupscl = $true
    $scaleratio = 2
    $genpath = Update-Paths $dinit $AImodel 2 $NoiseLv
    Write-Host ("`r$counter  [CHECK] {0,-32} {1,-48}" -f ("({0} x {1}px Quality={2})" -f $width,$height,$quality),($msgtmp = "${rltvPath} is Enlarge to x2.  ").Substring([Math]::Max(0, $msgtmp.Length - 48)) ) -ForegroundColor Green -NoNewline
  # 拡大対象x3（短辺が閾値より小さい）
  } else {
    $needupscl = $true
    $scaleratio = 3
    $genpath = Update-Paths $dinit $AImodel 3 $NoiseLv
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
function Switch-altmodloop ($dinit, $AImodel, $scaleratio, $NoiseLv) {
  if ($scaleratio -eq 1) {
    # RealCuGANのデノイズのみモデルは開発中のためWaifu2xのみで実施
    if     ($AImodel -eq 'waifu2x-cunet') { $genpath = Update-Paths $dinit 'waifu2x-art'   1 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-art')   { $genpath = Update-Paths $dinit 'waifu2x-photo' 1 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-photo') { $genpath = Update-Paths $dinit 'waifu2x-cunet' 1 $NoiseLv }
  }
  elseif ($scaleratio -eq 2) {
    if     ($AImodel -eq 'realcugan-pro') { $genpath = Update-Paths $dinit 'realcugan-se'  2 $NoiseLv }
    elseif ($AImodel -eq 'realcugan-se')  { $genpath = Update-Paths $dinit 'waifu2x-cunet' 2 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-cunet') { $genpath = Update-Paths $dinit 'waifu2x-art'   2 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-art')   { $genpath = Update-Paths $dinit 'waifu2x-photo' 2 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-photo') { $genpath = Update-Paths $dinit 'realcugan-pro' 2 $NoiseLv }
  }
  elseif ($scaleratio -eq 3) {
    if     ($AImodel -eq 'realcugan-pro') { $genpath = Update-Paths $dinit 'realcugan-se'  3 $NoiseLv }
    elseif ($AImodel -eq 'realcugan-se')  { $genpath = Update-Paths $dinit 'realcugan-pro' 4 $NoiseLv }
    # Waifu2xの3倍モデルは無いので4倍（x2モデル2回）にして回避できないかトライ。
  }
  elseif ($scaleratio -eq 4) {
    if     ($AImodel -eq 'realcugan-pro') { $genpath = Update-Paths $dinit 'realcugan-se'  4 $NoiseLv }
    elseif ($AImodel -eq 'realcugan-se')  { $genpath = Update-Paths $dinit 'waifu2x-cunet' 4 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-cunet') { $genpath = Update-Paths $dinit 'waifu2x-art'   4 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-art')   { $genpath = Update-Paths $dinit 'waifu2x-photo' 4 $NoiseLv }
    elseif ($AImodel -eq 'waifu2x-photo') { $genpath = Update-Paths $dinit 'realcugan-pro' 4 $NoiseLv }
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

Export-ModuleMember -Function Get-Mediatype, Update-Paths, Resolve-Scale, Switch-altmodloop
