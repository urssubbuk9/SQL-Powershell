<#
    .SYNOPSIS
        Connects to a given list of servers and retrieve user reboot, windows updates and SQL restart events from the event log.
    .DESCRIPTION
        Connects to a given list of servers and retrieve user reboot, windows updates and SQL restart events from the event log.
    .PARAMETERS
        $serverList -> List of servers to look at
        $includeSQLevents -> If the process will look at SQL restart events ($true or $false)
        $hours -> Number of hours we will look back in the logs, 24 if not specified
    .EXAMPLE
        Get-RestartDates "SQL1"
        Get-RestartDates "SQL1" $true 12
        Get-RestartDates "SQL1" | ft # to display format-list
        Get-RestartDates "SQL1", "SQL2"
 #>

Clear-Host;
$serverList = $null; # , "SQL02", "SQL03";
$includeSQLevents = $false; #$true; # 
$hours =12; 

if ($null -eq $serverList){
    $serverList = $env:COMPUTERNAME;
}

if ($hours -eq $null){ $hours = 24 ; }

$startDate = (get-date) - (New-TimeSpan -Hours $hours);

if ($includeSQLevents -eq $true){
    Write-Host "SQL Server Events are selected, please note that might take a while to complete" -ForegroundColor green;
}

$events=@() 

foreach ($s in $serverList){
   
    Write-Host "Looking for events that match the filters on server $($s)" -ForegroundColor green;

    $IsSrvValid = Test-Connection -ComputerName $s -Quiet
    
    if ($IsSrvValid -eq $true){
        $out = Get-WinEvent -ComputerName $s -ea SilentlyContinue `
                    -FilterHashtable @{ProviderName= "User32";LogName = "system"; StartTime = $startDate} |`
                    Select-Object -Property @{l="Computer";e={$s}}, TimeCreated, ID, LevelDisplayName, Message;

        $events += $out;

        $out = Get-WinEvent -ComputerName $s -ea SilentlyContinue `
                    -FilterHashtable @{ProviderName= "Microsoft-Windows-WindowsUpdateClient";LogName = "system"; StartTime = $startDate} | `
                    Where-Object { $_.Id -in 43, 19, 21 } |`
                    Select-Object -Property @{l="Computer";e={$s}}, TimeCreated, ID, LevelDisplayName, Message;

        $events += $out;

        if ($includeSQLevents -eq $true){
            $SQLprovider = (get-winevent -ComputerName $s -listlog Application).providernames | Where-Object { $_ -match "MSSQL"};
            $out = Get-WinEvent -ComputerName $s -ea SilentlyContinue `
                        -FilterHashtable @{ProviderName= $SQLprovider;LogName = "application"; StartTime = $startDate} | `
                        Where-Object { $_.Id -in 17069 } |`
                        Select-Object -Property @{l="Computer";e={$s}}, TimeCreated, ID, LevelDisplayName, Message;
            $events += $out;
        }

        if ($events.count -eq 0){
            Write-Host "There are no events that match the filters" -ForegroundColor green;
        }
        else{
            Write-Output $events | Sort-Object -Property "TimeCreated" | Format-Table -autosize;
        }

    }
    else{
        Write-Host "The server $($s) is not accessible or does not exist" -ForegroundColor Red
    }
}
