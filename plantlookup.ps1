$HabitKeywords = 'distribution', 'habitat', 'origin', 'altitude', 'range'

$DescriptionKeywords = 'description', 'size', 'stem', 'spines', 'toxicity', 'poison',
    'flower', 'bloom', 'fruit', 'leaves', 'inflorescence'

$CultureKeywords = 'cultivation', 'propagation', 'care', 'gardening', 'irrigation',
    'soil', 'feeding', 'houseplant', 'potting', 'repotting', 'fertilising', 'fertilizing',
    'propagation', 'problems', 'use', 'display', 'harvest', 'availability', 'edges',
    'light', 'position'

<#
    .SYNOPSIS
    Routine for access Plants Rescue database
    .DESCRIPTION
    .
    .PARAMETER Name
    scientific/botanical (Genus epithet) name for query
    .PARAMETER json
    if specified, return information as Json instead of native object
    .EXAMPLE
    Get-PlantsRescueInfo 'capsicum annuum'
#>
function Get-PlantsRescueInfo {
    param(
        [string]$Name,
        [switch]$json
    )

    # convert spaces and strip garbage
    $Name = $Name.Trim() -replace " ","+" -replace "[^a-zA-Z+]",""

    $SearchWR = Invoke-WebRequest "http://www.plantsrescue.com/?s=$Name"
    if ($SearchWR.ParsedHtml.getElementsByClassName("post")[0].InnerHtml -match "href=`"(http://www.plantsrescue.com/[^`"]*)") {
        $Url = $Matches[1]
        $PlantPageWR = Invoke-WebRequest ($Url)
    } else {
        throw "couldn't find plant. check spelling and synonyms [http://www.plantsrescue.com/?s=$Name]"
    }
    
    # Extract edit date from wordpress photo upload date
    if (($PlantPageWR.Images -match "\.jpg")[0].src -match "wp-content/uploads/(\d\d\d\d)/(\d\d)/") {
        [string]$ArticleProbableDate = (Get-Culture).DateTimeFormat.GetAbbreviatedMonthName($Matches[2]) + " " + $Matches[1]
    } else { $ArticleProbableDate = "" }
    $PlantData = New-Object psobject
    $PlantData | Add-Member -Type NoteProperty -Name "Name" -Value $PlantPageWR.ParsedHtml.getElementsByTagName("h2")[0].InnerText
 
    # Second div.content is article (first is searchbox fsr)
    $ParsedPlantData = Parse-Keywords $PlantPageWR.ParsedHtml.getElementsByClassName("content")[1].InnerHtml -SplittingMethod ${function:Split-Strong}

    $PlantData | Add-Member -Type NoteProperty -Name "Habit" -Value $ParsedPlantData.Habit
    $PlantData | Add-Member -Type NoteProperty -Name "Description" -Value $ParsedPlantData.Description
    $PlantData | Add-Member -Type NoteProperty -Name "Culture" -Value $ParsedPlantData.Culture

    $PlantData | Add-Member -Type NoteProperty -Name "Source" -Value "Plants Rescue - Plants & Flowers"
    $PlantData | Add-Member -Type NoteProperty -Name "Cite" -Value "`"$($PlantData.Name)`" www.plantsrescue.com $ArticleProbableDate. $(Get-Date -f "dd MMM yyyy"). <$Url>"

    if ($json) {
        return $PlantData | ConvertTo-json
    } else {
        return $PlantData
    }
}

<#
    .SYNOPSIS
    Routine for access succulent database
    .DESCRIPTION
    .
    .PARAMETER Name
    scientific/botanical (Genus epithet) name for query
    .PARAMETER json
    if specified, return information as Json instead of native object
    .EXAMPLE
    Get-SucculentInfo 'euphorbia resinifera'
#>
function Get-SucculentInfo {
    param(
        [string]$Name,
        [switch]$json
    )

    # convert spaces and strip garbage
    $Name = $Name.Trim() -replace " ","+" -replace "[^a-zA-Z+]",""

    $SearchWR = Invoke-WebRequest "http://llifle.com/Encyclopedia/SUCCULENTS/Species/all/1/10/?filter=$Name"
    if ($SearchWR.AllElements.FindById("all_species_list_main").InnerHtml -match "href=`"(/Encyclopedia/SUCCULENTS/Family/[^`"]*)") {
        $Url = "http://llifle.com" + $Matches[1]
        $PlantPageWR = Invoke-WebRequest ($Url)
    } else {
        throw "couldn't find plant. check spelling and synonyms [http://llifle.com/Encyclopedia/SUCCULENTS/Species/all/1/10/?filter=$Name]"
    }

    $PlantData = New-Object psobject
    $PlantData | Add-Member -Type NoteProperty -Name "Name" -Value $PlantPageWR.ParsedHtml.getElementsByClassName("plant_main_scientific_name_header")[0].InnerText
 
    $ParsedPlantData = Parse-Keywords $PlantPageWR.AllElements.FindById("plant_main_text").InnerHtml -SplittingMethod ${function:Split-Bold}

    $PlantData | Add-Member -Type NoteProperty -Name "Habit" -Value $ParsedPlantData.Habit
    $PlantData | Add-Member -Type NoteProperty -Name "Description" -Value $ParsedPlantData.Description
    $PlantData | Add-Member -Type NoteProperty -Name "Culture" -Value $ParsedPlantData.Culture

    $PlantData | Add-Member -Type NoteProperty -Name "Source" -Value "LLIFLE - Encyclopedia of living forms"
    $PlantData | Add-Member -Type NoteProperty -Name "Cite" -Value "`"$($PlantData.Name)`" Text available under a CC-BY-SA Creative Commons Attribution License. www.llifle.com 14 Nov. 2005. $(Get-Date -f "dd MMM yyyy"). <$Url>"

    if ($json) {
        return $PlantData | ConvertTo-json
    } else {
        return $PlantData
    }
}

function Parse-Keywords {
    param(
        [string]$RawHtml,
        [scriptblock]$SplittingMethod
    )
    $EndOfSectionTags = "(?:</div>|</p>|</section>)(?:.|\n)*"

    $KeyValues = Get-Pairs $SplittingMethod.Invoke($RawHtml)

    $ReturnObject = New-Object psobject
    $ReturnObject | Add-Member -Type NoteProperty -Name "Habit" -Value (New-Object psobject)
    $ReturnObject | Add-Member -Type NoteProperty -Name "Description" -Value (New-Object psobject)
    $ReturnObject | Add-Member -Type NoteProperty -Name "Culture" -Value (New-Object psobject)
    Write-Debug ($KeyValues | Out-String)
    $KeyValues | ForEach-Object {
        $Key = $_[0].Trim(": ").ToLower()
        $Value = $_[1].Trim() -replace $EndOfSectionTags,"" -replace "<[^>]*>","" 
        if (($HabitKeywords | %{$Key -imatch $_}) -contains $true) {
            $ReturnObject.Habit | Add-Member -Type NoteProperty -Name $Key -Value $Value -Force
        } elseif (($DescriptionKeywords | %{$Key -imatch $_}) -contains $true) {
            $ReturnObject.Description | Add-Member -Type NoteProperty -Name $Key -Value $Value -Force
        } elseif (($CultureKeywords | %{$Key -imatch $_}) -contains $true) {
            $ReturnObject.Culture | Add-Member -Type NoteProperty -Name $Key -Value $Value -Force
        } else {
            Write-Verbose "Discarding unmatched $Key`n`"$Value`""
        }
    }
    return $ReturnObject
}

<#
    .SYNOPSIS
    Splitter method for data defined with HTML bold tags
    .DESCRIPTION
    Splits data in the format <b>Key</b>Value[...] 
    such that fieldnames and values are on alternating lines
#>
function Split-Bold {
    param(
        [string]$RawHtml
    )

    $RawHtml = $RawHtml -replace "<br>",""

    return $RawHtml -split "<b>|</b>" | select -Skip 1
}
<#
    .SYNOPSIS
    Splitter method for data defined with HTML strong tags
    .DESCRIPTION
    Splits data in the format <strong>Key</strong>Value[...] 
    such that fieldnames and values are on alternating lines
#>
function Split-Strong {
    param(
        [string]$RawHtml
    )

    $RawHtml = $RawHtml -replace "<br>",""

    return $RawHtml -split "<strong>|</strong>" | select -Skip 1
}

function Get-Pairs {
    param(
        [object[]]$Array
    )

    if ($Array.Length % 2 -ne 0) {
        throw "uneven array"
    } elseif ($Array.Length -eq 2) {
        return ,(,$Array) #wrap two elements and done
    }

    [psobject]$Counter = @{Value = 0}
    return [object[]]($Array | Group-Object -Property {[Math]::Floor($Counter.Value++ / 2)} -AsHashTable).Values
}
