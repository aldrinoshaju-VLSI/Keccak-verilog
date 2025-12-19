transcript on
if ![file isdirectory verilog_libs] {
	file mkdir verilog_libs
}

vlib verilog_libs/altera_ver
vmap altera_ver ./verilog_libs/altera_ver
vlog -vlog01compat -work altera_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/altera_primitives.v}

vlib verilog_libs/lpm_ver
vmap lpm_ver ./verilog_libs/lpm_ver
vlog -vlog01compat -work lpm_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/220model.v}

vlib verilog_libs/sgate_ver
vmap sgate_ver ./verilog_libs/sgate_ver
vlog -vlog01compat -work sgate_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/sgate.v}

vlib verilog_libs/altera_mf_ver
vmap altera_mf_ver ./verilog_libs/altera_mf_ver
vlog -vlog01compat -work altera_mf_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/altera_mf.v}

vlib verilog_libs/altera_lnsim_ver
vmap altera_lnsim_ver ./verilog_libs/altera_lnsim_ver
vlog -sv -work altera_lnsim_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/altera_lnsim.sv}

vlib verilog_libs/cyclonev_ver
vmap cyclonev_ver ./verilog_libs/cyclonev_ver
vlog -vlog01compat -work cyclonev_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/mentor/cyclonev_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/mentor/cyclonev_hmi_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/cyclonev_atoms.v}

vlib verilog_libs/cyclonev_hssi_ver
vmap cyclonev_hssi_ver ./verilog_libs/cyclonev_hssi_ver
vlog -vlog01compat -work cyclonev_hssi_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/mentor/cyclonev_hssi_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_hssi_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/cyclonev_hssi_atoms.v}

vlib verilog_libs/cyclonev_pcie_hip_ver
vmap cyclonev_pcie_hip_ver ./verilog_libs/cyclonev_pcie_hip_ver
vlog -vlog01compat -work cyclonev_pcie_hip_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/mentor/cyclonev_pcie_hip_atoms_ncrypt.v}
vlog -vlog01compat -work cyclonev_pcie_hip_ver {d:/intelfpga_lite/24.1std/quartus/eda/sim_lib/cyclonev_pcie_hip_atoms.v}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/f_permutation.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/keccak.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/padder1.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/rconst2in1.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/round2in1.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/padder_fast_2.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/dbram.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/sampleinball_fsm.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/sampleinball_top.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/keccak_prg_adapter.v}
vlog -vlog01compat -work work +incdir+C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5 {C:/Users/aldri/OneDrive/Documents/RBL/quartus_workspace/g5/sampleinball_top_new_tb.v}

