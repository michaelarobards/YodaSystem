# YODA API Endpoint Auto-Fix Script
# This will fix all instances of the wrong API endpoint

Write-Host "🔧 YODA API Endpoint Auto-Fixer" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

# Get current directory
$currentPath = Get-Location
Write-Host "`n📁 Working in: $currentPath" -ForegroundColor Cyan

# Find all HTML, JS, and JSON files
Write-Host "`n🔍 Searching for files to fix..." -ForegroundColor Yellow
$files = Get-ChildItem -Path . -Include *.html, *.js, *.json -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "node_modules|\.git|dist|build" }

$totalFiles = $files.Count
Write-Host "📄 Found $totalFiles files to check" -ForegroundColor White

$oldEndpoint = "yoda-api.michaelarobards.workers.dev"
$newEndpoint = "yoda-mobile.michaelarobards.workers.dev"
$fixedCount = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -match $oldEndpoint) {
        Write-Host "`n✏️  Fixing: $($file.Name)" -ForegroundColor Yellow
        
        # Count occurrences
        $matches = ([regex]::Matches($content, $oldEndpoint)).Count
        Write-Host "   Found $matches occurrence(s)" -ForegroundColor Gray
        
        # Replace all occurrences
        $newContent = $content -replace $oldEndpoint, $newEndpoint
        
        # Save the file
        Set-Content -Path $file.FullName -Value $newContent -NoNewline
        Write-Host "   ✅ Fixed!" -ForegroundColor Green
        
        $fixedCount++
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "   - Files checked: $totalFiles" -ForegroundColor White
Write-Host "   - Files fixed: $fixedCount" -ForegroundColor White

if ($fixedCount -gt 0) {
    Write-Host "`n🚀 Now let's commit and push the changes:" -ForegroundColor Green
    
    # Git status
    Write-Host "`nGit status:" -ForegroundColor Yellow
    git status --short
    
    # Add all changes
    Write-Host "`n📦 Adding changes to git..." -ForegroundColor Yellow
    git add .
    
    # Commit
    Write-Host "`n💾 Committing changes..." -ForegroundColor Yellow
    git commit -m "Fix API endpoint: yoda-api -> yoda-mobile"
    
    # Push
    Write-Host "`n🚀 Pushing to GitHub..." -ForegroundColor Yellow
    git push
    
    Write-Host "`n✅ DONE! Your changes are pushed to GitHub!" -ForegroundColor Green
    Write-Host "⏰ Cloudflare Pages will redeploy in 1-2 minutes" -ForegroundColor Cyan
    Write-Host "`n💡 After deployment completes:" -ForegroundColor Yellow
    Write-Host "   1. Hard refresh your browser (Ctrl+Shift+R)" -ForegroundColor White
    Write-Host "   2. Your YODA AI should connect properly!" -ForegroundColor White
} else {
    Write-Host "`n✅ No files needed fixing!" -ForegroundColor Green
    Write-Host "🤔 The API endpoint might already be correct in your files." -ForegroundColor Yellow
}

Write-Host "`n🧪 Test your Worker directly:" -ForegroundColor Cyan
Write-Host "   https://yoda-mobile.michaelarobards.workers.dev/api/status" -ForegroundColor White
Start-Process "https://yoda-mobile.michaelarobards.workers.dev/api/status"