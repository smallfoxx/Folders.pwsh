
enum CommandTypes {
    If
    While
    Declare
    Let
    Print
    Input
    PushD
    PopD
    Save
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

$Variables = @{}

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
        [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][System.IO.DirectoryInfo]$Folder=(Get-Item "."),
        [parameter(ValueFromPipelineByPropertyName=$true)]$BaseFolder=$Folder
    )

    Process {
        $Folder = $Folder | ConvertTo-FoldersCommand
        $BaseFolder = $BaseFolder | ConvertTo-FoldersCommand
        write-Debug $Folder.SubFolders[0].CommandType
        switch ($Folder.SubFolders[0].CommandType) {
            'If' { if (Get-FoldersExpression $Folder.SubFolders[1]) {
                    Start-FoldersCommand -Folder (Get-FoldersExpression $Folder.SubFolders[2]) -BaseFolder $BaseFolder
                } }
            'While' { While (Get-FoldersExpression $Folder.SubFolders[1]) {
                    Start-FoldersCommand -Folder (Get-FoldersExpression $Folder.SubFolders[2]) -BaseFolder $BaseFolder
                } }
            'Declare' { Set-FoldersVariable $Folder.SubFolders[2] -Value $null  }
            'Let' { Set-FoldersVariable $Folder.SubFolders[1] -Value (Get-FoldersExpression $Folder.SubFolders[2]) }
            'Print' { Write-Output (Get-FoldersExpression $Folder.SubFolders[1]) }
            'Input' { Set-FoldersVariable $Folder.SubFolders[1] -Value (Read-Host -Prompt "Enter value:") }
            'PushD' { 
                Push-Location -StackName $PID -Path $BaseFolder.SubFolders[(Get-FoldersExpression $Folder.SubFolders[1])] 
                $BaseFolder = Get-Item $pwd | ConvertTo-FolderCommand
            }
            'PopD' {
                Pop-Location -StackName $PID
                $BaseFolder = Get-Item $pwd | ConvertTo-FolderCommand
            }
            'Save' { Set-FoldersValue $Folder.SubFolders[1] }
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
        Write-Debug $FOlder.SubFolders[0].ExpressionType
        switch ($Folder.SubFolders[0].ExpressionType) {
            'Variable' { Get-FoldersVariable $Folders.SubFolder[1] }
            'Add' { return (Get-FoldersExpression $Folder.SubFolders[1]) + (Get-FoldersExpression $Folder.SubFolders[2]) }
            'Subtract' { return (Get-FoldersExpression $Folder.SubFolders[1]) - (Get-FoldersExpression $Folder.SubFolders[2]) }
            'Multiply' { return (Get-FoldersExpression $Folder.SubFolders[1]) * (Get-FoldersExpression $Folder.SubFolders[2]) }
            'Divide' { return (Get-FoldersExpression $Folder.SubFolders[1]) / (Get-FoldersExpression $Folder.SubFolders[2]) }
            'Literal' {
                return Get-FoldersValue -Folder $Folder.SubFolders[2] -ByType $Folder.SubFolders[1].TypesType
            }
            'Equal' { return (Get-FoldersExpression $Folder.SubFolders[1]) -eq (Get-FoldersExpression $Folder.SubFolders[2]) }
            'Greater' { return (Get-FoldersExpression $Folder.SubFolders[1]) -gt (Get-FoldersExpression $Folder.SubFolders[2]) }
            'Less' { return (Get-FoldersExpression $Folder.SubFolders[1]) -lt (Get-FoldersExpression $Folder.SubFolders[2]) }
        }
    }

}

Function Set-FoldersValue() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder,
        [string]$ByType
    )

    Process {
        $Folder = $Folder | ConvertTo-FoldersCommand -Recurse
        $binBytes = $Folder.SubFolders | Get-FoldersByteValue
        switch ($ByType) {
            int {
                $hex = "{0:x}" -f ($Variables.("Var{0}" -f $Folder.SubFolders.Count))
                Set-FoldersByteValue $hex
                $bytes = $binBytes | ForEach-Object { [int]("0x$_") }
                [convert]::toInt32($bytes,0)  
            }
            float {
                $bytes = $binBytes | ForEach-Object { [int]("0x$_") }
                [convert]::ToSingle($bytes,0) 
            }
            string {
                ($binBytes | ForEach-Object { [char][convert]::toInt16($_,16) }) -join ''
            }
            char {
                $binBytes | ForEach-Object { [char][convert]::toInt16($_,16) }
            }
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
            int {
                $bytes = $binBytes | ForEach-Object { [int]("0x$_") }
                [convert]::toInt32($bytes,0)  
            }
            float {
                $bytes = $binBytes | ForEach-Object { [int]("0x$_") }
                [convert]::ToSingle($bytes,0) 
            }
            string {
                ($binBytes | ForEach-Object { [char][convert]::toInt16($_,16) }) -join ''
            }
            char {
                $binBytes | ForEach-Object { [char][convert]::toInt16($_,16) }
            }
        }
    }
}

Function ConvertFrom-HexToBytes() {
    param([string]$Hexadecimal)

    $Hexadecimal -split "(\w{2})" | Where-Object { $_ } | ForEach-Object { [convert]::ToByte($_, 16) }

}

Function Set-FoldersByteValue() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder,
        [parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName="ViaHexadecimal")][string]$Hexadecimal,
        [parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName="ViaByteArray")][byte[]]$Bytes
    )

    Process {
        switch ($PSCmdlet.ParameterSetName) {
            "ViaHexadecimal" {
                Set-FoldersByteValue -Folder $Folder -Bytes ($Hexadecimal | ConvertFrom-HexToBytes)
            }
            Default {
                $Folder = $Folder | ConvertTo-FoldersCommand -Recurse
            }
        }
        $HighBits = $Folder.SubFolders[0] | Get-FoldersBinValue
        $LowBits = $Folder.SubFolders[1] | Get-FoldersBinValue
        $Bits = "{0}{1}" -f $HighBits,$LowBits
        $intVal = [convert]::ToInt32($Bits,2)
        return "{0:X}" -f $intVal
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


Function Set-FoldersVariable() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder,
        $Value
    )

    Process {
        $Folder = $Folder | ConvertTo-FoldersCommand -Recurse
        $Variables.("Var{0}" -f $Folder.SubFolders.Count) = $Value
    }
}

Function Get-FoldersVariable() {
    [CmdletBinding()]
    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)][System.IO.DirectoryInfo]$Folder
    )

    Process {
        $Folder = $Folder | ConvertTo-FoldersCommand -Recurse
        return $Variables.("Var{0}" -f $Folder.SubFolders.Count)
    }
}
