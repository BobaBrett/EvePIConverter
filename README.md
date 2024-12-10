# EvePIConverter
Simple(ish) Script that Converts an Extraction planet between PlanetTypes. Created with the Help of GitHub CoPilot

## What it Does

- Takes a Supplied Template (Use mine or choose your own)
- Offers to change the planet Type for the Template
- If Changing Planet Type (or staying the same even), gives you the available Single Planet Production Types, and allows you to update Pins + Routes based on your selection
- You can now import the new Json into game, to apply your Initial Extraction Template to additional Planets 



## Process

- Update Sample.json with the export from your PI Template. 
- Run Process.ps1
- Choose 
- NewSample.json will be created with changes as you have configured


## Assumptions

- Intended to work on Extractor to P2 Planets. E.g. 6x P0>P1 Factories, 3x P1>P2 Factories + 2x Extractor Heads
- Factory Planets aren't currently supported, though theoretically if only producing up to P2 would work. 
- You will still need to find the best place to drop your template on the planet you want, and may need to move your extractors + extractor heads, potnetially re-creating your route from the Extractors to your Launchpad

## Feedback

Please Contact "Kotori" in Game, or ".bobabrett" on Discord