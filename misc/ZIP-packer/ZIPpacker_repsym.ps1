param(
  [string]$TgtRoot = $PSScriptRoot,
  [switch]$NoConfirm
)
# Replace Symbol script （文字の入替えスクリプト）
Get-ChildItem -LiteralPath $TgtRoot | ForEach-Object {
  $old = $_.Name  # 後の比較で利用する
  $new = $old
  $new = $new -replace '&', '＆'   # アンパサンド
  $new = $new -replace '!', '！'   # エクスクラメーション
  $new = $new -replace '%', '％'   # パーセント
  $new = $new -replace ';', '；'   # セミコロン
  $new = $new -replace '=', '＝'   # イコール
  $new = $new -replace ',', '，'   # カンマ
  $new = $new -replace '`', '｀'   # バッククォート
  $new = $new -replace '\^', '＾'  # キャレット
  $new = $new -replace '\$', '＄'  # ドル記号
  $new = $new -replace '\(', '〈'  # 開き丸括弧を山括弧に
  $new = $new -replace '\)', '〉'  # 閉じ丸括弧を山括弧に
  $new = $new -replace '\[', '〔'  # 開き角括弧を亀甲括弧に
  $new = $new -replace '\]', '〕'  # 閉じ角括弧を亀甲括弧に
  $new = $new -replace '\{', '｛'  # 開きコードブロックを全角に
  $new = $new -replace '\}', '｝'  # 閉じコードブロックを全角に
  $new = $new -replace '（', '〈'  # 開き丸括弧を山括弧に
  $new = $new -replace '）', '〉'  # 閉じ丸括弧を山括弧に
  $new = $new -replace '［', '〔'  # 開き角括弧を亀甲括弧に
  $new = $new -replace '］', '〕'  # 閉じ角括弧を亀甲括弧に

  # Mac由来の分解された濁点・半濁点などを通常の合成文字へ戻す
  $new = $new.Normalize([System.Text.NormalizationForm]::FormC)

  # 衝突回避用の変数準備
  $number = 1
  $parentPath = Split-Path -LiteralPath $_.FullName
  if ($_.PSIsContainer) {
    $baseName = $new
    $extension = ''
  } else {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($new)
    $extension = [System.IO.Path]::GetExtension($new)
  }

  # 新旧比較で差分があれば処理。
  # Unicode正規化で同一扱いされる文字列でも、差分があれば検出する。
  if (-not [string]::Equals($old, $new, [System.StringComparison]::Ordinal)) {
    $newPath = Join-Path -Path $parentPath -ChildPath $new
    # 書換え後のパスがすでにある場合はカッコ番号付けて回避
    while (Test-Path -LiteralPath $newPath) {
      $new = "$baseName❨$number❩$extension"
      $newPath = Join-Path -Path $parentPath -ChildPath $new
      $number++
    }
    Write-Host "befr : $old"
    Write-Host "aftr : $new"
    if ($NoConfirm) {
      Rename-Item -LiteralPath $_.FullName -NewName $new
    } else {
      $ans = Read-Host "書き換えますか？ Enterで続行 書き換えない場合はNを押して続行。"
      if ($ans -notmatch "^n") {
        Rename-Item -LiteralPath $_.FullName -NewName $new
      }
    }
  }
}
