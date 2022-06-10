#
# Example script to perform Fortify SCA static analysis
#

# Parameters
param (
    [Parameter(Mandatory=$false)]
    [switch]$QuickScan,
    [Parameter(Mandatory=$false)]
    [switch]$SkipPDF,
    [Parameter(Mandatory=$false)]
    [switch]$SkipSSC
)

# Import some supporting functions
Import-Module $PSScriptRoot\modules\FortifyFunctions.psm1

# Import local environment specific settings
$EnvSettings = $(ConvertFrom-StringData -StringData (Get-Content ".\.env" | Where-Object {-not ($_.StartsWith('#'))} | Out-String))
$AppName = $EnvSettings['SSC_APP_NAME']
$AppVersion = $EnvSettings['SSC_APP_VER_NAME']
$SSCUrl = $EnvSettings['SSC_URL']
$SSCAuthToken = $EnvSettings['SSC_AUTH_TOKEN'] # CIToken
$ScanSwitches = "-Dcom.fortify.sca.rules.enable_wi_correlation=true `
-Dcom.fortify.sca.Phase0HigherOrder.Languages=javascript,typescript `
-Dcom.fortify.sca.EnableDOMModeling=true -Dcom.fortify.sca.follow.imports=true `
-Dcom.fortify.sca.exclude.unimported.node.modules=true"
if ($QuickScan) {
    $PrecisionLevel = 1
} else {
    $PrecisionLevel = 3 # or 4 for full scan
}

# Test we have Fortify installed successfully
Test-Environment
if ([string]::IsNullOrEmpty($AppName)) { throw "Application Name has not been set" }

# Run the translation and scan

# Compile the application if not already built
$DependenciesFile = Join-Path -Path (Get-Location) -ChildPath build\classpath.txt
if (-not (Test-Path -PathType Leaf -Path $DependenciesFile)) {
    Write-Host Cleaning up workspace...
    & sourceanalyzer '-Dcom.fortify.sca.ProjectRoot=.fortify' -b "$AppName" -clean
    Write-Host Re-compiling application ...
    & .\gradlew.bat clean build writeClasspath
}
$ClassPath = Get-Content -Path $DependenciesFile

Write-Host Running translation...
& sourceanalyzer '-Dcom.fortify.sca.ProjectRoot=.fortify' $ScanSwitches -b "$AppName" `
    -jdk 1.8 -java-build-dir "build/classes" -cp $ClassPath -verbose `
    -exclude ".\src\main\resources\static\js\lib" -exclude ".\src\main\resources\static\css\lib"`
    "./src/**/*" "./build.gradle" "./azuredeploy.json" "./Dockerfile"

Write-Host Running scan...
& sourceanalyzer '-Dcom.fortify.sca.ProjectRoot=.fortify' $ScanSwitches -b "$AppName" `
   -cp $ClassPath  -java-build-dir "build/classes" -verbose `
    -build-project "$AppName" -build-version "$AppVersion" -build-label "SNAPSHOT" -scan -f "$($AppName).fpr"

# summarise issue count by analyzer
& fprutility -information -analyzerIssueCounts -project "$($AppName).fpr"   

if (-not $SkipPDF) {
    Write-Host Generating PDF report...
    & ReportGenerator '-Dcom.fortify.sca.ProjectRoot=.fortify' -user "Demo User" -format pdf -f "$($AppName).pdf" -source "$($AppName).fpr"
}

if (-not $SkipSSC) {
    Write-Host Uploading results to SSC...
    & fortifyclient uploadFPR -file "$($AppName).fpr" -url $SSCUrl -authtoken $SSCAuthToken -application $AppName -applicationVersion $AppVersion
}

Write-Host Done.
