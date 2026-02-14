# PSNR/SSIMのテスト関数。
# PSNRは通常行頭（括弧外）がPSNRと想定、SSIMは括弧内がSSIMと想定。
# SSIMはなぜか相関が高いほど0に近似する値が返ってくるため相補値で返しています。
function Get-Metrics($srcPath,$tstPath,$tstarea,$SSIMchk) {
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

function Write-metricsInfoLine ($msg1, $winit, $PSNRmin, $fPSNR, $DistortionCause, $fileRltv, $msg2, $color) {
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
  Write-Host $message -ForegroundColor $color -NoNewline:$winit.nnl
}



# 主にPSNRをタイルに別けて検査する。
function Search-Metrics ($srcPath, $chkPath, $testVal, $YUVmode, $winit, $DistortionCause) {
  # ($psnrTshOK $FApsnnrTsh $FAssimTsh $psnrTshVE $psnrTshNG $ssimTshOK $ssimTshVE $ssimTshNG $tilesizeL $tilesizeR $tilesizeSの展開)
  $testVal.psobject.Properties | ForEach-Object { Set-Variable -Name $_.Name -Value $_.Value -Scope Local }
  
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
  #拡大縮小に伴うエッジアーティファクトを評価外にしたいので周辺1pxを除去する。
  if ($width -ge 3 -and $height -ge 3 ){
    $width  = $width-2
    $height = $height-2
    $cropGeom = "${width}x${height}+1+1"
    & magick "$tstPathA" -colorspace sRGB -set colorspace sRGB -crop $cropGeom +repage "$tstPathA"
    & magick "$tstPathB" -colorspace sRGB -set colorspace sRGB -crop $cropGeom +repage "$tstPathB"
  }
  
  $result = [ordered]@{ PSNR = 0.0; SSIM = 0.0 }
  $mtrx = Get-Metrics $tstPathA $tstPathB "${width}x${height}+0+0" -SSIMchk:$true
  $PSNRmin = $fPSNR = $PSNR = $mtrx.PSNR
  $SSIMmin = $fSSIM = $SSIM = $mtrx.SSIM

  # 画像断片の評価を取得。
  :Tileloop
  for ($lx = 0; $lx -lt $width; $lx += $tilesizeL) {
    for ($ly = 0; $ly -lt $height; $ly += $tilesizeL) {
      # 全体でコケてるなら初手でループ終了。
      if ([double]$fPSNR -lt $FApsnrTsh) { break Tileloop }
      if ([double]$fSSIM -lt $FAssimTsh) { break Tileloop }
      # 全体に合格しているなら本ループへ
      $tstareaL = "${tilesizeL}x${tilesizeL}+${lx}+${ly}"
      $mtrx = Get-Metrics $tstPathA $tstPathB $tstareaL -SSIMchk $true
      $PSNR = $mtrx.PSNR
      $SSIM = $mtrx.SSIM
      if ($PSNR -lt $PSNRmin) { $PSNRmin = $PSNR }
      if ($SSIM -lt $SSIMmin) { $SSIMmin = $SSIM }
      if ([double]$PSNR -lt $psnrTshNG) { break Tileloop }
      if ([double]$SSIM -lt $ssimTshNG) { break Tileloop }
      if ([double]$PSNR -lt $psnrTshOK -or [double]$SSIM -lt $ssimTshOK ) {
        Write-metricsInfoLine "`r [CheckL] " $winit $PSNRmin $fPSNR $DistortionCause "${dirName}\${chkName}" 'PSNR Check now.' 'DarkGreen'
        if ($lx + $tilesizeL -gt $width) { $endposRx = $width }
        else { $endposRx = $lx + $tilesizeL }
        if ($ly + $tilesizeL -gt $height) { $endposRy = $height }
        else { $endposRy = $ly + $tilesizeL }
        for ($rx = $lx; $rx -lt $endposRx; $rx += $tilesizeR) {
          for ($ry = $ly; $ry -lt $endposRy; $ry += $tilesizeR) {
            $tstareaR = "${tilesizeR}x${tilesizeR}+${rx}+${ry}"
            $mtrx = Get-Metrics $tstPathA $tstPathB $tstareaR -SSIMchk $false
            $PSNR = $mtrx.PSNR  # SSIMのOKとVEを同値にしておくと一番細かいタイルサイズまでチェックできる。
          # $SSIM = $mtrx.SSIM  # この際、-SSIMchk $false時は戻り値なしとなるためこの行をコメントアウトしておく。
            if ($PSNR -lt $PSNRmin) { $PSNRmin = $PSNR }
            if ($SSIM -lt $SSIMmin) { $SSIMmin = $SSIM }
            if ([double]$PSNR -lt $psnrTshNG) { break Tileloop }
            if ([double]$SSIM -lt $ssimTshNG) { break Tileloop }
            if ([double]$PSNR -lt $psnrTshVE -or [double]$SSIM -lt $ssimTshVE ) {
              Write-metricsInfoLine "`r [CheckR] " $winit $PSNRmin $fPSNR $DistortionCause "${dirName}\${chkName}" 'PSNR Check now.' 'DarkYellow'
              if ($rx + $tilesizeR -gt $width) { $endposSx = $width }
              else { $endposSx = $rx + $tilesizeR }
              if ($ry + $tilesizeR -gt $height) { $endposSy = $height }
              else { $endposSy = $ry + $tilesizeR }
              for ($sx = $rx; $sx -lt $endposSx; $sx += $tilesizeS) {
                for ($sy = $ry; $sy -lt $endposSy; $sy += $tilesizeS) {
                  $tstareaS = "${tilesizeS}x${tilesizeS}+${sx}+${sy}"
                  $mtrx = Get-Metrics $tstPathA $tstPathB $tstareaS -SSIMchk $false
                  $PSNR = $mtrx.PSNR
                # $SSIM = $mtrx.SSIM  # -SSIMchk $false時は戻り値なしとなるためコメントアウトしておく。
                  if ($PSNR -lt $PSNRmin) { $PSNRmin = $PSNR }
                  if ($SSIM -lt $SSIMmin) { $SSIMmin = $SSIM }
                  if ([double]$PSNR -lt $psnrTshNG) { break Tileloop }
                  if ([double]$SSIM -lt $ssimTshNG) { break Tileloop }
                  else {
                    Write-metricsInfoLine "`r [CheckS] " $winit $PSNRmin $fPSNR $DistortionCause "${dirName}\${chkName}" 'PSNR Check now.' 'DarkRed'
  } } } } } } } } }
  for ($di=0; $di -lt 5; $di++) {
    try { [System.IO.File]::Delete($tstPathA); break }
    catch { Start-Sleep -Milliseconds 200 }
  }
  for ($di=0; $di -lt 5; $di++) {
    try { [System.IO.File]::Delete($tstPathB); break }
    catch { Start-Sleep -Milliseconds 200 }
  }
  $result.fPSNR = $fPSNR
  $result.fSSIM = $fSSIM
  $result.PSNR = $PSNRmin
  $result.SSIM = $SSIMmin
  return $result  # 戻り値: [ordered]@{ PSNR = <double>; SSIM = <double> ; fPSNR = <double>; fSSIM = <double>}
}

Export-ModuleMember -Function Get-Metrics, Search-Metrics
