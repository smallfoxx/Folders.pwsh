
enum CommandTypes {
    If
    While
    Declare
    Let
    Print
    Input    
}

enum ExpressionsType {
    Variable
    Add
    Subtract
    Multiply
    Divide
    Literal
    Equal
    Greater
    Less
}

enum TypesTypes {
    int
    float
    string
    char
}

Function ConvertTo-FoldersCommand() {
    [CmdletBinding(DefaultParameterSetName="Basic")]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder,
        [parameter(ParameterSetName="Recurse")][switch]$Recurse,
        [parameter(ParameterSetName="Basic")][switch]$NoRecurse
    )
    
    Process {
        If ($Recurse) {
            $Folder | Add-Member -Force ScriptProperty SubFolders { $this | Get-ChildItem -Directory | Sort-Object Name | ConvertTo-FoldersCommand -Recurse } 
        } elseIf ($NoRecurse) {
            $Folder | Add-Member -Force ScriptProperty SubFolders { $this | Get-ChildItem -Directory | Sort-Object Name } 
        } else {
            $Folder | Add-Member -Force ScriptProperty SubFolders { $this | Get-ChildItem -Directory | Sort-Object Name | ConvertTo-FoldersCommand -NoRecurse } 
        }
        $Folder | Add-Member -Force ScriptProperty CommandType { [CommandTypes]($this.SubFolders.Count-1) }
        $Folder | Add-Member -Force ScriptProperty ExpressionType { [ExpressionsType]($this.SubFolders.Count-1) }
        $Folder | Add-Member -Force ScriptProperty TypesType { [TypesTypes]($this.SubFolders.Count-1) }

        return $Folder
    }
}

Function Start-FoldersCommand() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true)][System.IO.DirectoryInfo]$Folder=(Get-Item ".")
    )

    Process {
        $Folder = $Folder | ConvertTo-FoldersCommand 
        write-host $Folder.SubFolders[0].CommandType
        switch ($Folder.SubFolders[0].CommandType) {
            'If' { }
            'While' { }
            'Declare' { }
            'Let' { }
            'Print' { Write-Output (Get-FoldersExpression $Folder.SubFolders[1]) }
            'Input' { }    
        }
    }
    End {
        
    }
}

Function Get-FoldersExpression() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder
    )

    Process {
        $Folder = $Folder | ConvertTo-FoldersCommand 
        Write-Host $FOlder.SubFolders[0].ExpressionType
        switch ($Folder.SubFolders[0].ExpressionType) {
            'Variable' { }
            'Add' { }
            'Subtract' { }
            'Multiply' { }
            'Divide' { }
            'Literal' {
                $FolderValue = Get-FoldersValue -Folder $Folder.SubFolders[2] -ByType $Folder.SubFolders[1].TypesType
                return $FolderValue
            }
            'Equal' { }
            'Greater' { }
            'Less' { }
        }
    }

}

Function Get-FoldersValue() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder,
        [string]$ByType
    )

    Process {
        $Folder = $Folder | ConvertTo-FoldersCommand -Recurse
        $binBytes = $Folder.SubFolders | Get-FoldersByteValue
        switch ($ByType) {
            string {
                ($binBytes | ForEach-Object { [char][convert]::toInt16($_,16) }) -join ''
            }
            char {
                $binBytes | ForEach-Object { [char][convert]::toInt16($_,16) }
            }
        }
    }
}

Function Get-FoldersByteValue() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder
    )

    Process {
        $HighBits = $Folder.SubFolders[0] | Get-FoldersBinValue
        $LowBits = $Folder.SubFolders[1] | Get-FoldersBinValue
        $Bits = "{0}{1}" -f $HighBits,$LowBits
        $intVal = [convert]::ToInt32($Bits,2)
        return "{0:X}" -f $intVal
    }
}

Function Get-FoldersBinValue() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder
    )

    Process {
        ($Folder.SubFolders | ForEach-Object { $_.SubFolders.Count } ) -join ''
    }
}