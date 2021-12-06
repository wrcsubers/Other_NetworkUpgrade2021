#############################################################################################
#
# PiHole Temperature Monitor
#
# Written 2021 by Cameron Woods
#
# https://github.com/wrcsubers
#
#############################################################################################

# About:
# This script pulls the temperature data directly from the PiHole Admin/Login page and then
# outputs that data into a CSV file which is timestamped.  The number and frequency of readings
# can be modified by changing a couple of variables.  I'm sure there is a better way to do this,
# but this worked quite well and was easy/quick to write.

# Notes:
# - To kill logging use: $IntervalTimer.dispose()
# - Tested on:
#		PiHole v5.6
#		FTL v5.11
#		Web Interface v5.8
# - PiHole should be displaying temps in C°, conversion to F° is handled by the script



# Set Variables
####################################################################################################

# Interval to Check Temperature (in seconds)
$CheckInterval = 15

# Samples To Take (default is 2880 which is 24 hours @ 30 second Intervals)
[int]$NumberOfSamplesToTake = 2880
# Leave Samples Taken at 0
[int]$NumberOfSamplesTaken = 0

# Request URI - should just be the PiHole Homepage - no need to login by default: http://PiHolesIPAddress/admin/index.php
$RequestURI = 'http://192.168.1.2/'

# CSV Output File Name
$CSVOutputFileName = "PiTemp_" + (Get-Date -Format "MMdd_HHMMss") + '.csv'



# Take-Sample Function
####################################################################################################
function Take-Sample {
    # Increment Samples Taken Counter
    $Global:NumberOfSamplesTaken++
    
    #Display Data
    Clear-Host
    Write-Host " Sampling Every $($CheckInterval) Seconds"
    Write-Host " Samples Left: $($Global:NumberOfSamplesToTake - $Global:NumberOfSamplesTaken)"

    # Request PiHole Webpage
    $Request = Invoke-WebRequest -Uri $Global:RequestURI

    # Grab Temperature
    $Temp = $Request.Content.Split([System.Environment]::NewLine)[151].Split('><')[16]

    # Convert to Float
    $TempC = [double]::Parse($Temp)
    $TempC = [math]::Round($TempC, 1)

    # Convert from C to F
    $TempF = [math]::Round(($TempC  * (9/5)) + 32, 1)

    # Get Time
    $Time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    # Create CSV Object to store data in
    $CSVData = New-Object -TypeName PSObject
    $CSVData | Add-Member NoteProperty Date $Time
    $CSVData | Add-Member NoteProperty TempC $TempC
    $CSVData | Add-Member NoteProperty TempF $TempF

    # Export the CSV
    Export-Csv -InputObject $CSVData -Path $Global:CSVOutputFileName -Append -NoTypeInformation
}




# Check-Samples Function
####################################################################################################
function Check-Samples {
    if ($Global:NumberOfSamplesTaken -lt $Global:NumberOfSamplesToTake){
        Take-Sample
    } else {
        $Global:IntervalTimer.Dispose()
        Write-Host "`n`n Sampling Complete!"
        Write-Host " Output File is: $($Global:CSVOutputFileName)"
        Exit
    }
}



# Create Timer to Run at interval
####################################################################################################
$IntervalTimer = New-Object System.Timers.Timer
$IntervalTimer.Interval = ($CheckInterval * 1000)
$IntervalTimer.AutoReset = $true
$IntervalTimer.Enabled = $true
Register-ObjectEvent -InputObject $IntervalTimer -EventName Elapsed -Action {Check-Samples}

#Run Take-Sample Function Once at startup
Take-Sample