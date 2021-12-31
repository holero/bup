## Bup Ver 0.1
# Purpose: Used to backup files, see design doc for more information
# bups.ps1 -hashfile HASHFILE -locationfile LOCATION 

[CmdletBinding()]
param (

  #If no hash file, then assume full backup
  [Parameter()]
  [string] $hashFile, 

  [Parameter(Mandatory)]
  [string] $locationFile 


)


## FUNCTIONS

# Checks the Locations and hash files and then pulls them to variables
# note the location file is a .txt and the hash file is a .csv
function OpenFile {

  [CmdletBinding()]
  param (

    [Parameter(Mandatory)]
    [string] $L_location,
    [Parameter()]
    [string] $L_hash


  )

  $L_Error = 0
  $L_chain = ""
  
  try {

    $L_locationData = Get-Content $L_location -ErrorAction Stop

    if ($L_hash) {

      $L_hashData = Import-Csv -Path $L_hash -ErrorAction Stop
      $L_chain = $L_hashData[0].Path

    }

  }
  catch {

    $L_Error = 1000

  }

    
    return $L_locationData, $L_hashData, $L_chain, $L_Error
}


#This will Grab all the hashes from the backup files and then compare with the hashfile
#if grabed hash is in the hashfile, file will be overlooked for backup
function GetHashes {

  [CmdletBinding()]
  param (

    # Pass by reference to make things faster
    [Parameter(Mandatory)]
    [System.Collections.ArrayList][ref] $L_location,
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.Collections.ArrayList][ref] $L_newHash,
    [Parameter()]
    [System.Collections.ArrayList][ref] $L_hash

  )

  $L_Error = 0

  try {
    foreach ($loc in $L_location) {

      foreach ( $file in $(Get-ChildItem -Recurse -File -Path $loc -ErrorAction Stop | Select-Object -ExpandProperty FullName)) { 

        $objects = Get-FileHash $file -ErrorAction Stop | Select-Object Hash,Path

        if ($L_hash) {

          #Magic Powershell: If you ref property name for whole array it will return and array for all values of the property, thus I can use a "Contains" statement for just that one!
          if (!$L_hash.Hash.Contains($objects.Hash)) {

            $null = $L_newHash.Add($objects)

          }

        }
        else {

          $null = $L_newHash.Add($objects)  
  
        }

      }

    }
  }
  catch {

    $L_Error = 2000

  }
  
  return $L_Error

}

#This will use tar to pull files and then make a backup. It will utilize tar's "files-from" feature to only backup "new" files (files with different hash)
#The tar name created will bein the form HOSTNAME_DATE.tar.gz
#tar --exclude-from=.\t.txt -cf test4.tar C:\Users\Tobi\Documents\TEMP\*
#tar -cf test.tar --files-from=.\n.txt
#Note: If you have two differnt drives on Windows with directories that have the same file structure to be backed up, then the directories will be merged, this is a Windows limitation
#since *nix based systems have no concept of drive letters 
function Backup {

  [CmdletBinding()]
  param (

    [Parameter(Mandatory)]
    [string] $L_fileName,
    [Parameter(Mandatory)]
    [System.Collections.ArrayList][ref] $L_newHash

  )

  $L_Error = 0

  try {
    #Build Include File
    #The Include file will use some knowledge:
    #1. Paths are always full paths, thus for windows it will start with "C:" and linux will always start with "/"
    #2. For tar to work right on Windows paths must be in unix format (thus change "\" to "/")

    ForEach ($obj in $L_newHash) {
      
      #Check to see if we are working with Windows Path, fix and write to exclude file
      #Else write to tar Include file
      if ($obj.Path -Contains "\") {

        $TEMP = $obj.Path.Replace("\", "/")
        $TEMP | Add-Content "./$L_fileName`.tmp" -ErrorAction Stop

      }
      else {

        $obj.Path | Add-Content "./$L_fileName`.tmp" -ErrorAction Stop

      }

    }

    # tar with include file
    tar -czvf "./$L_fileName`.tar.gz" --files-from="./$L_fileName`.tmp"

    #Cleanup, remove temp file
    Remove-Item "./$L_fileName`.tmp" -ErrorAction Stop

  }
  catch {

    $L_Error = 3000

  }

  return $L_Error

}


#This will be responsible for writing your new hash file with updated hashes
#This will be in .csv format
function WriteHashFile {

  [CmdletBinding()]
  param (

    [Parameter(Mandatory)]
    [string] $L_fileName,
    [Parameter(Mandatory)]
    [string] $L_hostname,
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.Collections.ArrayList][ref] $L_newHash,
    [Parameter()]
    [string] $L_chain,
    [Parameter()]
    [System.Collections.ArrayList][ref] $L_hash

  )

  $L_Error = 0

  try {
    if ($L_hash) {

      #Rebuild Header for hashtable file
      $L_hash[0].Hash = $L_hostname
      $L_hash[0].Path = $L_chain + "-->" +  $L_fileName
      
      #Build and Write Csv columns
      "Hash,Path,Version" | Add-Content "./$L_fileName`.csv" -ErrorAction Stop

      #Write Old Hash Values
      Foreach ($obj in $L_hash) {

        $obj.Hash + "," + $obj.Path + "," + $obj.Version | Add-Content "./$L_fileName`.csv" -ErrorAction Stop

      }

      #Write New Hash Values
      Foreach ($obj in $L_newHash) {

        $obj.Hash + "," + $obj.Path + "," + $fileName | Add-Content "./$L_fileName`.csv" -ErrorAction Stop

      }

    }
    else {

      "Hash,Path,Version" | Add-Content "./$L_fileName`.csv" -ErrorAction Stop
      "$L_Hostname,$fileName," | Add-Content "./$L_fileName`.csv" -ErrorAction Stop

      Foreach ($obj in $L_newHash) {

        $obj.Hash + "," + $obj.Path + "," + $fileName | Add-Content "./$L_fileName`.csv" -ErrorAction Stop

      }

    }

  }
  catch {

    $L_Error = 4000

  }

  return $L_Error


}


function WriteError {

  [CmdletBinding()]
  param (

    [Parameter(Mandatory)]
    [Int]$L_Error

  )

  if ($L_Error) {

    Write-Host "Error $L_Error" 
    exit
  
  }

}


## END FUNCTIONS 


#Variables

$hashes = [System.Collections.ArrayList]@()
$locations = [System.Collections.ArrayList]@()
$newHashes = [System.Collections.ArrayList]@()

$hostName = $(hostname)
$date = $(Get-Date -Format "yyyy-MM-dd_HHmm")
$fileName = "$hostName`_$date"
$chain = ""

$functionError = 0

## Main

$locations, $hashes, $chain, $functionError = OpenFile -L_location $locationFile -L_hash $hashFile
WriteError -L_Error $functionError

$functionError = GetHashes -L_location ([ref] $locations) -L_hash ([ref] $hashes) -L_newHash ([ref]$newHashes) 
WriteError -L_Error $functionError

$functionError = Backup -L_fileName $fileName -L_newHash ([ref]$newHashes)
WriteError -L_Error $functionError

$functionError = WriteHashFile -L_fileName $fileName -L_hostname $hostname -L_hash ([ref]$hashes) -L_newHash ([ref]$newHashes) -L_chain $chain
WriteError -L_Error $functionError





