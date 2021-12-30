## SBup Ver 0.1
# Purpose: Used to backup Screenshots and place them in unqiue tars, see design doc for more information
# sbup.ps1 -hashfile HASHFILE -locationfile LOCATION 

#Note: This code is pretty bad since it is a lazy mutation of bup.ps1, thus I will try to explain more with comments

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
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [hashtable][ref] $L_hashGroups,
    [Parameter()]
    [string] $L_hash


  )

  $L_Error = 0
  $L_chain = ""
  
  try {


    # Pull Out Location Groups
    ForEach ($item in $(Get-Content $L_location -ErrorAction Stop)) {

      # 1. Check for "[" and "]"
      # 2. Regex to get name if this fails then stop
      # 3. Add Name to Hashtable with locations
      
     
      # if you find a name, make it current name
      # This is pretty bad below, "nameValues" relies on powershell's garbage collection to make new ArrayLists
      # Since the "Clear" method does not destroy the ArrayList thus it is linked for each name
      if ($item[0] -eq "[" -and $item[-1] -eq "]") {

        #Check for null, this happens if "namekey" doesn't exist yet
        if ($nameKey) {

          $null = $L_hashGroups.Add($nameKey, $nameValues)

        }
        $nameKey = $item.substring(1,$item.Length - 2)
        #Create a new array for "nameValues", this will keep the old on around in the hashtable, but the new one will not be linked to it thus the data you write will be preserved
        $nameValues = [System.Collections.ArrayList]@()

      }
      else {
        
        #Have this check here just in case you start your locations file with a name stanza to prevent a crash
        if ($nameKey) {

          $null = $nameValues.Add($item)

        }

      }

    }

    # Write out Last Name and values
    $null = $L_hashGroups.Add($nameKey, $nameValues)

    
    if ($L_hash) {

      $L_hashData = Import-Csv -Path $L_hash -ErrorAction Stop
      $L_chain = $L_hashData[0].Path

    }

  }
  catch {

    $L_Error = 1000

  }

    
    return $L_hashData, $L_chain, $L_Error
}


#This will Grab all the hashes from the backup files and then compare with the hashfile
#if grabed hash is in the hashfile, file will be overlooked for backup
function GetHashes {

  [CmdletBinding()]
  param (

    # Pass by reference to make things faster
    [Parameter(Mandatory)]
    [hashtable][ref] $L_location,
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.Collections.ArrayList][ref] $L_newHash,
    [Parameter()]
    [System.Collections.ArrayList][ref] $L_hash

  )

  $L_Error = 0

  try {

    #Pull out locations based off of hash key then push into a custom object that will have hash, location/path, and set
    foreach ($j in $L_location.keys) {
      foreach($i in $L_location[$j]) {
        foreach ( $file in $(Get-ChildItem -Recurse -File -Path $i -ErrorAction Stop | Select-Object -ExpandProperty FullName)) { 

          $object_TEMP = Get-FileHash $file -ErrorAction Stop | Select-Object Hash,Path
          $objects = [PSCustomObject]@{Hash = $object_TEMP.Hash; Path = $object_TEMP.Path; Set = $j}

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
    [string] $L_date,
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.Collections.ArrayList][ref] $L_newHash

  )

  $L_Error = 0

  try {
    #Build Include File
    #The Include file will use some knowledge:
    #1. Paths are always full paths, thus for windows it will start with "C:" and linux will always start with "/"
    #2. For tar to work right on Windows paths must be in unix format (thus change "\" to "/")

    $setName = $null

  
    ForEach ($obj in $L_newHash) {
      
      # Set your first Name
      if (!$setName) {

        $setName = $obj.Set

      }

      # When You Transfer Sets, tar and then remove temp file, this will
      # Create multiple Tars for your sets
      if ($setName -ne $obj.Set){

        tar -czvf "./$setName`_$L_date`.tar.gz" --files-from="./$setName`_$L_date`.tmp"
        Remove-Item "./$setName`_$L_date`.tmp" -ErrorAction Stop
        $setName = $obj.Set

      }
      #Check to see if we are working with Windows Path, fix and write to exclude file
      #Else write to tar Include file
      if ($obj.Path -Contains "\") {

        $TEMP = $obj.Path.Replace("\", "/")
        $TEMP | Add-Content "./$setName`_$L_date`.tmp" -ErrorAction Stop

      }
      else {

        $obj.Path | Add-Content "./$setName`_$L_date`.tmp" -ErrorAction Stop

      }

    }

    #If you have nothing in $L_newHash, don't write tar or it will crash
    if ($L_newHash) {

      # When Everything is done, we still have our last set in the list to tar, so do it
      tar -czvf "./$setName`_$L_date`.tar.gz" --files-from="./$setName`_$L_date`.tmp"
      Remove-Item "./$setName`_$L_date`.tmp" -ErrorAction Stop

    }

  }
  catch {

    $L_Error = 3000

  }

  return $L_Error

}


#This will be responsible for writing your new hash file with updated hashes
#This will be in .csv format
#They Only difference I have fro sbup is that I added an new CSV column (Set) and change the Name of the hash csv file
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
      "Hash,Path,Version,Set" | Add-Content "./TOP_$L_fileName`.csv" -ErrorAction Stop

      #Write Old Hash Values
      Foreach ($obj in $L_hash) {

        $obj.Hash + "," + $obj.Path + "," + $obj.Version + "," + $obj.Set | Add-Content "./TOP_$L_fileName`.csv" -ErrorAction Stop

      }

      #Write New Hash Values
      Foreach ($obj in $L_newHash) {

        $obj.Hash + "," + $obj.Path + "," + $fileName + "," + $obj.Set | Add-Content "./TOP_$L_fileName`.csv" -ErrorAction Stop

      }

    }
    else {

      "Hash,Path,Version,Set" | Add-Content "./TOP_$L_fileName`.csv" -ErrorAction Stop
      "$L_Hostname,$fileName,," | Add-Content "./TOP_$L_fileName`.csv" -ErrorAction Stop

      Foreach ($obj in $L_newHash) {

        $obj.Hash + "," + $obj.Path + "," + $fileName + "," + $obj.Set | Add-Content "./TOP_$L_fileName`.csv" -ErrorAction Stop

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
#$locations = [System.Collections.ArrayList]@()
$hashGroups = [hashtable]@{}
$newHashes = [System.Collections.ArrayList]@()

$hostName = $(hostname)
$date = $(Get-Date -Format "yyyy-MM-dd_HHmm")
$fileName = "$hostName`_$date"
$chain = ""

$functionError = 0

## Main

$hashes, $chain, $functionError = OpenFile -L_hashGroups ([ref]$hashGroups) -L_hash $hashFile -L_location $locationFile
WriteError -L_Error $functionError

$functionError = GetHashes -L_location ([ref] $hashGroups) -L_hash ([ref] $hashes) -L_newHash ([ref]$newHashes) 
WriteError -L_Error $functionError

$functionError = Backup -L_date $date -L_newHash ([ref]$newHashes)
WriteError -L_Error $functionError

$functionError = WriteHashFile -L_fileName $fileName -L_hostname $hostname -L_hash ([ref]$hashes) -L_newHash ([ref]$newHashes) -L_chain $chain
WriteError -L_Error $functionError





