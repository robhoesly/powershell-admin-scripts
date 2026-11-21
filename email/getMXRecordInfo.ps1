# ------------------------------------------------------------------------- #
# Find MX, SPF, DKIM, DMARC, & DNS Host/Nameserver Info
# Optimized Array Performance, Fixed Loop Logic, Stable String Trapping
# ------------------------------------------------------------------------- #

# 1. Set PowerShell execution policy to run script
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 2. Define input and output files and path
$domainListPath = "$PSScriptRoot\MXdomains.txt"
$outputCsvPath  = "$PSScriptRoot\MX_Record_Report.csv"

# 2b. Tailored list of most common corporate email DKIM selectors
$CommonSelectors = @("selector1", "sig1", "default", "google", "ms")

# 3. Read domains from text file into array safely
if (-not (Test-Path $domainListPath)) {
    Write-Error "Input file missing at $domainListPath. Please create it first."
    return
}
$domains = Get-Content $domainListPath | Where-Object { $_ -notmatch '^\s*$' }

# 4. Streamlined loop processing (Aggregates directly into memory without += bottlenecks)
$results = foreach ($domain in $domains) {
    Write-Host "Querying domain: $domain" -ForegroundColor Cyan

    # --- Start Email Authentication Queries ---
    
    # Query SPF (Isolate missing record vs actual system crash errors)
    $spfRecord = "Not Found"
    try {
        $spfRecords = Resolve-DnsName -Name $domain -Type TXT -ErrorAction Stop
        if ($spfRecords) {
            $matchedSpf = $spfRecords | Where-Object { ($_.Strings -join "") -like "*v=spf1*" }
            if ($matchedSpf) { $spfRecord = ($matchedSpf.Strings -join " ") }
        }
    } catch {
        if ($_.Exception.Message -match "RecordNotFound|DNS_ERROR_RCODE_NAME_ERROR") {
            $spfRecord = "Not Found"
        } else {
            $spfRecord = "SPF Query Error"
        }
    }

    # Query DMARC
    $dmarcRecord = "Not Found"
    try {
        $dmarcRecords = Resolve-DnsName -Name "_dmarc.$domain" -Type TXT -ErrorAction Stop
        if ($dmarcRecords) { 
            $dmarcRecord = ($dmarcRecords.Strings -join " ") 
        }
    } catch {
        # Catch standard Windows NXDOMAIN string patterns ("does not exist", "9003", "RecordNotFound")
        if ($_.Exception.Message -match "does not exist|RecordNotFound|DNS_ERROR_RCODE_NAME_ERROR|9003") {
            $dmarcRecord = "Not Found"
        } else {
            $dmarcRecord = "DMARC Query Error"
        }
    }

    # Query DKIM
    $dkimRecord = "Not Found"
    foreach ($selector in $CommonSelectors) {
        try {
            $dkimRecords = Resolve-DnsName -Name "$selector._domainkey.$domain" -Type TXT -ErrorAction Stop
            if ($dkimRecords) {
                $dkimRecord = "[$selector]: " + ($dkimRecords.Strings -join " ")
                break
            }
        } catch {
            # Catch block remains empty
        }
    }

    # High-speed DNS Host / Nameserver Discovery
    $dnsHost = "Unknown"
    $primaryNS = $null
    try {
        $nsRecords = Resolve-DnsName -Name $domain -Type NS -ErrorAction Stop
        if ($nsRecords) {
            $dnsHost = ($nsRecords.NameHost | Sort-Object) -join "; "
            # Grab the first nameserver to query directly for the true Max TTL later
            $primaryNS = $nsRecords.NameHost[0]
        }
    } catch {
        $dnsHost = "NS Lookup Failed"
    }

    # --- End Email Authentication Queries ---

    try {
        # Fetch MX records from local cache/resolver (Provides local countdown)
        $mxRecords = Resolve-DnsName -Name $domain -Type MX -ErrorAction Stop
        
        foreach ($mx in $mxRecords) {
            # Resolve true TTL Max by querying the authoritative nameserver directly
            $ttlMax = "N/A"
            if ($primaryNS) {
                try {
                    $authMx = Resolve-DnsName -Name $domain -Type MX -Server $primaryNS -ErrorAction Stop
                    $matchedAuthMx = $authMx | Where-Object { $_.NameExchange -eq $mx.NameExchange }
                    if ($matchedAuthMx) {
                        $ttlMax = $matchedAuthMx[0].TTL
                    }
                } catch {
                    $ttlMax = "Lookup Error"
                }
            }

            # Resolve Only IPv4 Address via strict native 'A' records
            $ipAddresses = "None"
            try {
                $ipv4Records = Resolve-DnsName -Name $mx.NameExchange -Type A -ErrorAction Stop
                if ($ipv4Records) {
                    $ipAddresses = ($ipv4Records.IPAddress) -join "; "
                } else {
                    $ipAddresses = "No IPv4 Found"
                }
            } catch {
                $ipAddresses = "IP Resolve Failed"
            }

            # Output directly to the pipeline wrapper
            [PSCustomObject]@{
                "Domain Name" = $domain
                "Mail Exchange (MX) Record" = $mx.NameExchange
                "(MX) Pref" = $mx.Preference
                "Time To Live (TTL) Max" = $ttlMax
                "Time To Live (TTL) Left" = $mx.TTL
                "IP Address(es)" = $ipAddresses
                "DNS Registrar Host(s)" = $dnsHost
                "Email Auth (SPF) Record" = $spfRecord
                "Email Auth (DKIM) Record" = $dkimRecord
                "Email Auth (DMARC) Record" = $dmarcRecord
            }
        }
    } catch {
        Write-Host "Failed to resolve MX records for $domain" -ForegroundColor Red
        [PSCustomObject]@{
            "Domain Name" = $domain
            "Mail Exchange (MX) Record" = "Failed"
            "(MX) Pref" = "N/A"
            "Time To Live (TTL) Max" = "N/A"
            "Time To Live (TTL) Left" = "N/A"
            "IP Address(es)" = "N/A"
            "DNS Registrar Host(s)" = $dnsHost
            "Email Auth (SPF) Record" = $spfRecord
            "Email Auth (DKIM) Record" = $dkimRecord
            "Email Auth (DMARC) Record" = $dmarcRecord
        }
    }
}

# 5. Display and export results to CSV file
Write-Host "`nResults Table:" -ForegroundColor Blue
$results | Format-Table -Wrap

Write-Host "`nResults List:" -ForegroundColor Blue
$results | Format-List

$results | Export-Csv -Path $outputCsvPath -NoTypeInformation
Write-Host "Done! `nReport exported to $outputCsvPath" -ForegroundColor Green