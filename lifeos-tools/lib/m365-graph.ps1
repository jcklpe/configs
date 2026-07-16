[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("auth", "request")]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$RequestPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    $request = Get-Content -Raw -LiteralPath $RequestPath | ConvertFrom-Json
    $scopes = @($request.scopes | ForEach-Object { [string]$_ })
    if ($scopes.Count -eq 0) {
        throw "At least one Microsoft Graph scope is required."
    }

    $connect = @{
        Scopes       = $scopes
        ContextScope = "CurrentUser"
        NoWelcome    = $true
    }
    if ($request.tenant -and [string]$request.tenant -ne "organizations") {
        $connect.TenantId = [string]$request.tenant
    }
    if ($Mode -eq "auth" -and $request.no_browser -eq $true) {
        $connect.UseDeviceCode = $true
    }

    Connect-MgGraph @connect
    $context = Get-MgContext
    if ($null -eq $context) {
        throw "Microsoft Graph authentication completed without an active context."
    }

    if ($Mode -eq "auth") {
        [ordered]@{
            account             = $context.Account
            tenant_id           = $context.TenantId
            client_id           = $context.ClientId
            requested_scopes    = $scopes
            effective_scope_count = @($context.Scopes).Count
        } | ConvertTo-Json -Depth 4 -Compress
        exit 0
    }

    $headers = @{}
    if ($null -ne $request.headers) {
        foreach ($property in $request.headers.PSObject.Properties) {
            $headers[$property.Name] = [string]$property.Value
        }
    }

    $invoke = @{
        Method     = [string]$request.method
        Uri        = [string]$request.uri
        OutputType = "Json"
    }
    if ($headers.Count -gt 0) {
        $invoke.Headers = $headers
    }
    if ([string]$request.body) {
        $invoke.Body = [string]$request.body
        $invoke.ContentType = "application/json; charset=utf-8"
    }

    $response = Invoke-MgGraphRequest @invoke
    if ($null -eq $response -or [string]$response -eq "") {
        "{}"
    } else {
        [string]$response
    }
} catch {
    $message = $_.Exception.Message -replace "[\r\n]+", " "
    [Console]::Error.WriteLine("ERROR: Microsoft Graph PowerShell request failed: $message")
    exit 1
}
