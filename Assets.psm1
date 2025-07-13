function assets {# A suite of options to view or edit commands and scripts for the current profile.
param ([string]$resourcetype, [string]$action, [string]$resource, [switch]$help)
$script:powershell = Split-Path $profile

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

function help {# Inline help.
function scripthelp ($section) {# (Internal) Generate the help sections from the comments section of the script.
line yellow 100 -pre; $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; line yellow 100
if ($lines.Count -gt 1) {wordwrap $lines[1] 100 | Write-Host -f white | Out-Host -Paging}; line yellow 100}
$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}

$selection = $null
do {cls; Write-Host -f cyan "$(Get-ChildItem (Split-Path $PSCommandPath) | Where-Object { $_.FullName -ieq $PSCommandPath } | Select-Object -ExpandProperty BaseName) Help Sections:`n"
for ($i = 0; $i -lt $sections.Count; $i++) {Write-Host "$($i + 1). " -f cyan -n; Write-Host $sections[$i].Groups[1].Value -f white}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
Write-Host -f yellow "`nEnter a section number to view " -n; $input = Read-Host
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# External call to help.
if ($help) {help; return}

# Contextual display
function contextdisplay ($command) {foreach ($line in $command) {if ($line -match '^<#') {$inBlockComment = $true}
if ($inBlockComment) {$colour = 'darkgray'
if ($line -match "^## ") {$colour = 'gray'}
if ($line -match '^#>') {$inBlockComment = $false}}
else {if ($line -match '^<?#') {$colour = 'yellow'}
elseif ($line -match '(?i)^function\s') {$colour = 'cyan'}
elseif ($line -match '(?i)^sal\s') {$colour = 'green'}
else {$colour = 'white'}}
Write-Host -f $colour $line}}

# View commands and scripts.
function assetviewer ($name, $content) {$searchHits = @(0..($content.Count - 1) | Where-Object {$content[$_] -match $pattern}); $currentSearchIndex = $searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1; $pos = $currentSearchIndex; $script:coloredContent = @(); $content = $content | ForEach-Object {wordwrap $_ $null} | ForEach-Object {$_ -split "`n"}

# Pre-configure colours.
$content | ForEach-Object {$line = $_
if ($line -match '^<#') {$inBlockComment = $true}
if ($inBlockComment) {$colour = 'darkgray'
if ($line -match "^## ") {$colour = 'gray'}
if ($line -match '^#>') {$inBlockComment = $false}}
else {if ($line -match '^(#|-----)') {$colour = 'yellow'}
elseif ($line -match '(?i)^function\s') {$colour = 'cyan'}
elseif ($line -match '(?i)^sal\s') {$colour = 'green'}
else {$colour = 'white'}}
$script:coloredContent += [PSCustomObject]@{Line = $line; Color = $colour}}

$pageSize = 44; $pos = 0; $script:fileName = [System.IO.Path]::GetFileName($script:file); $searchHits = @(); $currentSearchIndex = -1

function getbreakpoint {param($start); return [Math]::Min($start + $pageSize - 1, $content.Count - 1)}

function showpage {cls; $start = $pos; $end = getbreakpoint $start; $pageLines = $script:coloredContent[$start..$end]; $highlight = if ($searchTerm) {"$pattern"} else {$null}
foreach ($entry in $pageLines) {$line = $entry.Line; $colour = $entry.Color
if ($highlight -and $line -match $highlight) {$parts = [regex]::Split($line, "($highlight)")
foreach ($part in $parts) {if ($part -match "^$highlight$") {Write-Host -f black -b yellow $part -n}
else {Write-Host -f $colour $part -n}}; ""}
else {Write-Host -f $colour $line}}

# Pad with blank lines if this page has fewer than $pageSize lines
$linesShown = $end - $start + 1
if ($linesShown -lt $pageSize) {for ($i = 1; $i -le ($pageSize - $linesShown); $i++) {Write-Host ""}}}

# Main menu loop
$statusmessage = ""; $errormessage = ""; $searchmessage = "Search Commands"
while ($true) {showpage; $pageNum = [math]::Floor($pos / $pageSize) + 1; $totalPages = [math]::Ceiling($content.Count / $pageSize)
if ($searchHits.Count -gt 0) {$currentMatch = [array]::IndexOf($searchHits, $pos); if ($currentMatch -ge 0) {$searchmessage = "Match $($currentMatch + 1) of $($searchHits.Count)"}
else {$searchmessage = "Search active ($($searchHits.Count) matches)"}}
line yellow -double
if (-not $errormessage -or $errormessage.length -lt 1) {$middlecolour = "white"; $middle = $statusmessage} else {$middlecolour = "red"; $middle = $errormessage}
$left = "$name".PadRight(57); $middle = "$middle".PadRight(44); $right = "(Page $pageNum of $totalPages)"
Write-Host -f white $left -n; Write-Host -f $middlecolour $middle -n; Write-Host -f cyan $right
$left = "Page Commands".PadRight(55); $middle = "| $searchmessage ".PadRight(34); $right = "| Exit Commands"
Write-Host -f yellow ($left + $middle + $right)
Write-Host -f yellow "[F]irst [N]ext [+/-]# Lines P[A]ge # [P]revious [L]ast | [<][S]earch[>] [#]Match [C]lear | [Q]uit " -n
$statusmessage = ""; $errormessage = ""; $searchmessage = "Search Commands"

function getaction {[string]$buffer = ""
while ($true) {$key = [System.Console]::ReadKey($true)
switch ($key.Key) {'LeftArrow' {return 'P'}
'UpArrow' {return 'U1L'}
'Backspace' {return 'P'}
'PageUp' {return 'P'}
'RightArrow' {return 'N'}
'DownArrow' {return 'D1L'}
'PageDown' {return 'N'}
'Enter' {if ($buffer) {return $buffer}
else {return 'N'}}
'Home' {return 'F'}
'End' {return 'L'}
default {$char = $key.KeyChar
switch ($char) {',' {return '<'}
'.' {return '>'}
{$_ -match '(?i)[B-Z]'} {return $char.ToString().ToUpper()}
{$_ -match '[A#\+\-\d]'} {$buffer += $char}
default {$buffer = ""}}}}}}

$action = getaction

switch ($action.ToString().ToUpper()) {'F' {$pos = 0}
'N' {$next = getbreakpoint $pos; if ($next -lt $content.Count - 1) {$pos = $next + 1}
else {$pos = [Math]::Min($pos + $pageSize, $content.Count - 1)}}
'P' {$pos = [Math]::Max(0, $pos - $pageSize)}
'L' {$lastPageStart = [Math]::Max(0, [int][Math]::Floor(($content.Count - 1) / $pageSize) * $pageSize); $pos = $lastPageStart}

'<' {$currentSearchIndex = ($searchHits | Where-Object {$_ -lt $pos} | Select-Object -Last 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[-1]; $statusmessage = "Wrapped to last match."; $errormessage = $null}
$pos = $currentSearchIndex
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null}}
'S' {Write-Host -f green "`n`nKeyword to search forward from this point in the logs" -n; $searchTerm = Read-Host " "
if (-not $searchTerm) {$errormessage = "No keyword entered."; $statusmessage = $null; $searchTerm = $null; $searchHits = @(); continue}
$pattern = "(?i)$searchTerm"; $searchHits = @(0..($content.Count - 1) | Where-Object { $content[$_] -match $pattern })
if ($searchHits.Count -eq 0) {$errormessage = "Keyword not found in file."; $statusmessage = $null; $currentSearchIndex = -1}
else {$currentSearchIndex = $searchHits | Where-Object { $_ -gt $pos } | Select-Object -First 1
if ($null -eq $currentSearchIndex) {Write-Host -f green "No match found after this point. Jump to first match? (Y/N)" -n; $wrap = Read-Host " "
if ($wrap -match '^[Yy]$') {$currentSearchIndex = $searchHits[0]; $statusmessage = "Wrapped to first match."; $errormessage = $null}
else {$errormessage = "Keyword not found further forward."; $statusmessage = $null; $searchHits = @(); $searchTerm = $null}}
$pos = $currentSearchIndex}}
'>' {$currentSearchIndex = ($searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[0]; $statusmessage = "Wrapped to first match."; $errormessage = $null}
$pos = $currentSearchIndex
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null}}
'C' {$searchTerm = $null; $searchHits.Count = 0; $searchHits = @(); $currentSearchIndex = $null}
'Q' {cls; return}
'U1L' {$pos = [Math]::Max($pos - 1, 0)}
'D1L' {$pos = [Math]::Min($pos + 1, $content.Count - $pageSize)}

default {if ($action -match '^[\+\-](\d+)$') {$offset = [int]$action; $newPos = $pos + $offset; $pos = [Math]::Max(0, [Math]::Min($newPos, $content.Count - $pageSize))}

elseif ($action -match '^(\d+)$') {$jump = [int]$matches[1]
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null; continue}
$targetIndex = $jump - 1
if ($targetIndex -ge 0 -and $targetIndex -lt $searchHits.Count) {$pos = $searchHits[$targetIndex]
if ($targetIndex -eq 0) {$statusmessage = "Jumped to first match."}
else {$statusmessage = "Jumped to match #$($targetIndex + 1)."}; $errormessage = $null}
else {$errormessage = "Match #$jump is out of range."; $statusmessage = $null}}

elseif ($action -match '^A(\d+)$') {$requestedPage = [int]$matches[1]
if ($requestedPage -lt 1 -or $requestedPage -gt $totalPages) {$errormessage = "Page #$requestedPage is out of range."; $statusmessage = $null}
else {$pos = ($requestedPage - 1) * $pageSize}}

else {$errormessage = "Invalid input."; $statusmessage = $null}}}}}

# Display the contents of a function with colored comments.
function details {param($command)
# Use last command if none was provided.
if (-not $command) {$history = Get-History -ErrorAction SilentlyContinue
if ($history -and $history.Count -gt 0 -and $history[-1].CommandLine) {$command = $history[-1].CommandLine} else {""; return}}
# Otherwise, resolve the command.
$cmd = Get-Command $command -ErrorAction SilentlyContinue
if (-not $cmd) {Write-Host -f green "$command is not a valid command, function, alias or cmdlet."; return}
$source = $cmd.Source; $callcommand = $command
if ($cmd.CommandType -eq 'Alias') {$callcommand = $cmd.displayname; $parent = Get-Command $cmd.Definition; $definition = $parent.Definition -split "`n"; $definition += "sal -Name $command -Value $($cmd.Definition)"}
else {$definition = $cmd.Definition -split "`n"}
$name = "$callcommand"

if ($definition.Count -gt 30) {assetviewer $name $definition}
else {Write-Host -f cyan "`nCommand: " -n; Write-Host -f yellow $callcommand; Write-Host -f cyan "Source: " -n; Write-Host -f yellow $source; line yellow; contextdisplay $definition; line yellow -post; return}}

# Set Notepad++ to the default editor, if available and edit files passed to it.
function edit ($file){$script:edit = "notepad"; $npp = "Notepad++\notepad++.exe"; $paths = @("$env:ProgramFiles", "$env:ProgramFiles(x86)")
foreach ($path in $paths) {$test = Join-Path $path $npp; if (Test-Path $test) {$script:edit = $test; break}}
& $script:edit $file}

# Error checking.
if ($resourcetype -notmatch "(?i)^(cmd|script)$" -and $action -notmatch "(?i)^(view|edit)$") {Write-Host -f cyan "`nUsage: assets <cmd/script> <view/edit> <resource> -help`n"; return}

# Script path completion
if ($resourcetype -eq "script" -and $resource.length -ge 1 -and -not (Test-Path $resource -PathType Leaf)) {$priority = @('.psm1', '.ps1', '.psd1'); $candidates = Get-ChildItem -Path $powershell -Recurse -Include *.psm1, *.ps1, *.psd1 | Where-Object { $_.BaseName -match "(?i)^$resource$" }
if ($candidates) {$resource = $candidates | Sort-Object @{Expression = { $priority.IndexOf($_.Extension.ToLower()) }; Ascending = $true} | Select-Object -First 1; $resource = (Resolve-Path $resource).Path}
else {Write-Host -f yellow "`nUnable to locate a script with the name $resource`n"; return}}

# View scripts, whether specified or blank.
if ($resourcetype -eq "script" -and $action -eq "view") {if (-not $resource) {Write-Host -f yellow "`nAvailable Scripts:`n"; 
$ScriptFiles = Get-ChildItem -Path $powershell -Recurse | Where-Object {$_.Name -match '(?i)\.ps[dm]?1$'}
$ScriptFiles | ForEach-Object {$index = [Array]::IndexOf($ScriptFiles, $_) + 1; Write-Host -f cyan "$index. " -n
if ($_.FullName.Substring($powershell.Length + 1) -match "(?i)\.psm1$") {Write-Host ($_.FullName.Substring($powershell.Length + 1)) -f darkcyan}
elseif ($_.FullName.Substring($powershell.Length + 1) -match "(?i)\.psd1$") {Write-Host ($_.FullName.Substring($powershell.Length + 1)) -f darkgray}
else {Write-Host ($_.FullName.Substring($powershell.Length + 1)) -f white}}
""; Write-Host -f white "Select a script to " -n; Write-Host -f green "VIEW " -n; $selection = Read-Host
if ($selection -notmatch "^\d+$") {""; return}
if ([int]$selection -gt 0 -and [int]$selection -le $ScriptFiles.Count) {$resource = $ScriptFiles[$selection - 1].FullName}
else {""; return}}

# Build content, starting with the PSD1 file if it exists, then proceeding to the script content.
$configuration = [System.IO.Path]::Combine((Split-Path $resource), ([System.IO.Path]::GetFileNameWithoutExtension($resource)))+".psd1"
if ((Test-Path $configuration -ErrorAction SilentlyContinue) -and -not ([System.IO.Path]::GetExtension($resource) -match "\.psd1")) {$separator = "-" * 100; $configcontent = Get-Content $configuration; $resourcecontent = Get-Content $resource; $content = @(); $content += $configcontent; $content += $separator; $content += $resourcecontent}
else {$content = Get-Content $resource}

if ($content.Count -gt 30) {assetviewer $([System.IO.Path]::GetFileNameWithoutExtension($configuration)) $content}

else {Write-Host -f cyan "`nScript: " -n; Write-Host -f yellow $([System.IO.Path]::GetFileNameWithoutExtension($configuration)); line yellow; contextdisplay $content; line yellow -post; return}}

# View commands menu.
if ($resourcetype -eq "cmd" -and $action -eq "view" -and $resource.length -le 1) {Write-Host -f yellow "`nAvailable Functions`n"; $functions = Get-Command -CommandType Function; $filtered = $functions | Where-Object {$_.ScriptBlock.File -like "*Users*"}; $filtered | ForEach-Object {Write-Host -f cyan "$($filtered.IndexOf($_) + 1). " -n; Write-Host -f white "$($_.Name)"}; Write-Host -f white "`nSelect a function to " -n; Write-Host -f green "VIEW " -n; $selection = Read-Host
while ($selection -ne "Q") {if ($selection -match '^\d{1,2}$') {$index = [int]$selection; if ($index -gt 0 -and $index -le $filtered.Count) {$function = $filtered[$index - 1].Name; details $function; ""; return}
else {""; return}} else {""; return}};"" ; return}

# View specified command.
if ($resourcetype -eq "cmd" -and $action -eq "view" -and (Get-Command $resource -ErrorAction SilentlyContinue)) {""; details $resource; return}

# Edit commands menu.
if ($resourcetype -eq "cmd" -and $action -eq "edit" -and $resource.length -le 1) {Write-Host -f yellow "`nAvailable Functions`n"; $functions = Get-Command -CommandType Function; $filtered = $functions | Where-Object {$_.ScriptBlock.File -like "*Users*"}; $filtered | ForEach-Object {$i = $filtered.IndexOf($_) + 1; $mod = if ($_.Module) {$_.Module.Name.ToUpper()} else {"PROFILE"}; Write-Host -f cyan "$i. " -n; Write-Host -f darkcyan "$mod\" -n; Write-Host -f white "$($_.Name)"}; Write-Host -f white "`nSelect a function parent file to " -n; Write-Host -f red "EDIT " -n; $selection = Read-Host
while ($selection -ne "Q") {if ($selection -match '^\d{1,2}$') {$index = [int]$selection; if ($index -gt 0 -and $index -le $filtered.Count) {$filePath = $filtered[$index - 1].ScriptBlock.File; edit $filePath; ""; return}
else {""; return}} else {""; return}}}

# Edit specified command.
if ($resourcetype -eq "cmd" -and $action -eq "edit" -and (Get-Command $resource -ErrorAction SilentlyContinue)) {$command = Get-Command $resource -CommandType Function -ErrorAction SilentlyContinue; $filepath = $command.ScriptBlock.File; if ($filepath.length -ge 1) {edit $filepath}; return}

# Edit scripts menu.
if ($resourcetype -eq "script" -and $action -eq "edit" -and (($resource.length -le 1) -or (-not (Test-Path $resource -PathType Leaf)))) {Write-Host -f yellow "`nAvailable Scripts:`n"; $ScriptFiles = Get-ChildItem -Path $powershell -Recurse | Where-Object {$_.Name -match '(?i)\.ps[dm]?1$'}
$ScriptFiles | ForEach-Object {$index = [Array]::IndexOf($ScriptFiles, $_) + 1; Write-Host -f cyan "$index. " -n
if ($($_.FullName.Substring($powershell.Length + 1)) -match "(?i)\.psm1$") {Write-Host $($_.FullName.Substring($powershell.Length + 1)) -f darkcyan}
elseif ($($_.FullName.Substring($powershell.Length + 1)) -match "(?i)\.psd1$") {Write-Host $($_.FullName.Substring($powershell.Length + 1)) -f darkgray}
else {Write-Host $($_.FullName.Substring($powershell.Length + 1)) -f white}}; ""
Write-Host -f white "Select a script to " -n; Write-Host -f red "EDIT " -n; $selection = Read-Host
if ([int]$selection -gt 0 -and [int]$selection -le $ScriptFiles.Count) {$selectedFile = $ScriptFiles[$selection - 1]; edit $selectedFile.FullName}
else {[console]::foregroundcolor = "gray"; ""; return}}

# Edit specified script.
if ($resourcetype -eq "script" -and $action -eq "edit" -and (Test-Path $resource -PathType Leaf)) {edit $resource; return}}

# Edit custom commands.
function editcmd ($resource) {assets cmd edit $resource}
sal -name ec -value editcmd -scope global

# Create/edit a new or existing PowerShell module file.
function editmodule ($script) {if ($script.length -le 1) {assets script edit; return}
$path="$powershell\modules\$script\$script.psm1"
if (Test-Path $path) {edit "$path"}
if (!(Test-Path $path)) {Write-Host "`nPath '$path' does not exist." -f yellow; $response=Read-Host "Create it now? (Y/N)";
if ($response -match '^[Yy]') {New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($path)) -Force | Out-Null;
New-Item -ItemType File -Path $path -Force | Out-Null}; ""}}
sal -Name em -Value editmodule

# Edit this Powershell profile.
function editprofile{& edit $profile}
sal -Name ep -Value editprofile

# Edit custom scripts.
function editscript ($resource) {assets script edit $resource}
sal -name es -value editscript -scope global

# View custom command details.
function seecmd ($resource) {assets "cmd" "view" "$resource"}
sal -name see -value seecmd -scope global

# View custom script details.
function seescript ($resource) {assets script view $resource}
sal -name ss -value seescript -scope global

Export-ModuleMember -Function assets, editcmd, editmodule, editprofile, editscript, seecmd, seescript
Export-ModuleMember -Alias ec, em, ep, es, see, ss

<#
## Assets
This function allows you to manage custom user content in your PowerShell environment with a myriad of options:

    Usage: assets <cmd/script> <view/edit> <resource> -help

To view commands or scripts on screen in a contextualized format use:

    assets cmd view "resource"
    assets script view "resource"
    assets cmd edit "resource"
    assets script edit "resource"

• If no "resource" is specified, the function will display a menu of available commands/scripts.

• While viewing long scripts, a contexualized viewer will be employed.
## Other Commands
Macros and aliases have been created for common functions within the Assets framework, in order to expedite common tasks:

        editprofile/ep - Edit this user's Powershell profile.

Other commands, with an optional "resource" parameter:

    Usage: <command> "resource"

        editcmd/ec     - Edit the script that hosts the command.
        editmodule/em  - Edit the module specified, or ask to create it, if it doesn't exist.
        editscript/es  - Edit a specific script.
        seecmd/see     - View a specific command.
        seescript/ss   - View a specific script.

• If no "resource" is specified, the function will display a menu of available commands/scripts.

• In the case of editmodule, this will consist of PSM1 and PSD1 files, but the editscript menu will also include PS1 files.
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>
