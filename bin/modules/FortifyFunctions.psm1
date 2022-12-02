
function Test-Environment {
    $SCALocalInstall = $True
    $ScanCentralClient = $True

    Write-Host "Validating Fortify Installation..." -NoNewline

	# Check Source Analyzer is on the path
    if ((Get-Command "sourceanalyzer.exe" -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Error "Unable to find sourceanalyzer.exe in your PATH - local analysis and scan not available"
        $SCALocalInstall = $False
    }

    # Check FPR Utility is on the path
    if ((Get-Command "FPRUtility.bat" -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Error "Unable to find FPRUtility.bat in your PATH - issue summaries not available"
        $SCALocalInstall = $False
    }

    # Check Report Generator is on the path
    if ((Get-Command "ReportGenerator.bat" -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Error "Unable to find ReportGenerator.bat in your PATH - report generation not available"
        $SCALocalInstall = $False
    }

    # Check Fortify Client is installed
    if ((Get-Command "fortifyclient.bat" -ErrorAction SilentlyContinue) -eq $null)
    {
        Write-Error "fortifyclient.bat is not in your PATH - upload to SSC not available"
        $SCALocalInstall = $False
    }

    # Check ScanCentral Client is installed
    if ((Get-Command "scancentral.bat" -ErrorAction SilentlyContinue) -eq $null)
    {
        if ($SCALocalInstall -eq $False) {
            Write-Host
            throw "scancentral.bat is not in your PATH - cannot run local or remote scan, exiting ..."
        }
        $ScanCentralClient = $False
    }

    Write-Host "OK."
}
