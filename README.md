# LS Wheel Theft - Comprehensive Vehicle Wheel Theft System

A feature-rich FiveM script that allows players to engage in wheel theft activities, providing an immersive criminal pathway with missions, tools, and a complete theft-to-sale pipeline.

![LS Wheel Theft](https://i.imgur.com/W4IOZTG.png)

## What is Wheel Theft?

LS Wheel Theft creates a complete criminal enterprise revolving around stealing wheels from vehicles across Los Santos. Players can:

1. Receive missions from a criminal contact (configurable NPC)
2. Locate target vehicles using mission waypoints
3. Use jackstands to lift vehicles realistically
4. Remove and steal wheels using proper animations and tools
5. Store wheels in a provided work truck
6. Sell stolen wheels to a buyer for cash rewards

## Key Features

### Immersive Theft Mechanics
- **Realistic Vehicle Lifting**: Use jackstands that physically raise vehicles
- **Proper Animations**: Different animations based on which side of the vehicle you approach
- **Visual Feedback**: Bricks appear under vehicles to show support when raised
- **Wheel Removal**: Realistic wheel removal process with appropriate timing

### Complete Mission System
- **Criminal Contact**: Speak with an NPC to get wheel theft missions
- **Target Locations**: GPS-marked locations for vehicles with valuable wheels
- **Work Vehicle**: Receive a work truck to transport stolen wheels
- **Buyer NPC**: Separate character who buys the stolen wheels

### Police Integration
- **Dispatch Alerts**: Configurable chance to alert police during thefts
- **Blip System**: Police can receive location information about thefts in progress

### Framework Support
- **Multi-Framework**: Supports QB-Core, ESX, and ox frameworks
- **ox_target Integration**: Full support for contextual interactions
- **ox_inventory**: Compatible with the popular inventory system

## Setup Guide

### Prerequisites
- A FiveM server running QB-Core, ESX, or ox framework
- ox_target (recommended)
- ox_inventory (recommended)
- ox_lib (optional but enhances UI)

### Basic Installation

1. **Download & Place Files**
   - Download the script
   - Extract and place the `wheel_theft` folder in your server resources directory

2. **Choose Your Framework Setup**
   - For QB-Core: Copy files from `_qb_setup` folder to your main QB resources
   - For ESX: Copy files from `_esx_setup` folder to your main ESX resources
   - For ox: Copy files from `_ox_setup` folder to your main ox resources

3. **Add Items to Your Inventory**
   - Add the following items to your inventory system (SQL files provided in setup folders):
     - `jackstand` - Used to lift vehicles
     - `wheel` - The item players steal and sell

4. **Configure the Script**
   - Open `config.lua` and adjust settings to your preference
   - Key settings to change:
     - Mission locations
     - Payment amounts
     - Police notification chance
     - NPC appearances and locations

5. **Start the Resource**
   - Add `ensure wheel_theft` to your server.cfg
   - Restart your server or start the resource

### Advanced Configuration

The `config.lua` file offers extensive customization options:

- **Vehicle Models**: Change which vehicles can be targeted for wheel theft
- **Payment Settings**: Adjust how much players earn per wheel
- **NPC Customization**: Change the appearance and location of mission givers and buyers
- **Police Settings**: Configure police notification chances and response
- **Mission Settings**: Adjust difficulty, spawn locations, and requirements

## Usage for Players

1. **Starting a Mission**
   - Find the mission giver NPC (marked on map if configured)
   - Interact with them to receive a wheel theft mission
   - A work truck will spawn for you to use

2. **Finding Target Vehicles**
   - Follow the GPS waypoint to the target vehicle
   - Approach the vehicle to begin the theft process

3. **Stealing Wheels**
   - Use a jackstand to lift the vehicle (approach wheels and use target)
   - Remove the wheels once the vehicle is lifted
   - Lower the vehicle when done

4. **Storing and Selling**
   - Store wheels in the work truck
   - Drive to the buyer location
   - Sell the wheels for cash

## Troubleshooting

- **Vehicles not lifting**: Make sure ox_target is working correctly
- **Items not showing**: Check that items were properly added to your inventory system
- **NPCs not appearing**: Verify the coordinates in your config.lua match your map

## Support

For support, please refer to the provided documentation or contact the developer through the platform where you purchased the script.

## License

This script is licensed under the MIT License. See the LICENSE file for details.

## Credits

- Remade by iiTzVein.
- Thanks to me.