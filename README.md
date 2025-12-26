# VHDL to Minecraft Redstone Circuit Entity Compiler 
This project provides an implementation for a subset of the VHDL IEEE 1076 2008 Spec, representing this initially as a logic gate intermediate representation before then translating into a Minecraft circuit description that is finally converted into a Named Binary Tag (NBT) file.

This generated file can then be added to any Minecraft world to construct the circuit and do some awesome stuff

## How It Does This
The process of going from VHDL source to Minecraft Entity is a very involved one, requiring a parser, several intermediate representations and finally a binary file protocol implementation, the general pipeline can be followed as:

```
[VHDL source] => [High Level Entity and Architectures] => [Gate Level Circuit] \\
                                                                                || 
                               [NBT Entity] <= [Minecraft Block Description] <=//
```

## Examples
### Single-Bit Full Adder:
<img width="1502" height="993" alt="image" src="https://github.com/user-attachments/assets/cd47e657-f4d5-416d-86c4-9f1d050f82b2" />


### 2-bit Ripple Carry Adder:
https://github.com/user-attachments/assets/a7b261b5-1d88-48c3-b45d-48760e02150d


Note: The input and output selectors and lamps were not generated as a part of the NBT structure, but the underlying logic circuit and input grid both were :)
