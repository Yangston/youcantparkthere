# Requires Windows PowerShell 5.1+ and GitHub CLI. No Python, Swift, or OpenSSL needed.
# Secrets are sent to gh through redirected standard input, never CLI arguments.
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'testflight-settings.json'),
    [string]$ApiKeyPath,
    [string]$CertificateKeyPath = (Join-Path $PSScriptRoot 'park_distribution_private_key.pem'),
    [string]$TeamId,
    [switch]$ValidateOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-Gh {
    $command = Get-Command gh.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidate = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    return $null
}

function Invoke-Gh {
    param([string[]]$Arguments, [AllowEmptyString()][string]$InputText)
    # Every argument is a validated identifier, fixed switch, or fixed API path.
    # JSON and secret material go through stdin instead of Windows quoting.
    foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') { throw 'Unexpected whitespace or quote in a CLI argument.' }
    }
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $script:GhPath
    $info.Arguments = $Arguments -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['GH_HOST'] = 'github.com'
    $info.EnvironmentVariables['GH_DEBUG'] = ''
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        if ($PSBoundParameters.ContainsKey('InputText')) {
            $process.StandardInput.Write($InputText)
        }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(180000)) {
            $process.Kill()
            throw 'A GitHub request timed out. Run the helper again; it can resume safely.'
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $outputTask.Result
            ErrorText = $errorTask.Result
        }
    } finally {
        $process.Dispose()
    }
}

function Require-Success {
    param($Result, [string]$Operation)
    if ($Result.ExitCode -ne 0) {
        # Do not echo arbitrary API response bodies or credential material.
        throw "$Operation failed (GitHub CLI exit $($Result.ExitCode)). Check account access and connectivity, then rerun. Any already-saved settings remain saved."
    }
}

function Read-Pem {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description file was not found. Keep key files outside the repository."
    }
    $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path).Trim()
    if ($text.Length -gt 16384 -or $text -notmatch '(?s)^-----BEGIN (RSA )?PRIVATE KEY-----\s+[A-Za-z0-9+/=\s]+\s+-----END (RSA )?PRIVATE KEY-----$') {
        throw "$Description must be an unencrypted PEM private-key file, not a certificate or filename."
    }
    return $text + "`n"
}

function Choose-ApiKey {
    param([string]$KeyId)
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = 'Choose your Apple API key. It will go only to GitHub Actions secrets.'
        $dialog.Filter = 'Apple API private key (*.p8)|*.p8'
        $dialog.FileName = "AuthKey_$KeyId.p8"
        $dialog.CheckFileExists = $true
        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            throw 'No API key selected. No settings have been changed.'
        }
        return $dialog.FileName
    } finally { $dialog.Dispose() }
}

try {
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw 'Missing testflight-settings.json. Use the private setup bundle or the documented config template.'
    }
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $repository = [string]$config.repository
    $environment = [string]$config.environment
    $appId = ([string]$config.app_id).Trim()
    $issuerId = ([string]$config.issuer_id).Trim()
    $keyId = ([string]$config.key_id).Trim()
    $bundleId = ([string]$config.bundle_id).Trim()
    if ($repository -ne 'Yangston/youcantparkthere' -or $environment -ne 'testflight') {
        throw 'This helper is restricted to Yangston/youcantparkthere and its testflight environment.'
    }
    $guid = [guid]::Empty
    if (-not [guid]::TryParse($issuerId, [ref]$guid)) { throw 'Issuer ID must be an Apple issuer UUID.' }
    if ($keyId -notmatch '^[A-Z0-9]{10}$') { throw 'Key ID must be 10 uppercase letters/numbers.' }
    if ($appId -notmatch '^[0-9]+$') { throw 'App ID must contain digits only.' }
    if ($bundleId -notmatch '^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$') { throw 'Bundle ID is not a reverse-DNS identifier.' }
    if (-not $TeamId) {
        if ($ValidateOnly) { throw 'Provide -TeamId when using -ValidateOnly.' }
        Write-Host 'Find your Team ID at Apple Developer > Account > Membership details.'
        Write-Host 'It is NOT the App ID, API Key ID, or Issuer ID.'
        $TeamId = Read-Host 'Apple Team ID (10 characters)'
    }
    $TeamId = $TeamId.Trim().ToUpperInvariant()
    if ($TeamId -notmatch '^[A-Z0-9]{10}$') { throw 'Apple Team ID must be 10 letters/numbers.' }
    if (-not $ApiKeyPath) {
        if ($ValidateOnly) { throw 'Provide -ApiKeyPath when using -ValidateOnly.' }
        $ApiKeyPath = Choose-ApiKey -KeyId $keyId
    }
    $apiPem = Read-Pem -Path $ApiKeyPath -Description 'Apple API key'
    $certificatePem = Read-Pem -Path $CertificateKeyPath -Description 'Distribution signing key'
    if ($apiPem.Trim() -eq $certificatePem.Trim()) { throw 'The API key and distribution signing key must be different keys.' }
    if ($ValidateOnly) {
        Write-Host 'PASS: configuration formats and distinct PEM files are present. No API calls or writes performed.'
        Write-Host 'This does not validate Apple permissions, key-ID matching, signing, or TestFlight acceptance.'
        exit 0
    }

    Write-Host "Destination: $repository / environment $environment"
    Write-Host "Apple app record: $appId; bundle: $bundleId"
    Write-Host 'Existing Apple API settings will be updated. An existing signing-key secret will be preserved.'
    Write-Host 'This helper does not start a build, create an Apple certificate, or publish an app.'
    if ((Read-Host 'Continue with this setup? [y/N]') -notmatch '^(?i)y(es)?$') { throw 'Setup canceled before any changes.' }

    $script:GhPath = Find-Gh
    if (-not $script:GhPath) {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $winget) { throw 'Install GitHub CLI from cli.github.com, then run this helper again.' }
        if ((Read-Host 'Install the official GitHub CLI using winget? [y/N]') -notmatch '^(?i)y(es)?$') {
            throw 'GitHub CLI is required. Install it, then rerun the helper.'
        }
        & $winget.Source install --id GitHub.cli --exact --source winget
        if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI installation did not complete. No settings changed.' }
        $script:GhPath = Find-Gh
        if (-not $script:GhPath) { throw 'GitHub CLI was installed; close this window and run the helper again to refresh PATH.' }
    }
    $auth = Invoke-Gh -Arguments @('auth','status','--hostname','github.com')
    if ($auth.ExitCode -ne 0) {
        Write-Host 'Sign in to GitHub in the browser. Never paste a GitHub token into chat.'
        & $script:GhPath auth login --hostname github.com --git-protocol https --web
        if ($LASTEXITCODE -ne 0) { throw 'GitHub browser login did not finish. No settings changed.' }
    }
    $repoResult = Invoke-Gh -Arguments @('api',"repos/$repository")
    Require-Success $repoResult 'Checking repository access'
    $repoInfo = $repoResult.Output | ConvertFrom-Json
    if (-not $repoInfo.permissions.admin) { throw 'Use a GitHub account with administrator access to this repository.' }

    $envPath = "repos/$repository/environments/$environment"
    $envResult = Invoke-Gh -Arguments @('api',$envPath)
    $created = $false
    if ($envResult.ExitCode -ne 0) {
        if ($envResult.ErrorText -notmatch 'HTTP 404') { Require-Success $envResult 'Reading the environment' }
        $body = '{"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}'
        $result = Invoke-Gh -Arguments @('api','--method','PUT',$envPath,'--input','-') -InputText $body
        Require-Success $result 'Creating the main-only environment'
        $created = $true
        $envResult = $result
    }
    $envInfo = $envResult.Output | ConvertFrom-Json
    if ($envInfo.deployment_branch_policy -and $envInfo.deployment_branch_policy.custom_branch_policies) {
        $policiesResult = Invoke-Gh -Arguments @('api',"$envPath/deployment-branch-policies")
        Require-Success $policiesResult 'Checking deployment branches'
        $policies = @((($policiesResult.Output | ConvertFrom-Json).branch_policies))
        if ($policies.Count -eq 0) {
            # Also repairs a previous interrupted create before its main policy was saved.
            $result = Invoke-Gh -Arguments @('api','--method','POST',"$envPath/deployment-branch-policies",'--input','-') -InputText '{"name":"main","type":"branch"}'
            Require-Success $result 'Allowing the main branch'
        } elseif (-not @($policies | Where-Object { $_.name -eq 'main' -and $_.type -eq 'branch' }).Count) {
            Write-Host 'Existing deployment rules are preserved. Confirm that they permit main before running an upload.'
        }
    }
    if (-not $created) { Write-Host 'Existing environment protection and approval rules were not replaced.' }

    $result = Invoke-Gh -Arguments @('secret','list','--repo',$repository,'--env',$environment,'--json','name')
    Require-Success $result 'Reading existing secret names'
    $existingRecords = ConvertFrom-Json -InputObject $result.Output
    $existingNames = @(foreach ($item in $existingRecords) { $item.name })
    $repoSecretsResult = Invoke-Gh -Arguments @('secret','list','--repo',$repository,'--json','name')
    Require-Success $repoSecretsResult 'Reading repository-level secret names'
    $repoSecretRecords = ConvertFrom-Json -InputObject $repoSecretsResult.Output
    $repoSecretNames = @(foreach ($item in $repoSecretRecords) { $item.name })
    $secrets = [ordered]@{
        APP_STORE_CONNECT_ISSUER_ID = $issuerId
        APP_STORE_CONNECT_KEY_IDENTIFIER = $keyId
        APP_STORE_CONNECT_PRIVATE_KEY = $apiPem
    }
    if ($existingNames -contains 'CERTIFICATE_PRIVATE_KEY' -or $repoSecretNames -contains 'CERTIFICATE_PRIVATE_KEY') {
        Write-Host 'Keeping the existing CERTIFICATE_PRIVATE_KEY; the bundled new key is not uploaded.'
    } else { $secrets['CERTIFICATE_PRIVATE_KEY'] = $certificatePem }
    foreach ($name in $secrets.Keys) {
        $result = Invoke-Gh -Arguments @('secret','set',$name,'--repo',$repository,'--env',$environment) -InputText ([string]$secrets[$name])
        Require-Success $result "Saving secret $name"
        Write-Host "Saved secret: $name (value not displayed)"
    }
    $variables = [ordered]@{ APPLE_TEAM_ID = $TeamId; APP_STORE_APP_ID = $appId; BUNDLE_ID = $bundleId }
    foreach ($name in $variables.Keys) {
        $result = Invoke-Gh -Arguments @('variable','set',$name,'--repo',$repository,'--env',$environment) -InputText ([string]$variables[$name])
        Require-Success $result "Saving variable $name"
        Write-Host "Saved variable: $name"
    }
    $result = Invoke-Gh -Arguments @('secret','list','--repo',$repository,'--env',$environment,'--json','name')
    Require-Success $result 'Confirming saved secret names'
    $savedRecords = ConvertFrom-Json -InputObject $result.Output
    $savedNames = @(foreach ($item in $savedRecords) { $item.name })
    $savedNames = @($savedNames) + @($repoSecretNames)
    foreach ($name in @('APP_STORE_CONNECT_ISSUER_ID','APP_STORE_CONNECT_KEY_IDENTIFIER','APP_STORE_CONNECT_PRIVATE_KEY','CERTIFICATE_PRIVATE_KEY')) {
        if ($savedNames -notcontains $name) { throw "Secret $name is missing after setup." }
    }
    $result = Invoke-Gh -Arguments @('variable','list','--repo',$repository,'--env',$environment,'--json','name,value')
    Require-Success $result 'Confirming saved variables'
    $savedVariables = ConvertFrom-Json -InputObject $result.Output
    foreach ($name in $variables.Keys) {
        $matches = @($savedVariables | Where-Object { $_.name -eq $name -and $_.value -eq $variables[$name] })
        if ($matches.Count -ne 1) { throw "Variable $name did not read back correctly." }
    }
    Write-Host ''
    Write-Host 'SUCCESS: all four effective secret names and all three variable values are confirmed in GitHub.'
    Write-Host 'Secret values cannot be read back. Apple authentication/signing still need the first upload.'
    Write-Host 'Next: repository > Actions > Upload to TestFlight > Run workflow > main.'
    Write-Host 'Keep the keys in a private backup outside the repository. Do not upload this setup folder to GitHub.'
    exit 0
} catch {
    Write-Host ''
    Write-Host ('STOP: ' + $_.Exception.Message)
    exit 1
} finally {
    $apiPem = $null
    $certificatePem = $null
    $secrets = $null
}
