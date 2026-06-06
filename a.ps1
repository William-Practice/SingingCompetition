# create_and_push.ps1
param()
set -e

function Check-Tool($name, $cmd) {
    try { & $cmd > $null 2>&1; return $true } catch { return $false }
}

if (-not (Check-Tool "git" "git --version")) { Write-Error "git 未安装或不可用."; exit 1 }
if (-not (Check-Tool "gh" "gh --version")) { Write-Error "gh CLI 未安装或不可用."; exit 1 }

Write-Host "确保已撤销旧 PAT，并已用 'gh auth login' 登录或设置 GITHUB_TOKEN 环境变量." -ForegroundColor Yellow
$ok = Read-Host "确认已处理（输入 Y 继续）"
if ($ok -ne 'Y' -and $ok -ne 'y') { Write-Host "已取消."; exit 0 }

# ask repo name
$defaultRepo = "SingingCompetition"
$repoName = Read-Host "要在 GitHub 上创建的仓库名（回车使用 $defaultRepo）"
if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = $defaultRepo }

# remove build artifacts
Write-Host "移除编译产物..."
$patterns = @("*.exe","*.pdb","*.ilk","*.log","*.obj",".vs","x64\Debug")
foreach ($p in $patterns) {
    Get-ChildItem -Path . -Recurse -Force -ErrorAction SilentlyContinue -Include $p | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
# create .gitignore for Visual Studio
$gitignore = @"
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
"@
if (-not (Test-Path .gitignore)) { $gitignore | Out-File -Encoding utf8 .gitignore }

# Edit source to apply safe fixes
$src = "SingingCompetition\SingingCompetition.cpp"
if (-not (Test-Path $src)) { Write-Error "$src 未找到。请在项目根目录运行此脚本."; exit 1 }

$content = Get-Content -Raw $src -Encoding UTF8

# 1) 禁用 system("color") 调用（改为注释）
$content = $content -replace '(^\s*system\("color [0-9A-Fa-f]{2}"\);\s*$)', '// $1  // removed for safety'

# 2) accumulate 初始值改为 0.0 并用 double
$content = $content -replace 'float sum = std::accumulate\(student.scores.begin\(\) \+ 1, student.scores.end\(\) - 1, 0\);', 'double sum = std::accumulate(student.scores.begin() + 1, student.scores.end() - 1, 0.0);'

# 3) scores.txt 打开检查
$content = $content -replace 'std::ofstream outFile\("scores.txt"\);\s*for \(const auto& stu : students\) {', 'std::ofstream outFile("scores.txt");\n    if (!outFile.is_open()) { std::cerr << "无法打开文件 \\'scores.txt\\' 进行写入。\\n"; return; }\n    for (const auto& stu : students) {'

# 4) winner.txt 打开检查
$content = $content -replace 'std::ofstream outFile\("winner.txt"\);\s*if \(!outFile.is_open\(\)\) {', 'std::ofstream outFile("winner.txt");\n    if (!outFile.is_open()) { std::cerr << "无法打开文件 \\'winner.txt\\' 进行写入。\\n"; return; }'

# 5) partial_sort 安全性：限制为实际元素数
$content = $content -replace 'std::partial_sort\(students.begin\(\), students.begin\(\) \+ 6, students.end\(\),', 'size_t topN = std::min((size_t)6, students.size());\n    std::partial_sort(students.begin(), students.begin() + topN, students.end(),'

# 6) 将输出循环的 6 改为 topN（如果存在）
$content = $content -replace 'for \(int i = 0; i < 6; \+\+i\) {', 'for (size_t i = 0; i < topN; ++i) {'

# 7) 输入分数读取，加入流失败检测（对单行替换，确保匹配）
$content = $content -replace 'std::cin >> score;', 'if (!(std::cin >> score)) { std::cin.clear(); std::cin.ignore(std::numeric_limits<std::streamsize>::max(), ''\n''); score = 0; }'

# Save edits if changed
Set-Content -Encoding UTF8 $src $content

# git init if needed
if (-not (Test-Path .git\.git)) {
    Write-Host "未检测到 git 仓库，正在初始化..."
    git init
    git checkout -b main
}

# create branch
$branch = "fix/sanitize"
git fetch origin --quiet 2>$null
git checkout -b $branch

git add -A
git commit -m "Sanitize: remove build artifacts, add .gitignore, input/file safety fixes, avoid system(color)" --allow-empty

# create remote repo under authenticated user
Write-Host "使用 gh 在你的账户下创建仓库 $repoName ..."
$createCmd = "gh repo create $repoName --public --source=. --remote=origin --push --confirm"
Invoke-Expression $createCmd

# create PR
Write-Host "创建 Pull Request..."
gh pr create --title "Fix: improve robustness and sanitize project" --body "自动应用：移除编译产物、添加 .gitignore、添加输入校验与文件打开检查、移除 system(color) 调用、修正平均值计算与部分排序安全。" --head $branch --base main --fill

Write-Host "完成。已推送并创建 PR。请在 GitHub 上验证并选择合并。"