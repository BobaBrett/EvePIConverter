# Purpose: Process and modify Planetary Interaction (PI) configurations
# Inputs: sample.json - Current PI configuration
#         mappings.json - Material and facility type mappings
#         schematics.json - Production recipes and requirements
# Outputs: NewSample.json - Updated PI configuration

# Load configuration files into memory
$jsonString = Get-Content -Path "sample.json" -Raw
$jsonObject = $jsonString | ConvertFrom-Json

$mappingsString = Get-Content -Path "mappings.json" -Raw
$mappings = $mappingsString | ConvertFrom-Json

$schematicsString = Get-Content -Path "Schematics.json" -Raw
$schematics = $schematicsString | ConvertFrom-Json

# Function: Get-PinTypeForPlanet
# Purpose: Match facility types between planets
# Inputs: tier - Facility level (Basic/Advanced/Extractor)
#        planetType - Target planet type ID
#        mappings - Reference data for valid combinations
# Returns: Matching facility type ID or null if no match
function Get-PinTypeForPlanet {
    param (
        $tier,
        $planetType,
        $mappings
    )
    
    foreach ($pin in $mappings.pins.PSObject.Properties) {
        if ($pin.Value.tier -eq $tier -and $pin.Value.planetType -eq $planetType) {
            return $pin.Name
        }
    }
    return $null
}

# Determine valid planet type options based on current setup
# High-tech facilities restrict planet choices to Barren/Temperate
$currentPlanetType = $jsonObject.Pln.ToString()
$hasHighTechPins = $jsonObject.P | Where-Object { $_.T -eq "2482" -or $_.T -eq "1028" }
$planetChoices = if ($hasHighTechPins) {
    @("2016", "11") # Only Barren and Temperate allowed
} else {
    $mappings.Planets.PSObject.Properties.Name
}

# Display current configuration and available choices
$currentPlanetName = $mappings.Planets.$currentPlanetType.name
Write-Output "Current planet type: $currentPlanetName"

Write-Output "`nAvailable planet types:"
$planetChoices | ForEach-Object { 
    Write-Output "$_) $($mappings.Planets.$_.name)"
}

$choice = Read-Host "`nEnter new planet type number (or press Enter to keep current)"
if ($choice -and $planetChoices -contains $choice) {
    # Update planet type in configuration
    $jsonObject.Pln = [int]$choice
    
    # Convert facility types to match new planet
    foreach ($pin in $jsonObject.P) {
        if ($pin.T) {
            $pinInfo = $mappings.pins.($pin.T.ToString())
            if ($pinInfo) {
                $newPinType = Get-PinTypeForPlanet -tier $pinInfo.tier -planetType $choice -mappings $mappings
                if ($newPinType) {
                    $pin.T = [int]$newPinType
                }
            }
        }
    }

    # Material Replacement Logic
    # 1. Get new planet's available resources/products
    $newPlanetInfo = $mappings.Planets.$choice
    
    # 2. Check for extractors (only process if planet has resource gathering)
    $hasExtractors = $jsonObject.P | Where-Object { 
        $mappings.pins.($_.T.ToString()).tier -eq "Extractor" 
    }
    
    if ($hasExtractors) {
        # 3. Find all P2 (advanced) products currently in production
        Write-Output "`nRecommended Material Updates:"
        
        $p2Products = $jsonObject.R | Where-Object {
            $material = $mappings.materials.($_.T.ToString())
            $material.type -eq "P2"
        }
        $p2Products = $p2Products | Select -Unique T

        $Oldp1Products = $jsonObject.R | Where-Object {
            $material = $mappings.materials.($_.T.ToString())
            $material.type -eq "P1"
        }
        $Oldp1Products = $p1Products | Select -Unique T
        
        if ($p2Products) {
            # 4. For each P2 product:
            # - Show current P2 and available replacements
            # - Update routes and facilities if user chooses replacement
            # - Find required P1 inputs for new P2
            # - Update P1 and P0 production chains
            Write-Output "`nP2 Product Recommendations:"
            foreach ($p2 in $p2Products[0]) {
                $oldP2 = $mappings.materials.($p2.T.ToString()).description
                $availableP2s = $newPlanetInfo.products.basic
                
                Write-Output "Current P2: $oldP2"
                Write-Output "Available P2s on $($newPlanetInfo.name):"
                $availableP2s | ForEach-Object -Begin {$i = 1} {
                    Write-Output "$i) $($mappings.materials.$_.description)"
                    $i++
                }
                
                $p2Choice = Read-Host "`nEnter number of P2 to replace with (or press Enter to skip)"
                if ($p2Choice -and [int]$p2Choice -ge 1 -and [int]$p2Choice -le $availableP2s.Count) {
                    $newP2Id = $availableP2s[$p2Choice - 1]
                    
                    # Update routes with new P2
                    $routesToUpdate = $jsonObject.R | Where-Object { $_.T -eq $p2.T }
                    foreach ($route in $routesToUpdate) {
                        $route.T = [int]$newP2Id
                    }

                    $pinsToUpdate = $jsonObject.P | Where-Object { $_.S -eq $p2.T }
                    foreach ($pin in $pinsToUpdate) {
                        $pin.S = [int]$newP2Id
                    }
                    
                    Write-Output "Updated P2 product: $($mappings.materials.$newP2Id.description)"
                }

                if ($p2Schematic) {
                    # 5. For each required P1:
                    # - Show P1 requirements
                    # - Find related P0 resources
                    # - Update entire production chain
                    # Find related P1s in schematic
                    $p2Schematic = $schematics.SchematicTypeMap.PSObject.Properties | 
                        Where-Object { $_.Value.Where({$_.typeID -eq  $newP2Id -and $_.isInput -eq 0}) }
                
                    if ($p2Schematic) {
                        Write-Output "`nRequired P1 replacements:"
                        $p1Inputs = $p2Schematic.Value | Where-Object { $_.isInput -eq 1 }
                        
                        foreach ($newP1 in $p1Inputs) {
                            Write-Output "`nNew P1 required: $($mappings.materials.($newP1.typeID.ToString()).description)"
    
                            
                            $newp1Schematic = $schematics.SchematicTypeMap.PSObject.Properties | 
                            Where-Object { $_.Value.Where({$_.typeID -eq  $newP1.typeID -and $_.isInput -eq 0}) }
    
                            $newp0Id = $newp1schematic.value | where-object { $_.isInput -eq 1} | select -expand typeID
    
    
                            Write-Output "Current P1s in use:"
                            
                            $Oldp1Products | ForEach-Object -Begin {$i = 1} {
                                Write-Output "$i) $($mappings.materials.($_.T.ToString()).description)"
                                $i++
                            }
                            
                            $p1Choice = Read-Host "Which current P1 should be replaced with $($mappings.materials.($newP1.typeID.ToString()).description)? (Enter number or press Enter to skip) `n This Will also update the P0 Extraction and Routes"
                            
                            if ($p1Choice -and [int]$p1Choice -ge 1 -and [int]$p1Choice -le $Oldp1Products.Count) {
                                $oldP1 = $Oldp1Products[$p1Choice - 1]
    
                                $oldp1Schematic = $schematics.SchematicTypeMap.PSObject.Properties | 
                                Where-Object { $_.Value.Where({$_.typeID -eq  $oldP1.T -and $_.isInput -eq 0}) }
        
                                $oldp0Id = $oldp1schematic.value | where-object { $_.isInput -eq 1} | select -expand typeID
    
                                
                                # Update routes using old P1
                                $routesToUpdate = $jsonObject.R | Where-Object { $_.T -eq $oldP1.T }
                                foreach ($route in $routesToUpdate) {
                                    $route.T = [int]$newP1.typeID
                                }
    
                                #Update Routes producing old P0
                                $routesToUpdate = $jsonObject.R | Where-Object { $_.T -eq  $oldp0Id }
                                foreach ($route in $routesToUpdate) {
                                    $route.T = [int]$newp0Id
                                }      
                                
                                
                                # Update pins producing old P1
                                $pinsToUpdate = $jsonObject.P | Where-Object { $_.S -eq $oldP1.T }
                                foreach ($pin in $pinsToUpdate) {
                                    $pin.S = [int]$newP1.typeID
                                }
    
                                #Update Routes using Old P0
                                $pinsToUpdate = $jsonObject.P | Where-Object { $_.S -eq $oldp0Id}
                                foreach ($pin in $pinsToUpdate) {
                                    $pin.S = [int]$newp0Id
                                }
                                
                                Write-Output "Updated P1: $($mappings.materials.($oldP1.T.ToString()).description) -> $($mappings.materials.($newP1.typeID.ToString()).description)"
                            }
                        }
                    }
                }
            }
        }
        
        # Show available raw resources on new planet
        Write-Output "`nAvailable P0 Resources:"
        foreach ($resource in $newPlanetInfo.resources) {
            Write-Output "- $($mappings.materials.$resource.description)"
        }
    }
    
    # Save updated configuration
    $jsonObject | ConvertTo-Json -Depth 10 | Set-Content "NewSample.json"
    Write-Output "`nPlanet type and pins updated successfully! Saved to NewSample.json"
}

# Display Configuration Summary
# 1. Show basic planet information
# Get planet type description
$planetType = $mappings.Planets.($jsonObject.Pln.ToString()).name

# Output Parent Information
Write-Output "Command Center Level: $($jsonObject.CmdCtrLv)"
Write-Output "Comment: $($jsonObject.Cmt)"
Write-Output "Diameter: $($jsonObject.Diam)"
Write-Output "Planet Type: $planetType"

# 2. Process and display facility information
# Group facilities by type and show their products
# Create hashtables to store unique installation types and their products
$Pins = @{}

# Process installations and their products
Write-Output "`nInstallation Types and Their Products:"
foreach ($pin in $jsonObject.P) {
    $pinType = $pin.T
    $producedProduct = $pin.S
    
    # Get installation description
    $installDesc = ""
    if ($mappings.pins.PSObject.Properties.Name -contains $pinType) {
        $installDesc = $mappings.pins.$pinType.description
    }
    elseif ($mappings.pins.PSObject.Properties.Name -contains $pinType) {
        $installDesc = $mappings.pins.$pinType.description
    }
    
    if ($producedProduct -ne $null) {
        if (!$Pins.ContainsKey($installDesc)) {
            $Pins[$installDesc] = @()
        }
        
        # Get product description
        $productDesc = ""
        if ($mappings.materials.PSObject.Properties.Name -contains $producedProduct) {
            $productDesc = $mappings.materials.$producedProduct.description
        }
        
        if (!$Pins[$installDesc].Contains($productDesc)) {
            $Pins[$installDesc] += $productDesc
        }
    }
}

# Display unique installation types and their products
foreach ($type in $Pins.Keys | Sort-Object) {
    Write-Output "Installation $type produces: $($Pins[$type] -join ', ')"
}

# 3. Process and display production routes
# Show connections between facilities and material flow
Write-Output "`nInstallation Routes:"
foreach ($route in $jsonObject.R) {
    $sourcePin = $jsonObject.P[$route.P[0]-1]
    $sourceDesc = if ($mappings.pins.PSObject.Properties.Name -contains $sourcePin.T) {
        $mappings.pins.($sourcePin.T).description
    } else {
        $mappings.pins.($sourcePin.T).description
    }
    
    $destinationDescs = $route.P[1..($route.P.Length-1)] | ForEach-Object {
        $pin = $jsonObject.P[$_-1]
        if ($mappings.pins.PSObject.Properties.Name -contains $pin.T) { 
            $mappings.pins.($pin.T).description
        } else {
            $mappings.pins.($pin.T).description
        }
    }
    
    $productDesc = if ($mappings.materials.PSObject.Properties.Name -contains $route.T) {
        $mappings.materials.($route.T).description
    } else {
        $route.T
    }
    
    Write-Output "Route: $sourceDesc -> $($destinationDescs -join ' -> ') | Quantity: $($route.Q) | Product: $productDesc"
}

