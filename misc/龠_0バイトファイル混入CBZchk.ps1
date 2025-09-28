chcp 65001
Set-Location -Path $PSScriptRoot
$sevenZip = "$env:ProgramFiles\7-Zip\7z.exe"
$archives = Get-ChildItem -Filter *.cbz

foreach ($archive in $archives) {
    Write-Host "$($archive.Name)"
    $output = & $sevenZip l -slt $archive.FullName

    $isFolder = $false
    $currentPath = ""

    foreach ($line in $output) {
        if ($line -like "Path = *") {
            $currentPath = $line.Substring(7).Trim()
            $isFolder = $false
        }
        elseif ($line -like "Folder = *") {
            $isFolder = $line.Substring(9).Trim() -eq "+"
        }
        elseif ($line -like "Size = *") {
            $size = $line.Substring(7).Trim()
            if (-not $isFolder -and $size -eq "0") {
                Write-Host ""
                Write-Host "→ 0バイトファイルあり: $($archive.Name)"
                Write-Host ""
                pause
                break
            }
        }
    }
}

Write-Host "--- チェック終了 ---"
pause
