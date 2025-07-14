@{RootModule = 'Assets.psm1'
ModuleVersion = '1.3'
GUID = 'e048c1ae-779a-4124-8cca-b3bff5a619d8'
Author = 'Craig Plath'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '© Craig Plath. All rights reserved.'
Description = 'PowerShell module to manage custom scripts and functions with several options to view and edit.'
PowerShellVersion = '5.1'
FunctionsToExport = @('assets', 'editcmd', 'editmodule', 'editprofile', 'editscript', 'seecmd', 'seescript')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @('ec', 'em', 'ep', 'es', 'see', 'ss')
FileList = @('Assets.psm1')

PrivateData = @{PSData = @{Tags = @('commands', 'function', 'alias', 'shortcut', 'edit', 'viewer', 'context', 'development', 'powershell')
LicenseUri = 'https://github.com/Schvenn/Assets/blob/main/LICENSE'
ProjectUri = 'https://github.com/Schvenn/Assets'
ReleaseNotes = 'Improved help.'}}}
