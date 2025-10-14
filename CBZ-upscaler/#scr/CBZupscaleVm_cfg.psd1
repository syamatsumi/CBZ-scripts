@{
  aicfg = @{
    # アップスケーラの設定
    # マルチGPU時はカンマ区切りで複数指定が必要なパラメータがある。
    # $tilesize（ex."256,256"）と$threadset（ex."1:4,4:2"）
    exeDir    = '#exe'       # exeを格納したディレクトリの名前
    gpuselect = 'auto'       # 利用するGPUの選択（auto,"0","0,1"など）
    tilesize  = '256'        # 画像を分割するサイズ。大きいほどメモリ食う。
    threadset = '1:4:4'      # スレッド割当てと比率（load:proc:save）
    # その他の挙動について
    maxRetry   = 8       # アップスケールの再試行許容回数
    deltemp    = $true   # テンポラリと元画像の削除の実施
    x1denoSKIP = $true   # 等倍判定時にデノイズ処理を強制スキップする。
    x1dskipTsh = 1       # 上記有効時、デノイズ処理をスキップする下限。
    webpQtest  = $false  # Webp出力の品質検査・有効無効
  }
  # 拡大後テストに関する閾値。
  tinit = @{ 
    TotalPixelTsh  = 6.0   # 拡大を省略する総画素数(メガピクセル指定)
    LongSideThlen  = 3840  # 拡大を省略する長辺の閾値
    BothSideThlen  = 2048  # 拡大を省略する両辺の閾値
    ShortSideThlen = 1024  # 倍率x2が確定する短辺の閾値（これ未満は3倍）
    psnrTshOK      = 32    # PSNRの閾値（再検査ライン）
    psnrTshVE      = 28    # PSNRの閾値（要検証ライン）
    psnrTshNG      = 16    # PSNRの閾値（不合格ライン）
    ssimTshOK      = 0.70  # SSIMの閾値（再検査ライン）
    ssimTshVE      = 0.60  # SSIMの閾値（要検証ライン）
    ssimTshNG      = 0.50  # SSIMの閾値（不合格ライン）
    tilesizeL      = 256   # PSNR検査用のタイルサイズ
    tilesizeR      = 128   # 再検査時のタイルサイズ
    tilesizeS      = 32    # 要検証時のタイルサイズ
  }
  # WebP変換後の画質評価を有効にする場合は要設定。
  tinit2 = @{ 
    psnrTshOK      = 40    # PSNRの閾値（再検査ライン）
    psnrTshVE      = 30    # PSNRの閾値（要検証ライン）
    psnrTshNG      = 20    # PSNRの閾値（不合格ライン）
    ssimTshOK      = 0.97  # SSIMの閾値（再検査ライン）
    ssimTshVE      = 0.95  # SSIMの閾値（要検証ライン）
    ssimTshNG      = 0.80  # SSIMの閾値（不合格ライン）
    tilesizeL      = 1024  # PSNR検査用のタイルサイズ
    tilesizeR      = 512   # 再検査時のタイルサイズ
    tilesizeS      = 128   # 要検証時用のタイルサイズ
  }
  # Write-hostやログの関連。
  writehostVal = @{ 
    l1 = 40
    l2 = 60
    l3 = '6:F3'   # 画面PSNR結果の桁
    l4 = '10:F7'  # ログPSNR結果の桁
    l5 = '10:F8'  # ログSSIM結果の桁
    nnl = $true   # デバッグで改行させたい場合は $false に。
  }
}
