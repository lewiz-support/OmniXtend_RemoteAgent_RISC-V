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
# Date: 2022-09-23
# Project: N/A
# Comments: Vivado Project IP Updater Script
#           Automatically configures IP to work with the format
#           used by the Project Import/Setup Script. Works on
#           the currently opened project.
#          
#           To Run, Open Vivado, select "Tools -> Run TCL Script..."
#           then browse to and open this script. This script may
#           also be run from the TCl console with the following
#           command:
#             source <path to script>/update_ip.tcl
#           
#           
#           WARNING: Currently only works if ip directory is `code/ip`
#                    (In both this script and the Import/Setup Script)
#
#********************************
# File history:
#   2022-09-23: Original
#****************************************************************


# ----------------------------------------------------------------
# Main Configuration

# Only update IPs that are currently in the project
set search_projOnly 1

# File extensions that indicate the presence of generated output in 
#  the IP source directory
set ext_gen {".veo" ".vho"}

# For IP folders containing generated output, completely clear them?
# WARNING: May remove user created files
set clear_all 0

# File extensions of files to delete when cleared generated output
set ext_del {"*.veo" "*.vho" "*.xml" "*.xdc"}



# ----------------------------------------------------------------
# Directory Settings (defaults work for most projects)

# Origin/Root directory (defaults to directory containing script)
set dir_origin [ file dirname [ file normalize [ info script ] ] ]

# Directory for Vivado to store non-code project files
set dir_proj ${dir_origin}/proj

# Root code directory
set dir_code ${dir_origin}/code

# IP source directory & accepted file extensions
set dir_ip ${dir_code}/ip
set ext_ip {"*.xci" "*.xcix"}


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
    # Collect Paths to IP files (either only in project or any in IP dir)
    if {$search_projOnly} {
        set files [get_files -quiet $ext_ip]
    } else {
        set files [findFilesMulti $dir_ip $ext_ip]
    }
    
    # Project dir path relative to origin dir (proj MUST be in origin)
    regsub "($dir_origin)/(.*)" $dir_proj {\2} dir_proj_name
    #TODO: get number of `..` to use in path
    
    # Project name for creating new generation output path
    set proj_name [get_property NAME [current_project]]
    
    # Good generation output paths must start with this
    set dir_gen_good "../../../$dir_proj_name/"
    
    # New generation output path (Each IP gets their own subdirectory)
    set dir_gen "../../../$dir_proj_name/Generic.gen/sources_1/ip/" 
    # TODO: Use project name in .gen folder?
    
    # List of IPs that need regenerating
    set regen {}
    
    # Check each IP for need of updating
    foreach file $files {
    
        if {[string first $dir_ip $file] == -1} {
            puts "Skipping $file"
            continue
        }
       
        set bReset 0
        
        # If traces of generated output found in folder, delete them
        foreach ext $ext_gen {
            set base [file rootname $file]
            set dir  [file dirname $file]/
            #puts "Testing $base$ext"
            if { [file exists $base$ext] == 1} {
                puts "Cleaning: $file"
                puts "  Found $base$ext"
                
                # "Soft" delete by resetting the IPs generated outputs
                reset_target all $file
                export_ip_user_files -of_objects $file -no_script -sync -force -quiet
                
                # If enabled, just hard delete everything except .xci and most user files
                # WARNING: this may delete some user created files
                if {$clear_all} {
                    set toDelete [glob -nocomplain -type {d  r} -path $dir *]
                    foreach del $ext_del {
                        set toDelete [list {*}$toDelete {*}[glob -nocomplain -type {f  r} -path $dir $del]]
                    }
                    if {[llength $toDelete]} {
                        puts "Deleting: $toDelete"
                        file delete -force -- {*}"$toDelete"
                    }
                } else {
                    file delete "${base}.xml"
                }
                
                set bReset 1
                break
            }
        }
        
        # Read in the IPs xci file (It's small enough to fit in memory)
        set fxci [open $file]
        set xcidata [read -nonewline $fxci]
        close $fxci
        
        # Even if IP was not reset above, the output path may still be wrong. Check it here
        if {!$bReset} {
            if {[regexp "\"RUNTIME_PARAM.OUTPUTDIR\">$dir_gen_good\[^<\]*</" "$xcidata" out]} {
                # puts "  Valid output path found: $out"
            } else {
                puts "Cleaning: $file"
                puts "  Bad generation output path"
                
                # "Soft" delete by resetting the IPs generated outputs
                reset_target all $file
                export_ip_user_files -of_objects $file -no_script -sync -force -quiet
                set bReset 1
            }
        }
        
        # Update the IP if it has been reset
        if {$bReset} {
            # Remove IP from project
            remove_files $file

            # Replace generated output path in in-memory xci
            regsub -all "\"RUNTIME_PARAM.OUTPUTDIR\">\[^<\]*</" $xcidata "\"RUNTIME_PARAM.OUTPUTDIR\">$dir_gen[file rootname [file tail $file]]</" newdata
            
            #DEBUG: show that replace succeded
            if {[regexp "\"RUNTIME_PARAM.OUTPUTDIR\">\.\./\.\./\.\./$dir_proj_name/\[^<\]*</" "$newdata" out]} {
                puts "  Replace succeeded: $out"
            }
            
            # Write modified xci back to file
            set f [open $file w]
            puts $f $newdata
            close $f
            
            # Add IP back to project
            add_files -quiet $file
            
            lappend regen $file
        } else {
            puts "Already up-to-date: $file"
        }

    }
    
    # Refresh generation for all IPs (will only generate for those not up to date)
    #TODO: only generate for changed IPs
    generate_target all [get_files $regen]
    export_ip_user_files -of_objects [get_files $regen] -no_script -sync -force -quiet
   
    export_simulation -of_objects [get_files $regen] \
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
    
} err ] } {
    puts " ==== IP Update Failed ==== "
    puts $err
}