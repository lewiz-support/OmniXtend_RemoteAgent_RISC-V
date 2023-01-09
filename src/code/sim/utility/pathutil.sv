//****************************************************************
// December 6, 2022
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//
// Date: N/A
// Project: N/A
// Comments: N/A
//
//********************************
// File history:
//   N/A
//****************************************************************

`timescale 1ns / 1ps

//NOTE: To use this function in testbenches, 
//      1) Add this file to the project as a simualtion source
//      2) Declare an instance of module 'pathutil' in the testbench module
//         e.g. 'pathutil path();'
//      3) Call the function as belonging to that instance
//         e.g. 'path.buildpath_relative(<arguments>)'

module pathutil ();
    //Builds an absolute file path from the given absolute and relative paths
    //  "upto" may be used to specify a directory to move up to (must always end with "/")
    function string buildpath_relative(input string fullpath, input string relative, input string upto);
        int i;
        int str_index;
        automatic logic found_path=0;
        string tmp;
        automatic string ret="";
    
        if (upto.len() != 0) begin
            for (i = fullpath.len()-upto.len(); i>0; i=i-1) begin
                tmp = fullpath.substr(i,i+upto.len()-1);
                if (tmp == upto) begin
                    found_path=1;
                    str_index=i+upto.len()-1;
                    break;
                end
            end
        end
        
        if (found_path==0) begin
            for (i = fullpath.len()-1; i>0; i=i-1) begin
                if (fullpath[i] == "/") begin
                    found_path=1;
                    str_index=i;
                    break;
                end
            end
        end
        
        if (found_path==1) begin
            ret={fullpath.substr(0,str_index),relative};
        end 

        return ret;
    endfunction

endmodule