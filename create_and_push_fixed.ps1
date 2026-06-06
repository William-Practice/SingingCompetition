param()

function Check-Tool($name, $cmd) {
    try { & $cmd > $null 2>&1; return $true } catch { return $false }
}

if (-not (Check-Tool "git" "git --version")) { Write-Error "git 未安装或不可用."; exit 1 }
if (-not (Check-Tool "gh" "gh --version")) { Write-Error "gh CLI 未安装或不可用."; exit 1 }

Write-Host "确保已撤销旧 PAT，并已用 'gh auth login' 登录或设置 GITHUB_TOKEN 环境变量." -ForegroundColor Yellow
$ok = Read-Host "确认已处理（输入 Y 继续）"
if ($ok -ne 'Y' -and $ok -ne 'y') { Write-Host "已取消."; exit 0 }

$defaultRepo = "SingingCompetition"
$repoName = Read-Host "要在 GitHub 上创建的仓库名（回车使用 $defaultRepo）"
if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = $defaultRepo }

Write-Host "移除常见编译产物..."
$patterns = @("*.exe","*.pdb","*.ilk","*.log","*.obj")
foreach ($p in $patterns) {
    Get-ChildItem -Path . -Recurse -Force -ErrorAction SilentlyContinue -Include $p | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
# 移除 .vs 目录
Get-ChildItem -Path . -Recurse -Directory -Force -Filter ".vs" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 写入 .gitignore
if (-not (Test-Path .gitignore)) {
    @"
# Visual Studio
.vs/
*.suo
*.user
*.userosscache
*.sln.docstates

# Build
bin/
obj/
x64/
x86/
*.exe
*.dll
*.pdb
"@ | Out-File -Encoding utf8 .gitignore
}

$src = "SingingCompetition\SingingCompetition.cpp"
if (-not (Test-Path $src)) { Write-Error "$src 未找到。请在项目根目录运行此脚本."; exit 1 }

$content = Get-Content -Raw -Encoding UTF8 $src

# 1) 注释掉 system("color ...") 行
$content = [regex]::Replace($content, '^\s*system\("color [0-9A-Fa-f]{2}"\);\s*$', '//$&  // removed for safety', [System.Text.RegularExpressions.RegexOptions]::Multiline)

# 2) 将 accumulate 初始值修正为 0.0
$content = $content.Replace('float sum = std::accumulate(student.scores.begin() + 1, student.scores.end() - 1, 0);', 'double sum = std::accumulate(student.scores.begin() + 1, student.scores.end() - 1, 0.0);')

# 3) 在打开 scores.txt 后检查是否成功
$old = 'std::ofstream outFile("scores.txt");'
if ($content.Contains($old)) {
    $insert = $old + "`n    if (!outFile.is_open()) { std::cerr << \"无法打开文件 'scores.txt' 进行写入。\\n\"; return; }"
    $content = $content.Replace($old, $insert)
}

# 4) 在打开 winner.txt 后检查是否成功
$old2 = 'std::ofstream outFile("winner.txt");'
if ($content.Contains($old2)) {
    $insert2 = $old2 + "`n    if (!outFile.is_open()) { std::cerr << \"无法打开文件 'winner.txt' 进行写入。\\n\"; return; }"
    $content = $content.Replace($old2, $insert2)
}

# 5) partial_sort 安全化，使用 topN
$patternPS = 'std::partial_sort\(students.begin\(\), students.begin\(\) \+ 6, students.end\(\),'
if ($content -match $patternPS) {
    $content = $content -replace $patternPS, 'size_t topN = std::min((size_t)6, students.size());`n    std::partial_sort(students.begin(), students.begin() + topN, students.end(),'
}
# 6) 循环用 topN
$content = $content.Replace('for (int i = 0; i < 6; ++i) {', 'for (size_t i = 0; i < topN; ++i) {')

# 7) 加入分数读取失败的处理（保留 C++ 原样风格）
$content = $content.Replace('std::cin >> score;', 'if (!(std::cin >> score)) { std::cin.clear(); std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\''\n\''); score = 0; }')

# 保存修改
Set-Content -Encoding UTF8 $src $content
Write-Host "已应用代码修补：$src" -ForegroundColor Green

# Git 操作：初始化、创建分支、提交
if (-not (Test-Path .git\HEAD)) {
    Write-Host "未检测到 git 仓库，正在初始化..."
    git init
    git checkout -b main
}

$branch = "fix/sanitize"
git fetch origin --quiet 2>$null
git checkout -b $branch

git add -A
git commit -m "Sanitize: remove build artifacts, add .gitignore, input/file safety fixes, avoid system(color)" --allow-empty

# 使用 gh 创建仓库并推送
Write-Host "使用 gh 在你的账户下创建仓库 $repoName 并推送..."
$createCmd = "gh repo create $repoName --public --source=. --remote=origin --push --confirm"
Invoke-Expression $createCmd

# 创建 PR
Write-Host "创建 Pull Request..."
gh pr create --title "Fix: improve robustness and sanitize project" --body "自动应用：移除编译产物、添加 .gitignore、添加输入校验与文件打开检查、移除 system(color) 调用、修正平均值计算与部分排序安全。" --head $branch --base main --fill

Write-Host "完成。已推送并创建 PR。请在 GitHub 上验证并合并。" -ForegroundColor Cyan
