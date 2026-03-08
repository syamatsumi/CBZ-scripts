# CBZtools-packer

**こちら利用にあたって7Zが必須になります。**

動画やアーカイブの含まれない画像のみのフォルダをCBZにパッキングします。

CBZts_act-packer.bat

## 使い方
1. 変換したいフォルダの外に

     CBZts_act-packer.bat  
     CBZts_repsym.ps1  
     CBZts_wipedir.ps1
     
     ファイルをコピーします。  
     (CBZts_repsym.ps1、CBZts_wipedir.ps1は上書きしても大丈夫)

2. ダブルクリックで実行すると、  
   カレントディレクトリ内の対象フォルダがCBZへと一括変換されます。

## 圧縮元のフォルダを残したい場合
CBZts_act-packer.batの  
`rmdir /s /q "%%~nxD"`  
という記述を削除するか、REMでコメントアウトする。
