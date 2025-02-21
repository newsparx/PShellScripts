# Define output file with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = "$env:USERPROFILE\Desktop\DC_Status_Report_$timestamp.csv"

# Get list of all Domain Controllers
$DCs = Get-ADDomainController -Filter *

# Get FSMO Role Holders
$fsmoRoles = @{
    "Schema Master"       = (Get-ADForest).SchemaMaster
    "Domain Naming Master"= (Get-ADForest).DomainNamingMaster
    "PDC Emulator"        = (Get-ADDomain).PDCEmulator
    "RID Master"          = (Get-ADDomain).RIDMaster
    "Infrastructure Master" = (Get-ADDomain).InfrastructureMaster
}

# Initialize an array to store report data
$report = @()

Write-Host "Gathering Domain Controller Status..." -ForegroundColor Cyan

foreach ($DC in $DCs) {
    $server = $DC.HostName
    Write-Host "Checking $server..." -ForegroundColor Yellow

    # Determine FSMO Roles held by this DC
    $schemaMaster       = if ($fsmoRoles["Schema Master"] -eq $server) { "Yes" } else { "No" }
    $domainNamingMaster = if ($fsmoRoles["Domain Naming Master"] -eq $server) { "Yes" } else { "No" }
    $pdcEmulator        = if ($fsmoRoles["PDC Emulator"] -eq $server) { "Yes" } else { "No" }
    $ridMaster          = if ($fsmoRoles["RID Master"] -eq $server) { "Yes" } else { "No" }
    $infrastructureMaster = if ($fsmoRoles["Infrastructure Master"] -eq $server) { "Yes" } else { "No" }

    # 2️⃣ Active Directory Replication Check
    try {
        $replicationTest = repadmin /showrepl $server 2>$null
        $replicationStatus = if ($replicationTest -match "0 failed") { "Healthy" } else { "Issues Detected" }
    } catch { $replicationStatus = "Error Retrieving" }

    # 3️⃣ DNS Status Check (Port 53 & DNS Lookup)
    try {
        # Step 1: Confirm DNS service is listening on port 53
        $dnsPortTest = Test-NetConnection -ComputerName $server -Port 53 -InformationLevel Quiet
        $dnsListening = if ($dnsPortTest -eq $true) { "Healthy (Port 53 Open)" } else { "DNS Not Responding" }

        # Step 2: Perform a DNS Query Test
        $dnsTestResult = Resolve-DnsName $server -Type A -ErrorAction SilentlyContinue
        if ($dnsTestResult -ne $null) {
            $dnsQueryResult = "DNS Query Successful"
        } else {
            $dnsQueryResult = "DNS Query Failed: " + $Error[0]
        }
        Write-Host $dnsQueryResult
    } catch { $dnsResponse = "Error Checking DNS" }

    # 4️⃣ Global Catalog Status
    try {
        $gcCheck = Get-ADDomainController -Identity $server | Select-Object IsGlobalCatalog
        $gcStatus = if ($gcCheck.IsGlobalCatalog -eq $true) { "Enabled" } else { "Not Enabled" }
    } catch { $gcStatus = "Error Retrieving" }

    # 5️⃣ Time Sync Status
    try {
        $timeCheck = w32tm /query /status /computer:$server 2>$null
        if ($timeCheck -match "Source:") {
            $timeSyncStatus = ($timeCheck | Select-String "Source:").ToString().Trim()
        } else {
            $timeSyncStatus = "Time Sync Issue"
        }
    } catch { $timeSyncStatus = "Error Retrieving" }

    # Append data to the report array
    $report += [PSCustomObject]@{
        "Domain Controller"     = $server
        "Schema Master"         = $schemaMaster
        "Domain Naming Master"  = $domainNamingMaster
        "PDC Emulator"          = $pdcEmulator
        "RID Master"            = $ridMaster
        "Infrastructure Master" = $infrastructureMaster
        "Replication Status"    = $replicationStatus
        "DNS Status"            = $dnsListening
        "DNS Query Result"      = $dnsQueryResult
        "Global Catalog"        = $gcStatus
        "Time Sync"             = $timeSyncStatus
    }
}

# Export to CSV
$report | Export-Csv -Path $reportPath -NoTypeInformation

Write-Host "✅ Report generated: $reportPath" -ForegroundColor Green
