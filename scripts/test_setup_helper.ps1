# Credential-free Windows tests. Synthetic PEM text tests formatting, not cryptography.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$helper = Join-Path $PSScriptRoot 'setup_testflight.ps1'
$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($helper, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'PowerShell helper has parse errors.' }
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
[void](New-Item -ItemType Directory -Path $temp)
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-TestFile([string]$Name, [string]$Text) {
    $path = Join-Path $temp $Name
    [System.IO.File]::WriteAllText($path, $Text, $utf8)
    return $path
}
try {
    $config = Write-TestFile 'settings.json' '{"repository":"Yangston/youcantparkthere","environment":"testflight","app_id":"1234567890","issuer_id":"11111111-1111-1111-1111-111111111111","key_id":"TESTKEY123","bundle_id":"com.example.test"}'
    $apiKey = Write-TestFile 'api.p8' "-----BEGIN PRIVATE KEY-----`nYWJj`n-----END PRIVATE KEY-----`n"
    $signingKey = Write-TestFile 'signing.pem' "-----BEGIN RSA PRIVATE KEY-----`nZGVm`n-----END RSA PRIVATE KEY-----`n"
    $badKey = Write-TestFile 'bad.p8' 'not a private key'
    $wrongConfig = Write-TestFile 'wrong.json' '{"repository":"someone/else","environment":"testflight","app_id":"1234567890","issuer_id":"11111111-1111-1111-1111-111111111111","key_id":"TESTKEY123","bundle_id":"com.example.test"}'
    $cases = @(
        @{ Name='Valid format'; Team='TEAM123456'; Api=$apiKey; Signing=$signingKey; Config=$config; Expected=0 },
        @{ Name='Invalid team'; Team='BAD'; Api=$apiKey; Signing=$signingKey; Config=$config; Expected=1 },
        @{ Name='Identical keys'; Team='TEAM123456'; Api=$apiKey; Signing=$apiKey; Config=$config; Expected=1 },
        @{ Name='Malformed key'; Team='TEAM123456'; Api=$badKey; Signing=$signingKey; Config=$config; Expected=1 },
        @{ Name='Wrong repository'; Team='TEAM123456'; Api=$apiKey; Signing=$signingKey; Config=$wrongConfig; Expected=1 }
    )
    foreach ($case in $cases) {
        $output = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $helper -ValidateOnly -ConfigPath $case.Config -TeamId $case.Team -ApiKeyPath $case.Api -CertificateKeyPath $case.Signing
        if ($LASTEXITCODE -ne $case.Expected) { throw ('Unexpected exit code: ' + $case.Name) }
        if (($output -join "`n") -match 'BEGIN.*PRIVATE KEY|YWJj|ZGVm') { throw 'Helper printed key material.' }
        Write-Host ('PASS: ' + $case.Name)
    }
    Write-Host 'PASS: parsing, 5 input-validation cases, and no key material in output.'
    Write-Host 'These checks do not authenticate GitHub, change secrets, or contact Apple.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}
