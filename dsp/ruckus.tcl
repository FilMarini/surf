# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadRuckusTcl "$::DIR_PATH/generic"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 2023.1} {
   loadRuckusTcl "$::DIR_PATH/xilinx"
} else {
   # EthCrc32Parallel (RoCEv2 iCRC engine) instantiates surf.DspXor
   loadSource -lib surf -fileType "VHDL 2008" -path "$::DIR_PATH/xilinx/logic/DspXor.vhd"
}
