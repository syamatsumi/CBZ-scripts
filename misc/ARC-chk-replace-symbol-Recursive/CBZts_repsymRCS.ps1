param(
  [string]$TgtRoot = $PSScriptRoot,
  [switch]$NoConfirm
)
# Replace Symbol script （文字の入替えスクリプト）
Get-ChildItem -LiteralPath $TgtRoot -Recurse |
  Sort-Object { $_.FullName.Length } -Descending |  # 深い階層から実施
  ForEach-Object {
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
    $new = $new -replace '\(', '（'  # 括弧
    $new = $new -replace '\)', '）'  # 括弧
    $new = $new -replace '\[', '［'  # 配列
    $new = $new -replace '\]', '］'  # 配列
    $new = $new -replace '\{', '｛'  # ブロック
    $new = $new -replace '\}', '｝'  # ブロック

    if ($old -ne $new) {
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
