# CBZ-upscaler
ウルトラHD向けの高解像度閲覧用の圧縮データを作成します。


## 概要
コミックブックアーカイブを読んでて、  
「解像感足りねぇなー」とか「アップスケーリングしてえなぁ」  
って思うことありませんか？

ありますよね？　あるんですよ！！！

そんなわけで、コミックブック形式アーカイブを
アップスケーリングするスクリプトをご用意しました。

WebP形式を使う都合から閲覧環境を選んでしまいますが、
そもそも4Kクラスの画像を閲覧できる環境ともなると、
WebPの表示に苦労するほどのレガシー環境を気にしてもしょうがないですし、
大抵はページ捲りが軽く快適になります。

そもそもなんでデノイズまでかけておいて
最後の最後で破壊圧縮をするのかって、
そもそもAIアップスケーリング自体が破壊的加工であるため、
気にするにしたって今更なのです。

要するに、このスクリプトで製作するのは、
UHDディスプレイでボケない表示をするための一時データに過ぎません。  
拡大前の元データは大切に保管しておいてください。


## 使い方
アップスケールをかけたいCBZを作業用ディレクトリに移して、
処理対象を同じフォルダに並べて使います。

ほかファイルの配置は以下のようになります。  

```
  アップスケールを実施したい処理対象.cbz  
  CBZupscaleVx_xxx.bat  
  README.md ←本文これ  
  #scr  
    └┬─ #exe  
      │    └┬ realcugan-ncnn-vulkan.exe  
      │      ├ waifu2x-ncnn-vulkan.exe  
      │      ├ vcomp140.dll  
      │      ├ models-art  
      │      │   ├ noise0_scale2.0x_model.bin  
      │      │   ├ noise0_scale2.0x_model.param
      │      │   └ ...  
      │      ├ models-cunet  
      │      │   └ ...  
      │      ├ models-photo  
      │      │   └ ...  
      │      ├ models-pro  
      │      │   └ ...  
      │      └ models-se  
      │           └ ...  
      ├─ CBZupsc  
      │    └┬ CBZupsc.psd1  
      │      ├ CBZupsc.psm1  
      │      ├ Metrics.psm1  
      │      ├ Orchestr.ps1  
      │      └ Wipedir.ps1  
      ├ CBZupscaleVx_cfg.psd1  
      └ CBZupscaleVx_upscale.ps1
```


## 実行にあたって必要なプログラム・モジュール等

### アップスケーラー（\*-ncnn-vulkan）
realcugan-ncnn-vulkan.exeとwaifu2x-ncnn-vulkan.exeほか
モデルファイルなどはncnn氏のリリースから入手してください。

- [realcugan-ncnn-vulkan (GitHub Releases)](https://github.com/nihui/realcugan-ncnn-vulkan/releases)
- [waifu2x-ncnn-vulkan (GitHub Releases)](https://github.com/nihui/waifu2x-ncnn-vulkan/releases)



### Powershell v7以降
Powershellにて以下を実行するだけでもいけるはず。
`winget search Microsoft.PowerShell`

詳細は下記サイトを参照。

- [PowerShell 公式インストールガイド](https://learn.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)


### ImageMagick
CUIで画像を扱うなら必携のシロモノです。

- [ImageMagick 公式サイト](https://imagemagick.org/)

今時は環境変数を自分で弄くりまわさんでもインストーラがパスも通してくれるからスゲー便利ですなぁ……  

通常は ImageMagick-7.1.2-5-Q16-HDRI-x64-static.exe  
かしらね。

少しでも動作を軽くしたいなら  
ImageMagick-7.1.2-5-Q8-x64-dll.exe  
を選択すると良いでしょう。


## その他
こちらと内容は重複しますが、ブログの方でも色々書いてます。

- [がらくた置き場](https://syamatsumi.hatenadiary.jp/entry/2025/09/19/021607)

