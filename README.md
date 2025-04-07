# LS Wheel Theft - Comprehensive Vehicle Theft System

A feature-rich FiveM script for wheel theft, jackstand mechanics, and parts selling. This script provides an immersive criminal enterprise focused on stealing and selling vehicle wheels.

![LS Wheel Theft Banner](https://i.imgur.com/YourBannerImage.png)

## Features

### Complete Wheel Theft System
- **Mission-based Gameplay**: Receive missions from a Mexican boss to steal wheels from specific vehicles
- **Target Identification**: Missions provide exact vehicle locations with GPS markers
- **Realistic Wheel Removal**: Use jackstands to lift vehicles and tools to remove wheels
- **Wheel Storage System**: Store stolen wheels in your pickup truck
- **Sales Process**: Deliver stolen wheels to a shady dealer for cash

### Vehicle Mechanics System
- **Jackstand Mechanics**: Use inventory jackstands to raise and lower vehicles
- **Realistic Animations**: Proper mechanic animations when working under vehicles
- **Side-specific Interactions**: Different animations based on which side of the vehicle you approach
- **Vehicle Stabilization**: Bricks placed under vehicles when raised to show support
- **Item Management**: Jackstand is removed from inventory when used and returned when vehicle is lowered

### Target Integration
- **ox_target Support**: Full integration with ox_target for immersive interactions
- **Contextual Options**: Different target options based on vehicle state and mission status
- **Bone Targeting**: Precise interaction points for wheel removal

### Police Features
- **Dispatch System**: Configurable dispatch alerts for police
- **Alert Chance**: Random chance for police to be notified of thefts
- **Blip System**: Police receive detailed blip locations of crimes

### Quality of Life
- **Multilingual Support**: Easy localization through config
- **Highly Configurable**: Almost every aspect can be customized via config.lua
- **Optimized Performance**: Efficient code designed for minimal resource usage
- **QB-Core Integration**: Seamless integration with QB-Core framework
- **ox_lib Support**: Advanced UI components with ox_lib

## Technical Features

- **Entity State Management**: Robust handling of entity states between clients
- **Network ID Tracking**: Proper network synchronization of all entities
- **Cleanup Routines**: Thorough cleanup to prevent resource leaks
- **Persistent Storage**: Database integration for long-term storage

## Recent Improvements

- **Fixed Brick Positioning**: Bricks now properly touch the ground when vehicles are lowered
- **Enhanced Jackstand Animations**: Correct animations work from both sides of the vehicle
- **Jackstand Recovery**: Jackstands are returned to inventory when lowering vehicles
- **Different Mission Characters**: Mexican boss for mission giving, Mexican gang member for buying stolen goods
- **Realistic Lowering Mechanics**: Jackstands remain in place while only the vehicle lowers

## Requirements

- QB-Core Framework
- ox_target
- ox_inventory (recommended)
- ox_lib (optional but enhances UI)

## Installation

1. Place the `wheel_theft` folder in your server resources directory
2. Add `ensure wheel_theft` to your server.cfg
3. Import the provided SQL file for item definitions
4. Configure the script in `config.lua`
5. Restart your server

## Configuration

The script is highly configurable through the `config.lua` file. Key configurations include:

- Vehicle models for theft missions
- Payment amounts and variations
- Police notification settings
- Spawn locations for mission vehicles
- PED models for dealers and mission givers
- Blip settings and visibility

## Documentation

For detailed documentation on how to configure the script, refer to the [Configuration Guide](https://link-to-your-docs.com).

## Credits

- Original development by Your Development Team
- Animations and prop models by Rockstar Games
- Special thanks to the testing team for their valuable feedback

## Support

For support, join our [Discord server](https://discord.gg/your-discord) or open an issue on our [GitHub repository](https://github.com/your-org/wheel_theft).

## License

This script is licensed under the MIT License. See the LICENSE file for details.

# Task 1: Despawning Work Vehicle on Mission Cancel

Added a WORK_VEHICLE variable in client/truckSpawn.lua to track the vehicle.

Modified SpawnTruck to store the vehicle reference.

Created DespawnWorkVehicle to remove the vehicle properly.

Called this function from CancelMission in client/mission.lua.

Added cleanup when the resource stops.

Ensured it only despawns when the player cancels via the NPC.

# Task 2: Implementing ox_target for Interactions

## Replaced key presses (E/H) with ox_target:

**Mission NPCs (Start/Cancel):**

Added network ID tracking.

Created dynamic options based on mission state.

Cleaned up properly when missions end.

**Seller Ped & Crate (Sale/Drop Wheels):**

Added target options with state-based availability.

Ensured proper cleanup.

**Vehicle Wheel Theft:**

Implemented bone-targeting for precise interactions.

Added different options for target vs. non-target vehicles.

Included options for lowering vehicles and finishing theft.

**Truck Interactions (Store/Take Wheels):**

Added target options for storing and retrieving wheels.

Ensured proper cleanup.

# Code Changes Summary

## Files Affected
- `client/client.lua`

## New Functions Added
1. `RegisterTargetVehicleWithOxTarget(vehicle, isTargetVehicle)`
   - Handles vehicle registration with ox_target
   - Adds wheel theft options
   - Manages vehicle cleanup
   - Parameters:
     - vehicle: The target vehicle entity
     - isTargetVehicle: Boolean indicating if it's a mission vehicle

2. `RegisterTruckWithOxTarget(vehicle)`
   - Manages truck registration for wheel storage
   - Handles wheel storage options
   - Parameters:
     - vehicle: The truck entity

## Modified Functions
1. `StartWheelTheft(vehicle)`
   - Added ox_target integration
   - Improved vehicle tracking
   - Enhanced wheel theft process

2. `StopWheelTheft(vehicle)`
   - Added ox_target cleanup
   - Improved vehicle state management
   - Enhanced mission completion handling

3. `BeginWheelLoadingIntoTruck(wheelProp)`
   - Added ox_target integration
   - Improved wheel storage process
   - Enhanced truck interaction

4. `EnableWheelTakeOut()`
   - Added ox_target integration
   - Improved wheel retrieval process
   - Enhanced truck interaction

## New Variables Added
1. `targetVehicleNetIds`
   - Array to track registered target vehicles
   - Used for cleanup and management

2. `truckNetId`
   - Stores the network ID of the current truck
   - Used for truck-specific operations

## Resource Management
- Added comprehensive cleanup in `onResourceStop` handler
- Improved vehicle tracking and deletion
- Enhanced ox_target entity management

## Integration Points
1. ox_target Integration
   - Vehicle registration
   - Wheel theft options
   - Truck storage options
   - Entity cleanup

2. Vehicle Management
   - Improved vehicle state tracking
   - Enhanced cleanup procedures
   - Better mission vehicle handling

## Total Changes
- 4 new functions
- 4 modified functions
- 2 new variables
- 1 new event handler
- Improved resource management
- Enhanced integration with ox_target