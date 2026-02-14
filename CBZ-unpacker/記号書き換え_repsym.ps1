param(
    [string]$TgtRoot = $PSScriptRoot
)
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
    $new = $new -replace '\^', '^'  # キャレット
    $new = $new -replace '\$', '＄'  # ドル記号

    if ($old -ne $new) {
        Write-Host "befr : $old"
        Write-Host "aftr : $new"
        Rename-Item -LiteralPath $_.FullName -NewName $new
    }
}
