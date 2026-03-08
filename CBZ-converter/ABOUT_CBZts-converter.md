# CBZtools-converter
アーカイブ形式を展開してCBZに変換します。  

・ビューワでは開封が重たいことが多いRARや7ZをZIPになおす
・アーカイブ環境由来のゴミファイルが含まれるなどで正常にプレビューが表示されない
・パスワード付きのアーカイブを展開・再圧縮したい

こういった場合に利用できるツールになります。

CB7（7Z）、CBT（Tar）、CBR（RAR）はいずれもZIPと較べてランダムアクセス性能に劣り、
つまり開くときどうしても重たいので、CBZに変換した方が閲覧が快適だったりします。  
元ファイルはそのままの形式でいいとしても、
閲覧用としては変換しておくと後々快適になるので便利。

arc2cbz.batで.7z .arj .cab .lzh .rar .tar .uue .zipに対応するよう書いてはいますが、
7Z、LZH、RAR以外で実際に動くかどうかは知らない……

## 使い方
1. 変換したいフォルダに対応する一つの `.bat` ファイルと二つの `.ps1` ファイルをコピーします。
   `CBZts_arc2cbz7Z.bat` アーカイブ形式からCBZへ、7Zipを利用  
   `CBZts_arc2cbzWR.bat` アーカイブ形式からCBZへ、WinRARを利用  
   `CBZts_cbx2cbz7Z.bat` コミックブック形式からCBZへ、7Zipを利用  
   `CBZts_cbx2cbzWR.bat` コミックブック形式からCBZへ、WinRARを利用  

   例: RAR → CBZ にしたい場合は
       `CBZts-arc2cbz.bat` 
       `CBZts_repsym.ps1`
       `CBZts_wipedir.ps1`
       をコピー。  
2. ダブルクリックで実行すると、カレントディレクトリ内の対象ファイルが一括変換されます。
