#Requires -Version 5.1

# =================配置区域=================
# 图片文件列表（已从文档中提取）
$fileList = @(
    "89f2c12463811904fc02ed291e5f3d2c_MD5.jpeg",
    "466d02144d2393b5ffe1224cc9bb6539_MD5.jpeg",
    "68638c37c87f0212d34015275ae70753_MD5.jpeg",
    "2fdbefbf1825a807d735d1ace2d33351_MD5.jpeg",
    "b94e042d2e857e715cf720da4045b31d_MD5.jpeg",
    "506ea1289b75ba24c9fa211d0a1dbd47_MD5.jpeg",
    "b724e8a6157c954ab0eaf26221bd1826_MD5.jpeg",
    "d6b3f2ce7f3c675422fd4251055a8570_MD5.jpeg",
    "d0a06fa7df02acc2a2fce1d03f90554b_MD5.jpeg",
    "cbb999c17bddc4a24a91ec7cf313c49e_MD5.jpeg",
    "dbec8f8d74f33dcb2b85e68aecf9ce74_MD5.jpeg",
    "437e69f072f692826eca964f9a3784e5_MD5.jpeg",
    "c891746e0d4ca2a88689c97aa36d26b2_MD5.jpeg",
    "c0c88eba3c43d84e7dff3fe55c69db15_MD5.jpeg",
    "3e47fe20f5a206368d0191f587937cbd_MD5.jpeg",
    "25dec16af6bca138fdc15da6ce82f4fe_MD5.jpeg",
    "8a06f136fbc38cc0fe5f895c88e1c74d_MD5.jpeg",
    "21fc89b0a81009bf8ebddcc32c1c0dff_MD5.jpeg",
    "2f67375f110ee16e774c1707b43e5cc0_MD5.jpeg",
    "fe2e7f8fa63d1e14cee234bc9894bfe2_MD5.jpeg",
    "674a11e6e952ba8ebbc858f9c279593b_MD5.jpeg",
    "6219b1e0b585f17d75561c5881e49b76_MD5.jpeg",
    "ff170bc844ce821f37fdc049bbcd1ba2_MD5.jpeg",
    "a2947ce93446b1fa92fcedf5e250286a_MD5.jpeg",
    "499944e43cfd784afd1518edfa87949d_MD5.jpeg",
    "11d98cff10774c710acae8f2b431a6a8_MD5.jpeg",
    "5cb028a89c7d332b019022647799f5a8_MD5.jpeg",
    "bc12b61d38c89a0cb202100d892cdf3d_MD5.jpeg",
    "9da0804cc183801fcb4b97780a9899e4_MD5.jpeg",
    "140b070096bf39cbf0e731ffbda42ec2_MD5.jpeg",
    "9e21e42580f9bfc7b5f6973cdebde748_MD5.jpeg",
    "386fb65d1b0da20a39fed6e47a55d340_MD5.jpeg",
    "72e3427bb8ff99107b2d89a60372133d_MD5.jpeg",
    "1487393d321df91c16c7a499ac588c6e_MD5.jpeg",
    "ac92abc2c1e1caa2a7463b75c89c490e_MD5.jpeg",
    "13a820d0050bb9e6014927c9a6fede0a_MD5.jpeg",
    "5adc5742c0bd3aaa9991e47e5c59aa6c_MD5.jpeg",
    "2f5d314b2585e9f98edb38196ed21644_MD5.jpeg",
    "f40e43b0979ba36c0269efd344d88a48_MD5.jpeg",
    "8b6321cebe4f5395c7f34acbac72d733_MD5.jpeg",
    "f520810f9a43fc15d129cc9241adb7c2_MD5.jpeg",
    "8b3af83d5bc21ca05c184cf7ed054e63_MD5.jpeg",
    "e3c892bf848e089093ef6465cdd3ad58_MD5.jpeg",
    "0c1768cd48d58fc82533651d4b9e125f_MD5.jpeg",
    "59b6d8ba2722274c298973a9d5e3e52b_MD5.jpeg",
    "bf8b3565e33ecddef97d08870e5b8052_MD5.jpeg",
    "5d557126eea7353908767928be423642_MD5.jpeg",
    "cafecd577cbd5149211a5963776c453b_MD5.jpeg",
    "4ba8ace21fe049078856f40f00dde27d_MD5.jpeg",
    "ab95fe9183be7b2f9e291f586b9b1a3c_MD5.jpeg",
    "876a14704cd413e21cc9ac247e10243e_MD5.jpeg",
    "52195ddae0ccfeb42717308b8c099fb8_MD5.jpeg",
    "93ade572c35dcd1b1e24b9f8aec09791_MD5.jpeg",
    "cc34f5f497c4562c496d636dca77e86c_MD5.jpeg",
    "872e448a5a7cd9d80286e36e0356c788_MD5.jpeg",
    "54c6ca10ce50e9907b0b3b32855853f9_MD5.jpeg",
    "04132693dac35313f6141b120ed04075_MD5.jpeg",
    "a68c78fde266a81ad0862191d13a388f_MD5.jpeg",
    "b247a4d82a0d5355a74d340c44e5666a_MD5.jpeg",
    "49f0c919b7bde8a584d28ef8686c9026_MD5.jpeg",
    "3c117f3742ca21e62ed83b64ab39bc3b_MD5.jpeg",
    "149fc89b5c8db6e061c3572d72a38c21_MD5.jpeg",
    "4b3b0886e7735709fff2f34d6b84887a_MD5.jpeg",
    "2a680dcb75215354ef0a3191b4c82fb5_MD5.jpeg",
    "d3806b4fc6fb31d94fb695d8b477b101_MD5.jpeg",
    "70e30f75b7dda6db57f816a2918a315c_MD5.jpeg",
    "b57c86bdf741a7f5e0b2530d6af0f037_MD5.jpeg",
    "a682df999a47dddf08c2cf29b071697a_MD5.jpeg",
    "6977881434b806da5993430f6c49582f_MD5.jpeg",
    "07e161dd5e1d0e591cc0b3c4a038529a_MD5.jpeg",
    "1bb134261b7e65bdbcb2ac14fe56f56a_MD5.jpeg",
    "e78ad21e8bc29873b46b7009ea42100f_MD5.jpeg",
    "c51513125076940c6bc3e1b8afefeb70_MD5.jpeg",
    "cd1641ee032be3c79477ceb99a3383ca_MD5.jpeg",
    "7d401a3bdf42862e33d71ed88011de71_MD5.jpeg"
) | Select-Object -Unique

$outputDir = "attachments"
# ==========================================

$ErrorActionPreference = "Continue" # 允许单个文件失败后继续执行
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:LESSCHARSET = 'utf-8'

# 创建输出目录
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    Write-Host "Created directory: $outputDir" -ForegroundColor Cyan
}

# 核心恢复函数 (基于 Log Parser 模式)
function Restore-GitFile {
    param ( [string]$FileName )

    $targetPath = Join-Path $outputDir $FileName
    if (Test-Path -LiteralPath $targetPath) {
        Write-Host "[-] Skipping $FileName (Already exists)" -ForegroundColor DarkGray
        return
    }

    Write-Host "[*] Processing: $FileName" -NoNewline

    # Git 参数
    $gitArgs = @("-c", "core.quotePath=false", "-c", "i18n.logOutputEncoding=utf-8")

    # 1. 扫描 Git Raw Log 寻找 Blob ID
    # 使用 --raw 直接获取 Blob hash，避开中文路径乱码问题
    $logOutput = git $gitArgs log --all --full-history --date-order --diff-filter=ACMRT --raw --abbrev=40 --format="COMMIT:%H" -- "*$FileName"

    $targetBlobId = $null
    
    if ($logOutput) {
        foreach ($line in $logOutput) {
            # 解析 RAW 行: :100644 100644 <OldBlob> <NewBlob> <Status> <Path>
            # 我们正则匹配 NewBlob (第4列)
            if ($line -match "^:\d+\s+\d+\s+[0-9a-f]+\s+([0-9a-f]{40})\s+\S+\s+(.*)$") {
                $extractedBlob = $matches[1]
                $extractedPath = $matches[2]
                
                # 再次确认文件名匹配 (防止匹配到类似 my_image.jpeg 的情况)
                $escapedName = [regex]::Escape($FileName)
                if ($extractedPath -match "(^|[/\\])$escapedName$") {
                    $targetBlobId = $extractedBlob
                    break 
                }
            }
        }
    }

    # 2. 恢复文件
    if ($targetBlobId) {
        try {
            # 使用 cmd /c 保证二进制流安全
            $cmdLine = "git cat-file -p $targetBlobId > ""$targetPath"""
            cmd /c $cmdLine
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $targetPath)) {
                Write-Host " -> [OK] Restored" -ForegroundColor Green
            } else {
                Write-Host " -> [FAIL] Write failed" -ForegroundColor Red
            }
        }
        catch {
            Write-Host " -> [ERROR] $_" -ForegroundColor Red
        }
    } else {
        Write-Host " -> [NOT FOUND] In git history" -ForegroundColor Yellow
    }
}

# 主循环
Write-Host "Starting batch recovery for $($fileList.Count) files..." -ForegroundColor Cyan
Write-Host "---------------------------------------------------"

$successCount = 0
$failCount = 0

foreach ($file in $fileList) {
    Restore-GitFile -FileName $file
}

Write-Host "---------------------------------------------------"
Write-Host "Batch operation completed." -ForegroundColor Cyan