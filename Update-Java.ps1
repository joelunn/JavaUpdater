if($env:Processor_Architecture -eq “AMD64”){
Write "Installing 64bit..."
start-process jre-8u123-windows-x64.exe /s -Wait
} else {
Write "Installing 32bit..."
start-process jre-8u123-windows-i586.exe /s -Wait
}
Start-Sleep -s 120

# IMPORTANT NOTE: If you would like Java versions 6 and below to remain, please edit the next line and replace $true with $False
$UninstallJava6andBelow = $true

#Declare version arrays
$32bitJava = @()
$64bitJava = @()
$32bitVersions = @()
$64bitVersions = @()
Write "Enumerating installed Java versions"
#Perform WMI query to find installed Java Updates
if ($UninstallJava6andBelow) {
    $32bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java(\(TM\))*\s\d+(\sUpdate\s\d+)*$"
    }
    #Also find Java version 5, but handled slightly different as CPU bit is only distinguishable by the GUID
    $32bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        ($_.Name -match "(?i)J2SE\sRuntime\sEnvironment\s\d[.]\d(\sUpdate\s\d+)*$") -and ($_.IdentifyingNumber -match "^\{32")
    }
} else {
    $32bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java((\(TM\) 7)|(\s\d+))(\sUpdate\s\d+)*$"
    }
    $32bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java((\(TM\) 8)|(\s\d+))(\sUpdate\s\d+)*$"
    }  
}

#Perform WMI query to find installed Java Updates (64-bit)
if ($UninstallJava6andBelow) {
    $64bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java(\(TM\))*\s\d+(\sUpdate\s\d+)*\s[(]64-bit[)]$" 
    }
    #Also find Java version 5, but handled slightly different as CPU bit is only distinguishable by the GUID
    $64bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        ($_.Name -match "(?i)J2SE\sRuntime\sEnvironment\s\d[.]\d(\sUpdate\s\d+)*$") -and ($_.IdentifyingNumber -match "^\{64")
    }
} else {
    $64bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java((\(TM\) 7)|(\s\d+))(\sUpdate\s\d+)*\s[(]64-bit[)]$"
    }
    $64bitJava += Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -match "(?i)Java((\(TM\) 8)|(\s\d+))(\sUpdate\s\d+)*\s[(]64-bit[)]$"  
    }
}
Write "Enumeration complete"
#Enumerate and populate array of versions
Foreach ($app in $32bitJava) {
    if ($app -ne $null) { $32bitVersions += $app.Version }
}

#Enumerate and populate array of versions
Foreach ($app in $64bitJava) {
    if ($app -ne $null) { $64bitVersions += $app.Version }
}

#Create an array that is sorted correctly by the actual Version (as a System.Version object) rather than by value.
$sorted32bitVersions = $32bitVersions | %{ New-Object System.Version ($_) } | sort
$sorted64bitVersions = $64bitVersions | %{ New-Object System.Version ($_) } | sort
#If a single result is returned, convert the result into a single value array so we don't run in to trouble calling .GetUpperBound later
if($sorted32bitVersions -isnot [system.array]) { $sorted32bitVersions = @($sorted32bitVersions)}
if($sorted64bitVersions -isnot [system.array]) { $sorted64bitVersions = @($sorted64bitVersions)}
#Grab the value of the newest version from the array, first converting 
$newest32bitVersion = $sorted32bitVersions[$sorted32bitVersions.GetUpperBound(0)]
$newest64bitVersion = $sorted64bitVersions[$sorted64bitVersions.GetUpperBound(0)]

Write "Most upto date Java version found (32bit): " $newest32bitVersion
Write "Most upto date Java version found (64bit): " $newest64bitVersion

Write "Uninstalling bad versions."
Foreach ($app in $32bitJava) {
    if ($app -ne $null){
        if ($env:Processor_Architecture -eq “AMD64”) {
        #When in a 64bit OS remove all 32bit versions
        $appGUID = $app.Properties["IdentifyingNumber"].Value.ToString()
           Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /norestart /x $($appGUID)" -Wait -Passthru
           Write "64bit environment detected, uninstalling 32bit versions: " $app
        } else {
        #Remove all versions of Java, where the version does not match the newest version.
        if (($app.Version -ne $newest32bitVersion) -and ($newest32bitVersion -ne $null)) {
           $appGUID = $app.Properties["IdentifyingNumber"].Value.ToString()
           Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /norestart /x $($appGUID)" -Wait -Passthru
           write "Uninstalling 32-bit version: " $app
        }
        }
    }
}

Foreach ($app in $64bitJava) {
    if ($app -ne $null)
    {
        #Remove all versions of Java, where the version does not match the newest version.
        if (($app.Version -ne $newest64bitVersion) -and ($newest64bitVersion -ne $null)) {
        $appGUID = $app.Properties["IdentifyingNumber"].Value.ToString()
           Start-Process -FilePath "msiexec.exe" -ArgumentList "/qn /norestart /x $($appGUID)" -Wait -Passthru
           write "Uninstalling 64-bit version: " $app
        }
    }
}
Write "Done."
