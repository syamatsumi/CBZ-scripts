このディレクトリにnihui氏の「waifu2x-ncnn-vulkan」と「realcugan-ncnn-vulkan」が必要です。
・ [realcugan-ncnn-vulkan (GitHub Releases)](https://github.com/nihui/realcugan-ncnn-vulkan/releases)  
・ [waifu2x-ncnn-vulkan (GitHub Releases)](https://github.com/nihui/waifu2x-ncnn-vulkan/releases)  

合体させる際、vcomp140.dllは新しい方で上書きしています。

```
  CBZupscaleVx_xxx.bat  
  #scr  
    └┬─ #exe ←今ここ  
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

あと、しれっと長いフォルダ名も書き換えちゃってます。

```
ren "models-upconv_7_anime_style_art_rgb" "models-art"
ren "models-upconv_7_photo" "models-photo"
```
