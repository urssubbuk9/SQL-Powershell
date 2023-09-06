function Test-FileLock {
  param (
    [parameter(Mandatory=$true)][string]$Path
  )

  $oFile = New-Object System.IO.FileInfo $Path

  if ((Test-Path -Path $Path) -eq $false) {
    return $false
  }

  try {
    $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)

    if ($oStream) {
      $oStream.Close()
    }
    $false
  } catch {
    # file is locked by a process.
    return $true
  }
}

$locations = "E:\", "G:\", "H:\", "L:\"
$output = $null

ForEach ($l in $locations){

  $output += get-childitem $l -Recurse -Include "*.ldf","*.mdf","*.ndf" | Select-Object FullName, @{l="Size";e={($_.length)/1024/1024}} ,  @{l="IsLocked";e={(Test-FileLock($_.FullName))}} | Where-Object IsLocked -eq $false
}

$output | Format-Table -AutoSize  # | export-csv -Path "c:\utilities\db_files_not_in_use.csv"
