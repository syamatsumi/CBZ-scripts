param([string]$Root = ".")

Get-ChildItem -LiteralPath $Root -Directory | ForEach-Object {
    $old = $_.Name
    $new = $old
    $new = $new -replace '\^', 'ÅO'
    $new = $new -replace '&', 'Åï'
    $new = $new -replace '!', 'ÅI'
    $new = $new -replace '%', 'Åì'
    $new = $new -replace ';', 'ÅG'
    $new = $new -replace '=', 'ÅÅ'
    $new = $new -replace ',', 'ÅC'

    if ($old -ne $new) {
        Write-Host "RENAMING: $old Å® $new"
        Rename-Item -LiteralPath $old -NewName $new
    }
}
