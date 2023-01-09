#****************************************************************
# December 6, 2022
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# Date: 2022-09-14
# Project: N/A
# Comments: Vivado Project Import/Setup Script
#           Automatically generates a Vivado project for the
#           accompanying design and simulation code. Any source 
#           file named `global.vh` will automatically be set  
#           as a global include. Options and project properties  
#           may be configured below.  
#          
#           To Run, Open Vivado, select "Tools -> Run TCL Script..."
#           then browse to and open this script. This script may
#           also be run from the TCl console with the following
#           command:
#             source <path to script>/setup.tcl
#           
#           
#           To create a new project, copy this script into an 
#           empty directory, set the desired project properties
#           below and run the script as directed above.
#      
#
#           NOTE: If project already exists, it will be replaced
#
#********************************
# File history:
#   2022-09-14: Original
#****************************************************************


# ----------------------------------------------------------------
# Project Properties

# The Project's name
set proj_name OX_CORE

# Target device for the project
#set proj_part xc7vx485tffg1157-1
set proj_part xcvu9p-flga2104-2L-e

# Target development board for the project (not strictly required)
#set proj_board ""
set proj_board xilinx.com:vcu118:part0:2.4
#set proj_board_id ""
set proj_board_id vcu118

# Project top modules for simulation and synthesis (blank for auto selection)
set proj_top_sim "core_tb"
set proj_top_syn "core_fpga"

# Disable automatic adding wave configs to project?
set proj_no_waveforms 0

# Any non-standard source files to add to the project
#   -All paths relative to code directory
#   -Each new line in this list must be escaped (end lines with '\')
set proj_addsrc { \
    "src/endpoint/memoryconfig.hex" \
}

# Any non-standard simulation files to add to the project
#   -All paths relative to code directory
#   -Each new line in this list must be escaped (end lines with '\')
#   -May be used in conjunction with 'proj_no_waveforms' to load only
#     specific waveform configurations
set proj_addsim { \
}

# TODO: ability to specify IP repositories

# TODO: remaining required properties

# TODO: list where extra properties can be added



# ----------------------------------------------------------------
# Directory Settings (defaults work for most projects)

# Origin/Root directory (defaults to directory containing script)
set dir_origin [ file dirname [ file normalize [ info script ] ] ]

# Directory for Vivado to store non-code project files
set dir_proj ${dir_origin}/proj

# Root code directory
set dir_code ${dir_origin}/code

# Design source code directory & accepted file extensions
set dir_src ${dir_code}/src
set ext_src {"*.v" "*.vh" "*.sv"}

# IP source directory & accepted file extensions
set dir_ip ${dir_code}/ip
set ext_ip {"*.xci" "*.xcix"}

# Simulation source code directory & accepted file extensions
set dir_sim ${dir_code}/sim
set ext_sim {"*.v" "*.vh" "*.sv"}
set ext_wav {"*.wcfg"}

# Constraint File Directory & accepted file extensions
set dir_cons ${dir_code}/cons
set ext_cons {"*.xdc"}



# ================================================================
#                   Do not edit below this line                   
# ================================================================

# findFiles
# basedir - the directory to start looking in
# pattern - A pattern, as defined by the glob command, that the files must match
proc findFiles { basedir pattern } {

    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory separator
    set basedir [string trimright [file join [file normalize $basedir] { }]]
    set fileList {}

    # Look in the current directory for matching files, -type {f r}
    # means only readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty
    foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
        lappend fileList $fileName
    }

    # Now look for any sub directories in the current directory
    foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
        # Recursively call the routine on the sub directory and append any
        # new files to the results
        set subDirList [findFiles $dirName $pattern]
        if { [llength $subDirList] > 0 } {
            foreach subDirFile $subDirList {
                lappend fileList $subDirFile
            }
        }
    }
    
    return $fileList
}

# findFilesMulti
# basedir - the directory to start looking in
# pattern - A list of patterns, one of which the files must match
proc findFilesMulti { basedir patterns } {
    set fileList {}

    foreach pattern ${patterns} {
        set fileList [list {*}$fileList {*}[findFiles $basedir $pattern]]
    }
    
    return $fileList
}

# ----------------------------------------------------------------

if { [ catch {
    # create directories if they don't exist
    file mkdir $dir_proj $dir_src $dir_sim $dir_cons $dir_ip
    
    
    # Create project
    create_project ${proj_name} ${dir_proj} -force
    
    # Set the directory path for the new project
    set proj_dir [get_property directory [current_project]]
    
    # Set project properties
    set obj [current_project]
    set_property -name "part" -value "${proj_part}" -objects $obj
    
    # Not all Vivado versions will have the board part available. If so, just use the part alone.
    if { [ catch {
        set_property -name "board_part" -value "${proj_board}" -objects $obj
        set_property -name "platform.board_id" -value "${proj_board_id}" -objects $obj
    } err ] } {
        puts "WARNING: Unable to set board part to '${proj_board}'. Continuing using only part '${proj_part}'"
        puts "  Reason: ${err}"
    }
    
    # Not all versions support "revised_directory_structure"
    if { [ catch {
        set_property -name "revised_directory_structure" -value "1" -objects $obj
    } err ] } {
        puts "WARNING: Not using revised directory structure."
        puts "  Reason: ${err}"
    }
    
    set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
    set_property -name "enable_vhdl_2008" -value "1" -objects $obj
    set_property -name "ip_cache_permissions" -value "read write" -objects $obj
    set_property -name "ip_output_repo" -value "$proj_dir/${proj_name}.cache/ip" -objects $obj
    set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
    set_property -name "sim.central_dir" -value "$proj_dir/${proj_name}.ip_user_files" -objects $obj
    set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
    set_property -name "simulator_language" -value "Mixed" -objects $obj
    set_property -name "source_mgmt_mode" -value "DisplayOnly" -objects $obj
    set_property -name "webtalk.activehdl_export_sim" -value "3" -objects $obj
    set_property -name "webtalk.modelsim_export_sim" -value "3" -objects $obj
    set_property -name "webtalk.questa_export_sim" -value "3" -objects $obj
    set_property -name "webtalk.riviera_export_sim" -value "3" -objects $obj
    set_property -name "webtalk.vcs_export_sim" -value "3" -objects $obj
    set_property -name "webtalk.xsim_export_sim" -value "3" -objects $obj
    set_property -name "webtalk.xsim_launch_sim" -value "3997" -objects $obj
    
    # TODO: set properties from additional property list
    
    # ----------------------------------------------------------------

    # Create 'sources_1' fileset (if not found)
    if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
    }

    # Add source files to 'sources_1' fileset
    set obj [get_filesets sources_1]
    set files [findFilesMulti $dir_src $ext_src]
    set files [list {*}$files {*}[findFilesMulti $dir_ip $ext_ip]]
    foreach file ${proj_addsrc} {
        set files [list {*}$files {*}[list "$dir_code/$file"]]
    }
    if {[llength $files]} {
        add_files -norecurse -fileset $obj $files
    }
    
    # Ensure .sv files are registered as SystemVerilog
    # set file_obj [get_files -of_objects $obj [list "*.sv"]]
    # set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
    
    # Set any files named "global.vh" as global includes
    set files [get_files -quiet "global.vh"]
    if {[llength $files]} {
        set_property -name "is_global_include" -value "1" -objects $files
    }

    #Run IP update script
    source ${dir_origin}/update_ip.tcl

    # Generate IP outputs
    #   Swap `[get_ips]` for `[get_files $ext_ip]` ??
    generate_target all [get_ips]
    export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet

    export_simulation -of_objects [get_ips] \
        -directory "$proj_dir/${proj_name}.ip_user_files/sim_scripts" \
        -ip_user_files_dir "$proj_dir/${proj_name}.ip_user_files" \
        -ipstatic_source_dir "$proj_dir/${proj_name}.ip_user_files/ipstatic" \
        -lib_map_path [list \
            {modelsim="$proj_dir/${proj_name}.cache/compile_simlib/modelsim"} \
            {questa="$proj_dir/${proj_name}.cache/compile_simlib/questa"} \
            {xcelium="$proj_dir/${proj_name}.cache/compile_simlib/xcelium"} \
            {vcs="$proj_dir/${proj_name}.cache/compile_simlib/vcs"} \
            {riviera="$proj_dir/${proj_name}.cache/compile_simlib/riviera"}] \
        -use_ip_compiled_libs -force -quiet

    
    if {[string equal $proj_top_syn ""]} {
        set_property -name "top_auto_set" -value "1" -objects $obj
        update_compile_order -fileset sources_1
    } else {
        set_property -name "top" -value "${proj_top_syn}" -objects $obj
        set_property -name "top_auto_set" -value "0" -objects $obj
    }
    
    # ----------------

    # Create 'sim_1' fileset (if not found)
    if {[string equal [get_filesets -quiet sim_1] ""]} {
    create_fileset -simset sim_1
    }
    
    # Add source files to 'sim_1' fileset
    set obj [get_filesets sim_1]
    set files [findFilesMulti $dir_sim $ext_sim]
    if {!$proj_no_waveforms} {
        set files [list {*}$files {*}[findFilesMulti $dir_sim $ext_wav]]
    }
    foreach file ${proj_addsim} {
        set files [list {*}$files {*}"$dir_code/$file"]
    }
    if {[llength $files]} {
        add_files -norecurse -fileset $obj $files
    }
    
    # Ensure .sv files are registered as SystemVerilog
    # set file_obj [get_files -of_objects $obj [list "*.sv"]]
    # set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
    
    if {[string equal $proj_top_sim ""]} {
        set_property -name "top_auto_set" -value "1" -objects $obj
        update_compile_order -fileset sim_1
    } else {
        set_property -name "top" -value "${proj_top_sim}" -objects $obj
        set_property -name "top_auto_set" -value "0" -objects $obj
    }

    # ----------------

    # Force recognize "*.hex" files as data files
    # TODO: user selectable data file extensions
    set files [get_files -quiet "*.hex"]
    if {[llength $files]} {
        set_property -name "file_type" -value "Data Files" -objects $files
    }


    # TODO: add constraint files

} err ] } {
    puts " ==== Project Creation Failed ==== "
    puts $err
    close_project -d
}