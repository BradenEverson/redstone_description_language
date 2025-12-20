# VHDL to Minecraft Redstone Circuit Entity Compiler 
This project provides an implementation for a subset of the VHDL IEEE 1076 2008 Spec, representing this initially as a logic gate intermediate representation before then translating into a Minecraft circuit description that is finally converted into a Named Binary Tag (NBT) file.

This generated file can then be added to any Minecraft world to construct the circuit and do some awesome stuff

## How It Does This
The process of going from VHDL source to Minecraft Entity is a very involved one, requiring a parser, several intermediate representations and finally a binary file protocol implementation, the general pipeline can be followed as:

```
[VHDL source] => [High Level Entity and Architectures] => [Gate Level Circuit] \
                                                                                | 
                               [NBT Entity] <= [Minecraft Block Description] <=/
```
