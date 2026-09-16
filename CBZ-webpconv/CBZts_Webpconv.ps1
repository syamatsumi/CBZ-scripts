param(
  [Parameter(Mandatory = $true)]
  [string]$TgtRoot,

  [ValidateRange(0, 100)]
  [int]$Quality = 90,

  [string]$Magick = 'magick.exe',
  [string]$ExifTool = (Join-Path $PSScriptRoot 'exiftool\exiftool.exe'),
  [string]$ExifConfig = (Join-Path $PSScriptRoot 'CBZts_Webpconv_exiftool.config')
)

# --------------------------------------------------------
# 変換対象のリスト。既存の WebP はそのまま残すため未記載。
# --------------------------------------------------------
$ImageExtensions = @(
  '.jpg', '.jpeg', '.png', '.bmp', '.gif',
  '.tif', '.tiff', '.avif', '.heic', '.heif', '.jxl'
)

# ------------------------
# 関連モジュールのパス解決
# ------------------------
$ErrorActionPreference = 'Stop'
function Resolve-CommandPath([string]$CommandName) {
  if ([System.IO.Path]::IsPathRooted($CommandName)) {
    if (-not (Test-Path -LiteralPath $CommandName -PathType Leaf)) {
      throw "必要なコマンドが見つかりません: $CommandName"
    }
    return (Get-Item -LiteralPath $CommandName).FullName
  }

  $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $cmd) {
    throw "必要なコマンドが見つかりません: $CommandName"
  }
  return $cmd.Source
}

$MagickPath = Resolve-CommandPath $Magick
$ExifToolPath = Resolve-CommandPath $ExifTool
$Root = (Get-Item -LiteralPath $TgtRoot).FullName

# ----------------------
# ディレクトリ日時の控え
# ----------------------
$Directories = @((Get-Item -LiteralPath $Root)) + @(
  Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force
)
$DirectoryTimes = @(
  foreach ($dir in $Directories) {
    [pscustomobject]@{
      Path              = $dir.FullName
      CreationTimeUtc   = $dir.CreationTimeUtc
      LastWriteTimeUtc  = $dir.LastWriteTimeUtc
      LastAccessTimeUtc = $dir.LastAccessTimeUtc
    }
  }
)
$ErrorActionPreference = 'Continue'

# --------------
# 画像処理ループ
# --------------
try {
  $Images = @(
    Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
      Where-Object { $ImageExtensions -contains $_.Extension.ToLowerInvariant() }
  )

  $Images | ForEach-Object -Parallel {
    $ErrorActionPreference = 'Stop'
    $MagickPath        = $using:MagickPath
    $Quality           = $using:Quality
    $ExifToolPath      = $using:ExifToolPath
    $ExifConfig        = $using:ExifConfig
    $src               = $_
    $srcName           = $src.Name
    $srcBsName         = $src.BaseName
    $srcDirName        = $src.DirectoryName
    $srcFlName         = $src.FullName
    $ext               = $src.Extension.ToLowerInvariant()
    $CreationTimeUtc   = $src.CreationTimeUtc
    $LastWriteTimeUtc  = $src.LastWriteTimeUtc
    $LastAccessTimeUtc = $src.LastAccessTimeUtc
    $Attributes        = $src.Attributes
    $dstBsName = $srcBsName + ($ext -replace '^\.', '_')
    $dstName = $dstBsName + '.webp'
    $dstPath = Join-Path $srcDirName $dstName
    # ----------------------
    # 仮出力先と出力先の決定
    # ----------------------
    if (Test-Path -LiteralPath $dstPath) {
      Write-Warning "WebP 出力先が既に存在します。: $dstPath"
      return
    }
    $tmpPath = Join-Path $srcDirName ('_cbzts_tmp_' + $dstBsName + '.webp')
    $i = 0
    while (Test-Path -LiteralPath $tmpPath) {
      $i++
      $tmpPath = Join-Path $srcDirName ('_cbzts_tmp_' + $dstBsName + "_$i.webp")
    }
    Write-Host ('WEBP: ' + $srcFlName)
    Write-Host ('   -> ' + $dstPath)

    # ---------------------
    # ImageMagickによる処理
    # ---------------------
    try {
      & $MagickPath $srcFlName '-quality' $Quality '-define' 'webp:method=6' $tmpPath
    } catch {
      Write-Warning "ImageMagick の実行中にエラーが発生しました。: $($srcFlName)"
      Write-Warning $_.Exception.Message
      return
    } if (-not (Test-Path -LiteralPath $tmpPath)) {
      Write-Warning "出力ファイルがありません。: $($srcFlName)"
      Write-Warning $LASTEXITCODE
      return
    } elseif ($LASTEXITCODE -ne 0 ) {
      Write-Warning "ImageMagick から例外通知あり。: $($srcFlName)"
      Write-Warning $LASTEXITCODE
      Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue 
      return
    }

    # ------------------------------------------
    # Exif Toolによるメタデータの移植。
    # 不要な系統はコメントアウトで対応すること。
    # ------------------------------------------
    Push-Location -LiteralPath $srcDirName
    $ErrorActionPreference = 'Continue'
    try {
      $tmpName = [System.IO.Path]::GetFileName($tmpPath)

      Write-Host '  [META] EXIF'
      & $ExifToolPath `
      '-config' $ExifConfig `
      '-overwrite_original' `
      '-TagsFromFile'  $srcName `
      '-EXIF:all' `
      $tmpName

      Write-Host '  [META] XMP'
      & $ExifToolPath `
      '-config' $ExifConfig `
      '-overwrite_original' `
      '-TagsFromFile'  $srcName `
      '-XMP:all' `
      $tmpName

      Write-Host '  [META] ICC Profile'
      & $ExifToolPath `
      '-config' $ExifConfig `
      '-overwrite_original' `
      '-TagsFromFile'  $srcName `
      '-ICC_Profile' `
      $tmpName

      # Forge/A1111 系 の出力PNGに含まれるパラメーターテキストを
      #  WebP の XMP-cbzts:PNGparam へ移す。
      Write-Host '  [META] AI generation info'
      if ($ext -eq '.png') {
        & $ExifToolPath `
        '-config' $ExifConfig `
        '-overwrite_original' `
        '-TagsFromFile'  $srcName `
        '-XMP-cbzts:PNGparam<PNG:Parameters' `
        $tmpName
      }
    } catch {
      Write-Warning "メタデータ移植にあたって例外が発生している。: $($srcFlName)"
      Write-Warning $_.Exception.Message
    } finally { 
      $ErrorActionPreference = 'Stop'
      Pop-Location
    }

    try {
      if (-not (Test-Path -LiteralPath $tmpPath -PathType Leaf)) {
        Write-Warning "メタデータ操作中にファイルが行方不明になった。: $($srcFlName)"
        return
      }
      Move-Item -LiteralPath $tmpPath -Destination $dstPath
    } catch {
      Write-Warning "テンポラリの改名時にエラー発生: $($srcFlName)"
      Write-Warning $_.Exception.Message
      return
    }

    # ------------------
    # ファイル属性の操作
    # ------------------
    # NTFS 側のファイル日時・属性も元画像に揃える。
    try {
      $dst = Get-Item -LiteralPath $dstPath
      $dst.CreationTimeUtc   = $CreationTimeUtc
      $dst.LastWriteTimeUtc  = $LastWriteTimeUtc
      $dst.LastAccessTimeUtc = $LastAccessTimeUtc
      $dst.Attributes        = $Attributes
    } catch {
      Write-Warning "成果物データの処理中にエラー発生: $tmpPath"
      Write-Warning $_.Exception.Message
      # この時点で作成ファイルがテンポラリのまま残ってる場合は削除
      if (Test-Path -LiteralPath $tmpPath) {
        Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
      }
    } # 変換元ファイルを削除。デバッグ時は下をコメントアウト。
    Remove-Item -LiteralPath $srcFlName -Force
  } -ThrottleLimit 8
  # ループ終端
}

# ------------------
# フォルダ属性の操作
# ------------------
finally {
  # 変換により変わったディレクトリ日時を戻す。深い階層から戻す。
  foreach ($saved in ($DirectoryTimes | Sort-Object { $_.Path.Length } -Descending)) {
    if (Test-Path -LiteralPath $saved.Path -PathType Container) {
      $dir = Get-Item -LiteralPath $saved.Path -Force
      $dir.CreationTimeUtc   = $saved.CreationTimeUtc
      $dir.LastWriteTimeUtc  = $saved.LastWriteTimeUtc
      $dir.LastAccessTimeUtc = $saved.LastAccessTimeUtc
    }
  }
}