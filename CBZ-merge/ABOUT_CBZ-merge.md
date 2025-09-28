# CBZ-merge
分割ダウンロードにありがちな連番アーカイブを結合します。

**こちら利用にあたって7Zが必須になります。**

名前が被ったファイルはハッシュ値で比較してオリジナルと同じなら廃棄します。  
いうて、ここらの作り込みは雑なので、image.jpgとimage_1.jpgが同じなら捨てますが、
image.jpgとimage_1.jpgが違っている場合、
image_1.jpgとimage_2.jpgが同じバイナリでも生き残ってしまいますwwwwww

なので過信は禁物です。

## 使い方
1. 変換したいフォルダに

     CBZmerge_ver.bat  
     CBZmerge_dedup.ps1  
     CBZmerge_repsym.ps1  
     
     ファイルをコピーします。

2. CBZmerge_ver.batのset "SPLIT_KEY=" に適切な値を入れてください。
   ダブルクリックで実行すると、カレントディレクトリ内の対象ファイルが一括変換されます。

## 変換イメージ
結合のイメージとしましては、

     hogehoge-01-01.cbz
     hogehoge-01-02.cbz
     hogehoge-01-03.cbz
     hogehoge-02-01.cbz
     hogehoge-02-01.cbz

といったファイルに対して "SPLIT_KEY=-0" を設定して使うと

     hogehoge1.cbz
     hogehoge2.cbz

という結果が得られるイメージです……  
汎用性は微妙かも？
