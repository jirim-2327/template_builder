param($Path)

function Show-Tree {
    param($Path, $Prefix = "")
    
    $items = Get-ChildItem -Path $Path | Sort-Object { $_.PSIsContainer }, Name -Descending
    $count = $items.Count
    $index = 0
    
    foreach ($item in $items) {
        $index++ 
        $isLast = ($index -eq $count)
        $branch = if ($isLast) { "└─ " } else { "├─ " }
        $nextPrefix = if ($isLast) { "   " } else { "│  " }
        
        if ($item.PSIsContainer) {
            Write-Host "$Prefix$branch📁 $($item.Name)" -ForegroundColor Blue
            Show-Tree -Path $item.FullName -Prefix ($Prefix + $nextPrefix)
        } else {
            Write-Host "$Prefix$branch📄 $($item.Name)" -ForegroundColor Gray
        }
    }
}

Show-Tree -Path $Path
