# Define output file with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = "$env:USERPROFILE\Desktop\DC_Status_Report_$timestamp.csv"

# Get list of all Domain Controllers
$DCs = Get-ADDomainController -Filter *

# Get FSMO Role Holders
$fsmoRoles = @{
    "Schema Master"        = (Get-ADForest).SchemaMaster
    "Domain Naming Master" = (Get-ADForest).DomainNamingMaster
    "PDC Emulator"         = (Get-ADDomain).PDCEmulator
    "RID Master"           = (Get-ADDomain).RIDMaster
    "Infrastructure Master"= (Get-ADDomain).InfrastructureMaster
}

# Initialize an array to store report data
$report = @()

Write-Host "Gathering Domain Controller Status..." -ForegroundColor Cyan

foreach ($DC in $DCs) {
    $server = $DC.HostName
    Write-Host "Checking $server..." -ForegroundColor Yellow

    # Determine FSMO Roles held by this DC
    $schemaMaster        = if ($fsmoRoles["Schema Master"] -eq $server) { "Yes" } else { "No" }
    $domainNamingMaster  = if ($fsmoRoles["Domain Naming Master"] -eq $server) { "Yes" } else { "No" }
    $pdcEmulator         = if ($fsmoRoles["PDC Emulator"] -eq $server) { "Yes" } else { "No" }
    $ridMaster           = if ($fsmoRoles["RID Master"] -eq $server) { "Yes" } else { "No" }
    $infrastructureMaster= if ($fsmoRoles["Infrastructure Master"] -eq $server) { "Yes" } else { "No" }

    # DNS Lookup Test (Checking if DC can resolve external domain)
    try {
        $dnsLookup = Resolve-DnsName google.com -Server $server -ErrorAction Stop
        $dnsStatus = if ($dnsLookup) { "DNS Lookup Successful" } else { "DNS Lookup Failed" }
    } catch {
        $dnsStatus = "DNS Lookup Failed"
    }

    # Append data to the report array
    $report += [PSCustomObject]@{
        "Domain Controller"     = $server
        "Schema Master"         = $schemaMaster
        "Domain Naming Master"  = $domainNamingMaster
        "PDC Emulator"          = $pdcEmulator
        "RID Master"            = $ridMaster
        "Infrastructure Master" = $infrastructureMaster
        "DNS Lookup Status"     = $dnsStatus
    }
}

# Check if AD Recycle Bin is enabled
Write-Host "Checking if AD Recycle Bin is enabled..." -ForegroundColor Cyan
try {
    $recycleBinFeature = Get-ADOptionalFeature -Filter { Name -eq "Recycle Bin Feature" }
    $recycleBinStatus = if ($recycleBinFeature.EnabledScopes) { "Enabled" } else { "Disabled" }
} catch {
    $recycleBinStatus = "Error Checking Status"
}

# Append AD Recycle Bin status to report
$report += [PSCustomObject]@{
    "Domain Controller"     = "AD Recycle Bin"
    "Schema Master"         = ""
    "Domain Naming Master"  = ""
    "PDC Emulator"          = ""
    "RID Master"            = ""
    "Infrastructure Master" = ""
    "DNS Lookup Status"     = $recycleBinStatus
}

# Export results to CSV
$report | Export-Csv -Path $reportPath -NoTypeInformation

Write-Host "✅ DC Status Report generated: $reportPath" -ForegroundColor Green
