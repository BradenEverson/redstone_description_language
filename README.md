# VHDL to Minecraft Redstone Circuit Entity Compiler 

https://github.com/user-attachments/assets/4ebd65f2-e26f-4be8-8f5c-bc32a5d43ad2


This project provides an implementation for a subset of the VHDL IEEE 1076 2008 Spec, representing this initially as a logic gate intermediate representation before then translating into a Minecraft circuit description that is finally converted into a Named Binary Tag (NBT) file.

This generated file can then be added to any Minecraft world to construct the circuit and do some awesome stuff

## How It Does This
The process of going from VHDL source to Minecraft Entity is a very involved one, requiring a parser, several intermediate representations and finally a binary file protocol implementation, the general pipeline can be followed as:

```
[VHDL source] => [High Level Entity and Architectures] => [Gate Level Circuit] \\
                                                                                || 
                               [NBT Entity] <= [Minecraft Block Description] <=//
```

## Usage
### Building our Circuit
To build RHDL from source, you must have Zig version 0.15.1 installed. In the project root, build the executable with

```
zig build
```

To create the `rhdl` executable in the `zig-out/bin/` directory. (You can also run the project directly with `zig build run -- {file}` if you're in the project root)

To use `rhdl`, simply create a valid VHDL file and compile it to a redstone entity with `rhdl {file}.vhd`. This will create a Named Binary Tag (NBT) file that can be used directly in vanilla Minecraft.

### Using the Circuit in Minecraft
Awesome, now you have an NBT file representing your digital logic circuit! The next step is to get it usable within Minecraft. To do so, navigate to your Minecraft data folder. On Linux, this can likely be found at `~/.minecraft` or somewhere similar. On Windows, in the file explorer navigation bar type `%appdata%` and you should see a `.minecraft` folder. 

Once you are in your `.minecraft` data folder, navigate to saves and then the folder named after the world you want to use the circuit in. In this folder, we are going to have to create some directories for our new structure. At the root of your save folder, create the nested directories `generated/minecraft/structures`. This is the folder path that Minecraft will look at when you try spawning in our circuit structures. Simply drop your generated `.nbt` file in here and we can move on!

### Loading the Circuit in Minecraft
Now that our file is generated and loaded in an appropriate spot, all that's left is using it in the game! Simply start up the World you placed the NBT file into, and give yourself a structure block. This can be done with the command 

```
/give @s minecraft:structure_block
```

This block is used to load structure entities from that nested folder we created. placing and right clicking this block will bring us into a control page for loading and controlling our structure. This page has several different modes for loading and saving entities, so click the button on the bottom left until it says `Load` and looks like the page pictured below:

<img width="1919" height="1199" alt="image" src="https://github.com/user-attachments/assets/94d0b8d2-f77d-47e0-8ee0-c3b69b0b0537" />

Once we're on the loading specific page, the first input is the name of our entity. This is given from `minecraft:` followed by the name of our NBT structure without the .nbt at the end. For example, if we compiled `foo.vhd` into redstone circuit `foo.nbt`, we would type `minecraft:foo` into this page.

The next 3 inputs provide the offset from the structure block to spawn in the entity. For me, it defaulted to being 0 shifts on the x and z axis, and a single y axis shift, so I usually just dug one block down and placed my structure block there so I wouldn't have to change these parameters when rapidly checking changes. Feel free to shift the structure as much as you'd like. 

Now that all parameters are set, we simply need to click the `LOAD` button near the bottom right. This will create a bounding box in the overworld of where our structure will load:

<img width="1919" height="1199" alt="image" src="https://github.com/user-attachments/assets/e40b5c02-df82-4268-9566-21512f28f3c1" />

This bounding box is *technically* going to try limiting us to a 48x48x48 box, but we don't need to worry about this. Simply place a redstone button or lever next to your structure block and activate it to load the RHDL circuit into your world! Have fun!

<img width="1919" height="1199" alt="image" src="https://github.com/user-attachments/assets/d95cae63-1913-4187-a9de-6b8139488f0f" />


## Examples
### Single-Bit Full Adder:
<img width="1502" height="993" alt="image" src="https://github.com/user-attachments/assets/cd47e657-f4d5-416d-86c4-9f1d050f82b2" />

### 3-Bit Number Five Detector:
<img width="1609" height="1037" alt="image" src="https://github.com/user-attachments/assets/1e083739-8aac-48bc-b92a-c20576cc7e1e" />

### 2-bit Ripple Carry Adder:
https://github.com/user-attachments/assets/a7b261b5-1d88-48c3-b45d-48760e02150d


Note: The input and output selectors and lamps were not generated as a part of the NBT structure, but the underlying logic circuit and input grid both were :)

Also, the video quality is abysmal because simulating a giant redstone circuit and recording video on a laptop is apparently a bit too much
