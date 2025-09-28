param(
  [string]$TgtFile,     # 処理対象ファイル
  [string]$ScriptHome   # 親スクリプトの場所
)
# 入力が無い場合は何もしないで終了。
  if (-not $TgtFile -or -not $ScriptHome) {
  Write-Host "Usage error: -TgtFile と -ScriptHome の両方を指定してください。  " -ForegroundColor Red
  exit 1
  }
# 利用するGPUの選択（auto,"0","0,1"など。タイルサイズとスレッド割当ても要適宜変更）
  $gpuselect = "auto"
# 画像を分割するサイズ（大きいほどタイルの継目が減るけどメモリを食う。）
  $tilesize = "256"
# スレッド割当てと比率（load:proc:save）
  $threadset = "1:4:4"
# アップスケールの再試行許容回数
  $maxRetry = 8
# テンポラリと元画像の削除の実施
  $deltemp = $true
# 拡大を省略する長辺の閾値
  $lsthlength = 3840
# 拡大を省略する両辺の閾値
  $bsthlength = 2048
# 2倍に拡大する短辺の閾値（これ以下は3倍）
  $ssthlength = 1024

# 対象ファイルの周辺情報を取得
  $src = $TgtFile
  $tdir = Split-Path -Parent $src
  $fdNam = Split-Path -Leaf $tdir
  $base = [System.IO.Path]::GetFileNameWithoutExtension($src)
  $ext = [System.IO.Path]::GetExtension($src).ToLower()

# ロッシー形式ならデノイズON、ロスレス形式はデノイズOFF
  $lsquality = "Undefined"
  switch -Regex ($ext) {
    '\.bmp' {
      $base = "${base}_nf"
      $lsquality = "Lossless"
      $denoise = -1
    }
    '\.jpe?g' {
      $info = & magick identify -verbose "$src"
      $qline = $info | Select-String "Quality: (\d+)"
      if ($qline) {
        $lsquality = [int]$qline.Matches[0].Groups[1].Value
        $base = "${base}_dn"
        if ($lsquality -lt 70) {
          $denoise = 3
        } elseif  ($lsquality -lt 80) { 
          $denoise = 2
        } elseif  ($lsquality -lt 90) { 
          $denoise = 1
        } else {  $denoise = 0 }
      } else { 
        $base = "${base}_dn"
        $denoise = 0
      }
    }
    '\.png' {
      $base = "${base}_nf"
      $lsquality = "Lossless"
      $denoise = -1
    }
    '\.webp' {
      # magick identify を使って WebP の圧縮タイプを調べる
      $info = & magick identify -verbose "$src"
      $lline  = $info | Select-String "WebP Lossless"
      if ($lline) {
        $base = "${base}_nf"
        $lsquality = "Lossless"
        $denoise = -1
      } else { 
        $base = "${base}_dn"
        $lsquality = "unknown"
        $denoise = 0 
      }
    }
    default {
      Write-Host "`rSkip: $src (unsupported extension)  " -NoNewline -ForegroundColor Yellow
      exit 0   # スキップして正常終了
    }
  }
# 拡大倍率の調整。magick identify を使って 画像のサイズを確認する
  $width  = & magick identify -format "%w" "$src"
  $height = & magick identify -format "%h" "$src"
  $width  = [int]$width
  $height = [int]$height
  if ( ($width -ge $lsthlength -or $height -ge $lsthlength) -or
       ($width -ge $bsthlength -and $height -ge $bsthlength) ) {
    if ($ext -eq ".webp" -and $denoise -ne -1) {
      # 元からLossyのWebpはデノイズや再梱包してもディティールが潰れてサイズも増えてと、あまりメリット無さそうなので放置。
      Write-Host "`rSkip: ${base} is No need to process. ${width}px x ${height}px Quality=${lsquality}  " -NoNewline -ForegroundColor Blue
      exit 0   # スキップして正常終了
    } elseif ($ext -eq ".bmp" -or $ext -eq ".png" -or $ext -eq ".webp") {
      $needupscl = $false
      $base = "${base}x1"
      Write-Host "`rConvert Only: ${base}, is large enough. ${width}px x ${height}px Quality=${lsquality}  " -NoNewline -ForegroundColor Blue
    } else {
      $needupscl = $True
      $Upscaler = Join-Path $ScriptHome "#sca\waifu2x-ncnn-vulkan.exe"
      $ModelDir = Join-Path $ScriptHome "#sca\models-cunet"
      $scaleratio = 1
      $base = "${base}f${denoise}"
      Write-Host "`rDenoise: ${base}, is large enough. ${width}px x ${height}px Quality=${lsquality}  " -NoNewline -ForegroundColor Blue
    }
  } elseif ($width -ge $ssthlength -and $height -ge $ssthlength) {
    $needupscl = $True
    $Upscaler = Join-Path $ScriptHome "#sca\realcugan-ncnn-vulkan.exe"
    $ModelDir = Join-Path $ScriptHome "#sca\models-pro"
    if ($denoise -eq 1) { $denoise = 0 }
    if ($denoise -eq 2) { $denoise = 3 }
    $scaleratio = 2
    $base = "${base}x2"
    Write-Host "`rMag x2: ${base}, ${width}px x ${height}px Quality=${lsquality}  " -NoNewline -ForegroundColor Green
  } else {
    $needupscl = $True
    $Upscaler = Join-Path $ScriptHome "#sca\realcugan-ncnn-vulkan.exe"
    $ModelDir = Join-Path $ScriptHome "#sca\models-pro"
    if ($denoise -eq 1) { $denoise = 0 }
    if ($denoise -eq 2) { $denoise = 3 }
    $scaleratio = 3
    $base = "${base}x3"
    Write-Host "`rMag x3: ${base}, ${width}px x ${height}px Quality=${lsquality}  " -NoNewline -ForegroundColor Magenta
  }
# アップスケール出力
  if ($needupscl) {
    $upfile = "temp_upscale_${base}.png"
    $uppath = Join-Path $tdir $upfile
    $retry = 0
  } else {  # 拡大処理が不要な場合は中間ファイルなし。
    $uppath = $src 
  }
  while ($needupscl -and $retry -lt $maxRetry) {
    & $Upscaler -i $src -o $uppath -x -n $denoise -s $scaleratio -g $gpuselect -t $tilesize -j $threadset -m $ModelDir 2> $null
    if ($LASTEXITCODE -eq 0 -and [System.IO.File]::Exists($uppath)) {
      $needupscl = $false
      Write-Host "`rUpscaling $upfile is done. (try $($retry+1)/$maxRetry)...  " -NoNewline
    # アップスケーラからエラーが返ってきてるかアップスケール後のファイルが無い場合。
    } else {
      $retry++
      Write-Host "`r[FAIL] Upscaling is fail. ${upfile} EXTCODE = $LASTEXITCODE (try $($retry+1)/$maxRetry)...  " -NoNewline -ForegroundColor DarkRed
      Start-Sleep -Seconds 2  # 少し待ってからリトライ
    }
  }
  if ($needupscl) {
    Write-Host "`r[CRITICAL] Upscaling failed for after $maxRetry attempts  " -ForegroundColor Red
    return  # この画像は拡大工程をスキップ（処理を止めたいなら throw に変更）
  }
# WebPに変換
  $webp = Join-Path $tdir ($base + ".webp")
  magick "$uppath" `
    -quality 90 `
    -define webp:method=6 `
    -define webp:segments=4 `
    -define webp:sns-strength=0 `
    -define webp:filter-strength=0 `
    -define webp:alpha-quality=100 `
    "$webp"
# 出力待ち
  Write-Host "`rWaiting for $base.webp to be created...  " -NoNewline -ForegroundColor DarkGray
  while (-not [System.IO.File]::Exists($webp)) {
      Start-Sleep -Milliseconds 200
  }
  Write-Host "OK!  " -NoNewline
# 元画像と中間PNGを削除
  if ($deltemp) {
    [System.IO.File]::Delete($src)
    if ($uppath -ne $src) {
      [System.IO.File]::Delete($uppath)
    }
  }

<#-h                   show this help
  -v                   verbose output
  -i input-path        input image path (jpg/png/webp) or directory
  -o output-path       output image path (jpg/png/webp) or directory
  -n noise-level       denoise level (-1/0/1/2/3, default=-1)
  -s scale             upscale ratio (1/2/3/4, default=2)
  -t tile-size         tile size (>=32/0=auto, default=0) can be 0,0,0 for multi-gpu
  -c syncgap-mode      sync gap mode (0/1/2/3, default=3)
  -m model-path        realcugan model path (default=models-se)
  -g gpu-id            gpu device to use (-1=cpu, default=auto) can be 0,1,2 for multi-gpu
  -j load:proc:save    thread count for load/proc/save (default=1:2:2) can be 1:2,2,2:2 for multi-gpu
  -x                   enable tta mode
  -f format            output image format (jpg/png/webp, default=ext/png)#>
