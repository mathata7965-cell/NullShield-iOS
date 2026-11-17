<#
.SYNOPSIS
    Zero-Git Windows Cloud IPA Builder for NullShield_iOS (Null).
.DESCRIPTION
    Uploads the project to GitHub via pure REST API (no git.exe required),
    triggers macOS Xcode compilation on GitHub Actions, and downloads
    Null.ipa & Null-NoExtension.ipa directly to this project folder.
#>

param(
    [string]$Token = $env:GITHUB_TOKEN,
    [string]$RepoName = "NullShield-iOS",
    [switch]$PrivateRepo,
    [ValidateSet("Auto", "Major", "Minor", "Patch", "None")]
    [string]$VersionBump = "Auto"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RootDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($RootDir)) {
    $RootDir = Get-Location
}
$ParentDir = Split-Path $RootDir -Parent
$TokenCachePath = Join-Path $RootDir ".github_token.local"
$FallbackPaths = @(
    $TokenCachePath,
    (Join-Path $ParentDir "ChessBotAssistant_iOS\.github_token.local"),
    (Join-Path $ParentDir "GlassMusicPlayer_iOS\.github_token.local"),
    (Join-Path $ParentDir "AppleMapsNavigator_iOS\.github_token.local")
)

function Download-GitHubArtifactZip {
    param(
        [string]$DownloadUrl,
        [string]$OutZipPath,
        [string]$AuthToken
    )
    $RedirectUrl = $null
    $Req = [System.Net.HttpWebRequest]::Create($DownloadUrl)
    $Req.Method = "GET"
    $Req.UserAgent = "NullShield-CloudBuilder"
    $Req.Headers.Add("Authorization", "Bearer $AuthToken")
    $Req.AllowAutoRedirect = $false
    try {
        $Resp = $Req.GetResponse()
        $RedirectUrl = $Resp.Headers["Location"]
        $Resp.Close()
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $RedirectUrl = $_.Exception.Response.Headers["Location"]
            $_.Exception.Response.Close()
        }
    }

    if ([string]::IsNullOrWhiteSpace($RedirectUrl)) {
        $DlHeaders = @{
            "Authorization" = "Bearer $AuthToken"
            "User-Agent"    = "NullShield-CloudBuilder"
        }
        Invoke-WebRequest -Uri $DownloadUrl -Headers $DlHeaders -OutFile $OutZipPath -UseBasicParsing
    } else {
        Invoke-WebRequest -Uri $RedirectUrl -OutFile $OutZipPath -UseBasicParsing
    }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Null 零噪盾 · 雲端免費編譯 IPA 工具 (Windows)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

foreach ($PathCandidate in $FallbackPaths) {
    if ([string]::IsNullOrWhiteSpace($Token) -and (Test-Path $PathCandidate)) {
        try {
            $Encrypted = Get-Content -Path $PathCandidate -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($Encrypted)) {
                $SecureCached = ConvertTo-SecureString $Encrypted.Trim()
                $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureCached)
                $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Bstr)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
                Write-Host "已從本機加密快取載入 GitHub Token" -ForegroundColor DarkGray
                break
            }
        } catch {
            if ($PathCandidate -eq $TokenCachePath) {
                Remove-Item -Path $TokenCachePath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    Write-Host "請輸入您的 GitHub Personal Access Token (需勾選 repo 與 workflow 權限)：" -ForegroundColor Yellow
    $secure = Read-Host -Prompt "GitHub Token" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $Token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "未提供 GitHub Token，已中止。"
}

$Headers = @{
    "Authorization"        = "Bearer $Token"
    "Accept"               = "application/vnd.github+json"
    "User-Agent"           = "NullShield-CloudBuilder"
    "X-GitHub-Api-Version" = "2022-11-28"
}

Write-Host "[1/5] 驗證 GitHub 帳號..." -ForegroundColor Green
try {
    $User = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $Headers -Method Get
} catch {
    if (Test-Path $TokenCachePath) {
        Remove-Item -Path $TokenCachePath -Force -ErrorAction SilentlyContinue
    }
    throw "GitHub Token 驗證失敗，請確認 Token 有效且包含 repo 與 workflow 權限。"
}
$Owner = $User.login
Write-Host "      已登入帳號：$Owner"

try {
    $SecureToSave = ConvertTo-SecureString -String $Token -AsPlainText -Force
    $EncryptedSave = ConvertFrom-SecureString -SecureString $SecureToSave
    [System.IO.File]::WriteAllText($TokenCachePath, $EncryptedSave, (New-Object System.Text.UTF8Encoding($false)))
} catch { }

Write-Host "[2/5] 檢查或建立 GitHub 倉庫 ($Owner/$RepoName)..." -ForegroundColor Green
$RepoUri = "https://api.github.com/repos/$Owner/$RepoName"
try {
    $RepoInfo = Invoke-RestMethod -Uri $RepoUri -Headers $Headers -Method Get
    $Branch = $RepoInfo.default_branch
    Write-Host "      找到現有倉庫（預設分支：$Branch）"
} catch {
    $CreateBody = @{
        name        = $RepoName
        description = "Null - iOS Privacy, Safari Content Blocker, System Encrypted DNS & X-Ray Lab (Cloud IPA Build)"
        private     = [bool]$PrivateRepo
        auto_init   = $true
    } | ConvertTo-Json
    $RepoInfo = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $Headers -Method Post -Body $CreateBody -ContentType "application/json"
    $Branch = $RepoInfo.default_branch
    if ([string]::IsNullOrWhiteSpace($Branch)) { $Branch = "main" }
    Write-Host "      已自動建立新倉庫：https://github.com/$Owner/$RepoName"
    Start-Sleep -Seconds 2
}

try {
    $RefInfo = Invoke-RestMethod -Uri "$RepoUri/git/ref/heads/$Branch" -Headers $Headers -Method Get
} catch {
    Write-Host "      初始化空白倉庫分支 $Branch..."
    $InitBytes = [System.Text.Encoding]::UTF8.GetBytes("# $RepoName`n")
    $InitBody = @{
        message = "Initialize repository"
        content = [Convert]::ToBase64String($InitBytes)
        branch  = $Branch
    } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "$RepoUri/contents/README.md" -Headers $Headers -Method Put -Body $InitBody -ContentType "application/json"
    Start-Sleep -Seconds 2
    $RefInfo = Invoke-RestMethod -Uri "$RepoUri/git/ref/heads/$Branch" -Headers $Headers -Method Get
}

$ParentCommitSha = $RefInfo.object.sha

$VersionStatePath = Join-Path $RootDir ".version_state.json"
$MainPlistPath = Join-Path $RootDir "Null\Info.plist"
$ExtPlistPath = Join-Path $RootDir "NullSafariBlocker\Info.plist"
$ProjectYmlPath = Join-Path $RootDir "project.yml"

function Get-TrackedSourceMetrics {
    param([string]$BaseDir)
    $map = @{}
    $tracked = Get-ChildItem -Path $BaseDir -File -Recurse | Where-Object {
        $rel = $_.FullName.Substring($BaseDir.Length + 1).Replace("\", "/")
        ($rel -notmatch '^(\.git/|build/)') -and ($_.Extension -in @(".swift", ".py", ".yml", ".mjs", ".json")) -and ($_.Name -ne "Build-IPA-Cloud.ps1")
    }
    foreach ($item in $tracked) {
        $rel = $item.FullName.Substring($BaseDir.Length + 1).Replace("\", "/")
        $hash = (Get-FileHash -Path $item.FullName -Algorithm SHA256).Hash
        $lineCount = (Get-Content -Path $item.FullName -Encoding UTF8).Count
        $map[$rel] = @{ hash = $hash; lines = $lineCount }
    }
    return $map
}

function Set-BundleVersionValues {
    param([string]$ShortVersion, [int]$BuildNumber)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    foreach ($plistPath in @($MainPlistPath, $ExtPlistPath)) {
        if (Test-Path $plistPath) {
            $raw = [System.IO.File]::ReadAllText($plistPath, [System.Text.Encoding]::UTF8)
            $raw = [regex]::Replace($raw, "(<key>CFBundleShortVersionString</key>\s*<string>)[^<]+(</string>)", "`${1}$ShortVersion`${2}")
            $raw = [regex]::Replace($raw, "(<key>CFBundleVersion</key>\s*<string>)[^<]+(</string>)", "`${1}$BuildNumber`${2}")
            [System.IO.File]::WriteAllText($plistPath, $raw, $utf8NoBom)
        }
    }
    if (Test-Path $ProjectYmlPath) {
        $yml = [System.IO.File]::ReadAllText($ProjectYmlPath, [System.Text.Encoding]::UTF8)
        $yml = [regex]::Replace($yml, '(MARKETING_VERSION:\s*")[^"]+(")', "`${1}$ShortVersion`${2}")
        $yml = [regex]::Replace($yml, '(CURRENT_PROJECT_VERSION:\s*")[^"]+(")', "`${1}$BuildNumber`${2}")
        [System.IO.File]::WriteAllText($ProjectYmlPath, $yml, $utf8NoBom)
    }
}

$CurrentMainPlist = [System.IO.File]::ReadAllText($MainPlistPath, [System.Text.Encoding]::UTF8)
$CurShortVer = if ($CurrentMainPlist -match '<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>') { $Matches[1] } else { "1.0.0" }
$CurBuildNum = if ($CurrentMainPlist -match '<key>CFBundleVersion</key>\s*<string>(\d+)</string>') { [int]$Matches[1] } else { 1 }
$CurMetrics = Get-TrackedSourceMetrics -BaseDir $RootDir

if ($VersionBump -ne "None") {
    if (Test-Path $VersionStatePath) {
        try {
            $PrevState = Get-Content -Path $VersionStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $ChangedFiles = 0
            $NewFiles = 0
            $ApproxChangedLines = 0
            foreach ($k in $CurMetrics.Keys) {
                $curEntry = $CurMetrics[$k]
                $prevProp = $PrevState.files.PSObject.Properties[$k]
                if (-not $prevProp) {
                    $NewFiles++
                    $ChangedFiles++
                    $ApproxChangedLines += [int]$curEntry.lines
                } elseif ($prevProp.Value.hash -ne $curEntry.hash) {
                    $ChangedFiles++
                    $ApproxChangedLines += [Math]::Max(8, [Math]::Abs([int]$curEntry.lines - [int]$prevProp.Value.lines) + 12)
                }
            }
            if ($ChangedFiles -gt 0 -and $PrevState.shortVersion -eq $CurShortVer) {
                $Tier = $VersionBump
                if ($Tier -eq "Auto") {
                    if ($NewFiles -ge 3 -or ($ChangedFiles -ge 10 -and $ApproxChangedLines -ge 800)) {
                        $Tier = "Major"
                    } elseif ($ChangedFiles -ge 2 -or $NewFiles -ge 1 -or $ApproxChangedLines -ge 80) {
                        $Tier = "Minor"
                    } else {
                        $Tier = "Patch"
                    }
                }
                $Parts = $CurShortVer.Split(".")
                $Maj = [int]$Parts[0]; $Min = if ($Parts.Count -gt 1) { [int]$Parts[1] } else { 0 }; $Pat = if ($Parts.Count -gt 2) { [int]$Parts[2] } else { 0 }
                switch ($Tier) {
                    "Major" { $Maj++; $Min = 0; $Pat = 0; $TierZh = "大更新 (Major)" }
                    "Minor" { $Min++; $Pat = 0; $TierZh = "中更新 (Minor)" }
                    "Patch" { $Pat++; $TierZh = "小更新 (Patch)" }
                }
                $NewShortVer = "$Maj.$Min.$Pat"
                $NewBuild = $CurBuildNum + 1
                Set-BundleVersionValues -ShortVersion $NewShortVer -BuildNumber $NewBuild
                Write-Host "      版本自動判定：$TierZh | $CurShortVer (Build $CurBuildNum) -> $NewShortVer (Build $NewBuild)" -ForegroundColor Cyan
                $CurShortVer = $NewShortVer
                $CurBuildNum = $NewBuild
            }
        } catch { }
    }
    $SaveStateObj = @{
        shortVersion = $CurShortVer
        buildNumber  = $CurBuildNum
        files        = $CurMetrics
    }
    [System.IO.File]::WriteAllText($VersionStatePath, ($SaveStateObj | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
}
Write-Host "      當前封裝版本：v$CurShortVer (Build $CurBuildNum)" -ForegroundColor DarkGray

Write-Host "[3/5] 上傳專案檔案至 GitHub (免安裝 Git)..." -ForegroundColor Green
$AllFiles = Get-ChildItem -Path $RootDir -File -Recurse -Force | Where-Object {
    $rel = $_.FullName.Substring($RootDir.Length + 1).Replace("\", "/")
    ($rel -notmatch '^(\.git/|build/|Build-IPA-Cloud\.ps1\.log$|\.github_token\.local$|\.version_state\.json$|xcodebuild\.log$)') -and
    ($_.Extension -ne ".ipa") -and
    ($_.Name -ne ".DS_Store")
}

$TreeEntries = @()
foreach ($File in $AllFiles) {
    $RelPath = $File.FullName.Substring($RootDir.Length + 1).Replace("\", "/")
    $Bytes = [System.IO.File]::ReadAllBytes($File.FullName)
    $BlobBody = @{
        content  = [Convert]::ToBase64String($Bytes)
        encoding = "base64"
    } | ConvertTo-Json
    $BlobRes = Invoke-RestMethod -Uri "$RepoUri/git/blobs" -Headers $Headers -Method Post -Body $BlobBody -ContentType "application/json"

    $Mode = if ($RelPath.EndsWith(".sh")) { "100755" } else { "100644" }
    $TreeEntries += @{
        path = $RelPath
        mode = $Mode
        type = "blob"
        sha  = $BlobRes.sha
    }
}

$TreeBody = @{
    tree = $TreeEntries
} | ConvertTo-Json -Depth 5
$TreeRes = Invoke-RestMethod -Uri "$RepoUri/git/trees" -Headers $Headers -Method Post -Body $TreeBody -ContentType "application/json"

$CommitBody = @{
    message = "Upload NullShield iOS project for Cloud IPA build"
    tree    = $TreeRes.sha
    parents = @($ParentCommitSha)
} | ConvertTo-Json
$CommitRes = Invoke-RestMethod -Uri "$RepoUri/git/commits" -Headers $Headers -Method Post -Body $CommitBody -ContentType "application/json"
$NewCommitSha = $CommitRes.sha

$UpdateRefBody = @{
    sha   = $NewCommitSha
    force = $true
} | ConvertTo-Json
$null = Invoke-RestMethod -Uri "$RepoUri/git/refs/heads/$Branch" -Headers $Headers -Method Patch -Body $UpdateRefBody -ContentType "application/json"
Write-Host "      已上傳 $($TreeEntries.Count) 個檔案（Commit: $($NewCommitSha.Substring(0,7))）"

Write-Host "[4/5] 等待 GitHub Actions macOS 編譯 Null.ipa..." -ForegroundColor Green
$TargetRun = $null
for ($i = 0; $i -lt 18; $i++) {
    Start-Sleep -Seconds 5
    $RunsRes = Invoke-RestMethod -Uri "$RepoUri/actions/runs?per_page=10" -Headers $Headers -Method Get
    $TargetRun = $RunsRes.workflow_runs | Where-Object { $_.head_sha -eq $NewCommitSha } | Select-Object -First 1
    if ($TargetRun) { break }
}

if (-not $TargetRun) {
    throw "找不到對應的 GitHub Actions 建置任務，請前往 https://github.com/$Owner/$RepoName/actions 查看。"
}

Write-Host "      建置任務網址：$($TargetRun.html_url)" -ForegroundColor DarkGray
while ($TargetRun.status -ne "completed") {
    Write-Host "      目前狀態：$($TargetRun.status)... (每 10 秒檢查一次)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 10
    $TargetRun = Invoke-RestMethod -Uri "$RepoUri/actions/runs/$($TargetRun.id)" -Headers $Headers -Method Get
}

$ArtifactsRes = Invoke-RestMethod -Uri "$RepoUri/actions/runs/$($TargetRun.id)/artifacts" -Headers $Headers -Method Get

if ($TargetRun.conclusion -ne "success") {
    try {
        $JobsRes = Invoke-RestMethod -Uri "$RepoUri/actions/runs/$($TargetRun.id)/jobs" -Headers $Headers -Method Get
        foreach ($Job in $JobsRes.jobs) {
            if ($Job.conclusion -ne "success") {
                Write-Host "      Job [$($Job.name)] 失敗狀態：$($Job.conclusion)" -ForegroundColor Red
                $FailedSteps = $Job.steps | Where-Object { $_.conclusion -eq "failure" }
                foreach ($Step in $FailedSteps) {
                    Write-Host "      失敗步驟：$($Step.name)" -ForegroundColor Yellow
                }
            }
        }

        $LogArtifact = $ArtifactsRes.artifacts | Where-Object { $_.name -eq "xcodebuild-log" } | Select-Object -First 1
        if ($LogArtifact) {
            $LogZip = Join-Path $env:TEMP "xcodebuild-log-$($TargetRun.id).zip"
            $LogDir = Join-Path $env:TEMP "xcodebuild-log-$($TargetRun.id)"
            if (Test-Path $LogDir) { Remove-Item -Path $LogDir -Recurse -Force }
            Download-GitHubArtifactZip -DownloadUrl $LogArtifact.archive_download_url -OutZipPath $LogZip -AuthToken $Token
            Expand-Archive -Path $LogZip -DestinationPath $LogDir -Force
            $LogFile = Join-Path $LogDir "xcodebuild.log"
            if (Test-Path $LogFile) {
                $SavedLog = Join-Path $RootDir "xcodebuild.log"
                Copy-Item -Path $LogFile -Destination $SavedLog -Force
                Write-Host "      已下載完整編譯日誌至：$SavedLog" -ForegroundColor Cyan
                $ErrLines = Get-Content -Path $SavedLog -Encoding UTF8 | Select-String -Pattern "error:|fatal error:|BUILD FAILED" | Select-Object -Last 20
                foreach ($Line in $ErrLines) {
                    Write-Host "      $($Line.Line)" -ForegroundColor Red
                }
            }
        }
    } catch { }
    throw "雲端編譯失敗 ($($TargetRun.conclusion))。請開啟上方建置網址查看 Xcode 錯誤日誌：$($TargetRun.html_url)"
}

Write-Host "[5/5] 下載並解壓縮 Null.ipa..." -ForegroundColor Green
$IpaArtifact = $ArtifactsRes.artifacts | Where-Object { $_.name -eq "Null-ipa" } | Select-Object -First 1

if (-not $IpaArtifact) {
    throw "編譯完成但找不到產物 Null-ipa。"
}

$TempZip = Join-Path $env:TEMP "Null-ipa-$($TargetRun.id).zip"
$TempExtract = Join-Path $env:TEMP "Null-ipa-$($TargetRun.id)"
if (Test-Path $TempExtract) { Remove-Item -Path $TempExtract -Recurse -Force }

Download-GitHubArtifactZip -DownloadUrl $IpaArtifact.archive_download_url -OutZipPath $TempZip -AuthToken $Token
Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force

$ExtractedIpa = Join-Path $TempExtract "Null.ipa"
$FinalIpa = Join-Path $RootDir "Null.ipa"
Move-Item -Path $ExtractedIpa -Destination $FinalIpa -Force

$ExtractedNoExtIpa = Join-Path $TempExtract "Null-NoExtension.ipa"
$FinalNoExtIpa = Join-Path $RootDir "Null-NoExtension.ipa"
if (Test-Path $ExtractedNoExtIpa) {
    Move-Item -Path $ExtractedNoExtIpa -Destination $FinalNoExtIpa -Force
}

Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item -Path $TempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  成功取得側載檔案（完整版含 Safari 內容阻擋器）：$FinalIpa" -ForegroundColor Green
if (Test-Path $FinalNoExtIpa) {
    Write-Host "  成功取得側載檔案（單一 App ID 免外掛版）：$FinalNoExtIpa" -ForegroundColor Green
}
Write-Host "==================================================" -ForegroundColor Green
Write-Host "現在請打開 Sideloadly / AltStore / SideStore，拖入 Null.ipa 即可安裝到 iPhone！" -ForegroundColor Cyan
