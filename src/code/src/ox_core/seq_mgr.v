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
// Project: OmniXtend Core
// Comments: N/A
//
//********************************
// File history:
//   2022-10-06, ID=SRJAM
//     If the 'Send Request' is running when the Ack timer expired, it would jam in the wait state.
//     Solved by removing dependency on 'ack_timer_in_progress' for transitioning out of wait state.
//     See comments starting with "//SRJAM"
//****************************************************************




`timescale 1ns / 1ps


module seq_mgr
    #(
      //parameter ACK_TIMEOUT  = 32'd128)
      //parameter ACK_TIMEOUT  = 32'd64)   //need to respond to Endpoint quicker
        parameter ACK_TIMEOUT  = 32'd96)   //minimum ack time out
    (
        input                   clk,
        input                   rst_,

        input                   tx_req,
        input                   tx_done,
        output                  ackmtotx_busy,

        input                   tx2rx_updateseq_req,    // update seq req, PULSE - must latched before it went away
        input           [21:0]  tx2rx_seq_num,          // seq num from tx (local seq)
        output  reg             tx2rx_updateseq_done,   // update seq req done back to tx

        output  reg             rx2tx_updateack_req,    // update tx ack req (update remote ack)
    //  output  reg     [21:0]  rx2tx_new_ack_num,      // new ack num from rx  (remote ack for rtx)
        output  reg     [ 3:0]  rx2tx_free_entries,     // number of entries to free int he RTX linked list
    //  output  reg     [ 3:0]  rx2tx_rtx_entries,      // the number of entries needing retransmit
        output  reg             rx2tx_rtx_req,          // RTX req
        input                   rx2tx_rtxreq_done,      // RTX req done
        input                   rx2tx_updateack_done,

        output  reg             rx2tx_send_req,         // send req     //TODO: rename rx2tx_ack_req or rx2tx_sendack_req
        output  reg             rx2tx_ack_mode,         // ack mode, ack = 1, nack = 0
        output  reg     [21:0]  rx2tx_rxack_num,        // ack num to send out to remote node (local ack)
        input                   rx2tx_sendreq_done,                     //TODO: rename rx2tx_ack_done or rx2tx_sendack_done

        input                   bcnt_rden,              // indicate there's a packet (for timer to start)

        input           [21:0]  oxm2ackm_new_ack_num,   // Remote ack num from M2OX
        input           [21:0]  oxm2ackm_new_seq_num,   // Remote seq num from M2OX
        input                   oxm2ackm_chk_req,       // Asserted by M2OX to request a sequence check
        input                   oxm2ackm_ack,           // Remote ack mode from M2OX (ack = 1, nack = 0)
        input                   rx_done,                // Asserted when M2OX has finished RXing current packet (= rx_done_st from M2OX)
        output  reg             oxm2ackm_accept,        // Assert for M2OX to current RXed packet (1 = accept 0 = reject)
        output  reg             oxm2ackm_busy,          // Asserted by seq_mgr when running a sequence check or ACK timer expire
        output  reg             oxm2ackm_done           // Asserted by seq_mgr when sequence check is done
    );

    //================================================================//
    //  State Machine State Encoding and State Signals

    reg [3:0]   update_seq_state;
    localparam  US_IDLE         =   4'h1,
                US_CHECK_SEQ    =   4'h2,   //  check the new sequence number in this state
                US_UPDATE       =   4'h4,   //  if the new seq number is OK, update it
                US_DONE         =   4'h8;   //  return the done to the requester

    wire        us_idle_st      =   update_seq_state[0];
    wire        us_check_seq_st =   update_seq_state[1];
    wire        us_update_st    =   update_seq_state[2];
    wire        us_done_st      =   update_seq_state[3];

    //----------------------------------------------------------------//

    reg [7:0]   update_ack_state;
    localparam  UA_IDLE         =   8'h01,
                UA_CHECK_ACK    =   8'h02,  //  checking the new ACK number
                UA_CALC         =   8'h04,  //  calculate how many entries that we need to request or need RTX_REQ
                UA_REQ          =   8'h08,  //  request either *updateack_req or *rtx_req
                UA_WAIT         =   8'h10,  //  wait for the TX Path to respond with DONE
                UA_DONE         =   8'h20;

    wire        ua_idle_st      =   update_ack_state[0];
    wire        ua_check_ack_st =   update_ack_state[1];
    wire        ua_calc_st      =   update_ack_state[2];
    wire        ua_req_st       =   update_ack_state[3];
    wire        ua_wait_st      =   update_ack_state[4];
    wire        ua_done_st      =   update_ack_state[5];

    //----------------------------------------------------------------//

    reg [7:0]   send_req_state;
    localparam  SR_IDLE         =   8'h01,
                SR_CHECK_SEQ    =   8'h02,  //  check the sequence number as indicated above
                SR_CALC         =   8'h04,  //  may not need (determine in-order or not)
                SR_REQ          =   8'h08,  //  request TX Path to perform ACK or NACK
                SR_WAIT         =   8'h10,  //  wait for TX Path to complete
                SR_DONE         =   8'h20;

    wire        sr_idle_st      =   send_req_state[0];
    wire        sr_check_seq_st =   send_req_state[1];
    wire        sr_calc_st      =   send_req_state[2];
    wire        sr_req_st       =   send_req_state[3];
    wire        sr_wait_st      =   send_req_state[4];
    wire        sr_done_st      =   send_req_state[5];

    //----------------------------------------------------------------//

  //reg [1:0]   master_state;
    reg [3:0]   master_state;       //20220505
    localparam  MASTER_IDLE     =   4'h1,
                MASTER_BUSY     =   4'h2,
                MASTER_DONE     =   4'h8;

    wire    master_idle_st  =   master_state[0];
    wire    master_busy_st  =   master_state[1];
    //
    wire    master_done_st  =   master_state[3];

    assign  ackmtotx_busy   =   master_state[1];



    reg [21:0]  ack_num_max;
    reg [21:0]  ack_num_cur;
    reg [21:0]  ack_num_new;
    reg [21:0]  seq_cur_tx;
    reg [21:0]  seq_cur_rx;     //will become our ack number
    reg [21:0]  seq_next_rx;    //Sequence number to expect next
    reg         ack_mode_rx;    //Incoming (remote) ack mode (1 = ack, 0 = nack);
    reg         seq_in_order;



    reg [31:0]  ack_timer;
    reg         ack_timer_expired;
    reg         ack_timer_in_progress;

    reg     updateseq_gnt, tx_req_gnt, chk_req_gnt, timer_gnt;      //different modes MASTER operates in


    //------------ vars
    reg             updateseq_pending ;
    reg     [21:0]  seq_num_reg ;   //to keep the seq number to be updated around


    //================================================================//
    //  'Update Sequence Number' State Machine
    //  Started by OX2M to update TX sequence number
    //    TX2RX UPDATE SEQ REQ CYCLE

    //Next State Logic
    always @ (posedge clk) begin
        if (!rst_) begin
            update_seq_state    <=  US_IDLE;
        end
        else begin
            if (us_idle_st) begin
                //update_seq_state  <=  (tx2rx_updateseq_req                ) ? US_CHECK_SEQ : US_IDLE;
                //update_seq_state  <=  (tx2rx_updateseq_req & updateseq_gnt) ? US_CHECK_SEQ : US_IDLE;
                update_seq_state    <=  (updateseq_pending   & updateseq_gnt) ? US_CHECK_SEQ : US_IDLE;
            end

            //check the TX seq number for validity before updating RX local copy?
            if (us_check_seq_st) begin
                update_seq_state    <=  ack_num_max < tx2rx_seq_num ? US_UPDATE : US_DONE;
            end

            if (us_update_st) begin
                update_seq_state    <=  US_DONE;
            end

            if (us_done_st) begin
                update_seq_state    <=  US_IDLE;
            end
        end // Else
    end

    //Output Logic
    always @ (posedge clk) begin
        if (!rst_) begin
            ack_num_max        		<=  22'b0;
            seq_cur_tx        		<=  22'b0;
            tx2rx_updateseq_done	<=  1'b0;
        end
        else begin
            case (update_seq_state)
                US_IDLE: begin
                    tx2rx_updateseq_done <=  1'b0;
                end

                US_CHECK_SEQ:   begin
                //  seq_cur_tx  <=  (tx2rx_seq_num - ack_num_max == 1) ? tx2rx_seq_num : seq_cur_tx;
                    seq_cur_tx  <=  (tx2rx_seq_num - ack_num_max >= 1) ? tx2rx_seq_num : seq_cur_tx;
                end
                
                US_UPDATE: begin
                    ack_num_max <=  seq_cur_tx;
                end
                
                US_DONE: begin
                    tx2rx_updateseq_done <=  1'b1;
                end
            endcase
        end // Else
    end

    //================================================================//
    //  'Update ACK Number' State Machine
    //  Runs at the same time as the RX sequence check
    //  RX2TX UPDATE ACK REQ CYCLE or RTX REQ CYCLE

    //Next State Logic
    always  @ (posedge clk) begin
        if (!rst_) begin
            update_ack_state <= UA_IDLE;
        end
        else begin

            //Idle State: Stay idle unless M2OX's sequence check request is granted
            if (ua_idle_st) begin
            //  update_ack_state    <=  oxm2ackm_chk_req && master_idle_st ? UA_CHECK_ACK : UA_IDLE;
                update_ack_state    <=  oxm2ackm_chk_req && chk_req_gnt ? UA_CHECK_ACK : UA_IDLE;
            end

            if (ua_check_ack_st) begin
                update_ack_state    <=  UA_CALC;
            end

            if (ua_calc_st) begin
                update_ack_state    <=  UA_REQ;
            end

            if (ua_req_st) begin
                update_ack_state    <=  (!ack_mode_rx)               ? UA_WAIT:
                                        (ack_num_new >= ack_num_cur) ? UA_WAIT:
                                        UA_DONE;
            end

            if (ua_wait_st) begin
                update_ack_state    <=  ((rx2tx_updateack_done || tx_done) && ack_mode_rx) || (rx2tx_rtxreq_done && !ack_mode_rx) ? UA_DONE : UA_WAIT;
            end

            if (ua_done_st) begin
                update_ack_state    <=  UA_IDLE;
            end
        end //
    end

    //Output Logic
    always @ (posedge clk) begin
        if (!rst_) begin
            ack_num_new <= 0;
            rx2tx_updateack_req <=  1'b0;
            rx2tx_rtx_req       <=  1'b0;
            rx2tx_free_entries  <=  4'b0;
        //  rx2tx_rtx_entries   <=  0;
            ack_num_cur         <=  22'b0;
        //  rx2tx_new_ack_num   <=  0;
            ack_mode_rx         <=  1'b0;
        end
        else begin
            case(update_ack_state)
                UA_IDLE: begin
                    ack_num_new 		<=     0;
                    rx2tx_updateack_req <=  1'b0;
                    rx2tx_rtx_req       <=  1'b0;
                    rx2tx_free_entries  <=   'b0;
                //  rx2tx_rtx_entries   <=     0;
                    ack_mode_rx     	<=  1'b0;
                //  rx2tx_new_ack_num   <=     0;
                end

                UA_CHECK_ACK: begin
                    ack_num_new     <= oxm2ackm_new_ack_num;
                    ack_mode_rx		<= oxm2ackm_ack;
                end

                UA_CALC: begin
                //  rx2tx_rtx_entries   <=  (ack_mode_rx) ? rx2tx_rtx_entries : ack_num_max - ack_num_new;
                //  rx2tx_free_entries  <=  (ack_mode_rx) ?
                //                          (ack_num_new > ack_num_cur) ? ack_num_new - ack_num_cur : rx2tx_free_entries  :
                //                          rx2tx_free_entries;
                //  rx2tx_free_entries  <=  (ack_num_new > ack_num_cur) ? ack_num_new - ack_num_cur - 22'd1 : rx2tx_free_entries  ;
                    rx2tx_free_entries  <=  (ack_num_new > ack_num_cur) ? ack_num_new - ack_num_cur : rx2tx_free_entries  ;
                end

                UA_REQ: begin
                    if (ack_mode_rx) begin
                        rx2tx_updateack_req <=  (ack_num_new >= ack_num_cur) ? 1'b1 : 1'b0;
                    end else begin
                        rx2tx_rtx_req       <=  1'b1;
//                      rx2tx_new_ack_num   <=  (ack_num_new > ack_num_cur) ? ack_num_new : rx2tx_new_ack_num;
                    end
                end

                UA_WAIT: begin
                    rx2tx_updateack_req <=  1'b0;
                    rx2tx_rtx_req       <=  1'b0;
                end

                UA_DONE: begin
                    ack_num_cur         <=  (ack_num_cur <= ack_num_new) && (ack_num_new <= ack_num_max) ?
                                                ack_num_new :
                                                ack_num_cur;
                end
            endcase
        end // Else
    end


    //================================================================//
    //  'Check Sequence & Send ACK' State Machine
    //  Sends (N)ACK on Ack Timer Expire or Out-of-Order Packet RX
    //  RX2TX Send ACK Request (higher priority than the local transmit)

    //Next State Logic
    always  @ (posedge clk) begin
        if (!rst_) begin
            send_req_state  <=  SR_IDLE;
        end
        else begin

            //Idle State: Transition to Sequence Check State if M2OX need sequence check, or ACK Timer expired
            //            Must receive check/timer grant from Main State Machine to proceed
            if (sr_idle_st) begin
              //send_req_state  <=  oxm2ackm_chk_req  && master_idle_st ? SR_CHECK_SEQ :
              //                    ack_timer_expired && master_idle_st ? SR_CHECK_SEQ :
              //                    SR_IDLE;

                send_req_state  <=  ( (oxm2ackm_chk_req  && chk_req_gnt)   |
                                      (ack_timer_expired && timer_gnt  ) ) ? SR_CHECK_SEQ :
                                    SR_IDLE;
            end

            if (sr_check_seq_st) begin
                send_req_state  <=  SR_CALC;
            end

            if (sr_calc_st) begin
                send_req_state  <=  SR_REQ;
            end

            if (sr_req_st) begin
                send_req_state  <=  SR_WAIT;
            end

            //Wait State: ____________
            if (sr_wait_st) begin
              //send_req_state  <=  rx2tx_sendreq_done || (ack_timer_in_progress && rx_done) ? SR_DONE : SR_WAIT;  //SRJAM(-)//
                send_req_state  <=  rx2tx_sendreq_done || (rx_done & chk_req_gnt) ? SR_DONE : SR_WAIT;  //SRJAM(+)//
                                    //   ^                     ^          ^ Only stop on RX done if running seq number check
                                    //   ^                     ^ means M2OX done processing an RX pkt
                                    //   ^ from TX_Path to indicate the SEND_REQ completed
            end

            if (sr_done_st) begin
                send_req_state  <=  SR_IDLE;
            end
        end
    end

    //Output Logic
    always @ (posedge clk) begin
        if (!rst_) begin
            seq_cur_rx          <= 22'b0;
            seq_next_rx         <= 22'b0;
            seq_in_order        <=  1'b0;
            rx2tx_send_req      <=  1'b0;
            rx2tx_ack_mode      <=  1'b0;
            rx2tx_rxack_num     <= 22'b0;
            oxm2ackm_done       <=  1'b0;
            oxm2ackm_accept     <=  1'b0;
            oxm2ackm_busy       <=  1'b0;
        //  ack_timer_in_progress <=  0;
        end

        else begin
            case (send_req_state)

                //Idle State: Reset internal status registers
                SR_IDLE: begin
                    seq_in_order    <=  1'b0;
                    oxm2ackm_done   <=  1'b0;
                    oxm2ackm_accept <=  1'b0;
                //  rx2tx_ack_mode  <=  1'b0;
                //  oxm2ackm_busy   <=  oxm2ackm_chk_req | ack_timer_expired;
                    oxm2ackm_busy   <=  chk_req_gnt | timer_gnt ;   //Become busy if we're about to leave idle

                    //true if TIMER is not expired
                    //should move this out of the SM?
                //  ack_timer_in_progress   <=  ack_timer_in_progress ? ack_timer_in_progress : oxm2ackm_chk_req | ack_timer_expired;
                end

                //Check Sequence State: Update current RX sequence number if in order and set in_order flag accordingly
                SR_CHECK_SEQ: begin
                    seq_cur_rx  	<=  (oxm2ackm_new_seq_num - seq_cur_rx == 1) ? oxm2ackm_new_seq_num : seq_cur_rx;
                    seq_in_order    <=  (oxm2ackm_new_seq_num == seq_next_rx   ) ? 1'b1 : 1'b0;
                end

                //Calculate State: Calculate next expected RX sequence number
                SR_CALC: begin
                    seq_next_rx 	<=  seq_next_rx > seq_cur_rx ? seq_next_rx : seq_cur_rx   +   seq_in_order   ;
                    oxm2ackm_accept <=  seq_in_order;
                //-/oxm2ackm_done   <=  1'b1;
                    oxm2ackm_done   <=  chk_req_gnt;    //+//	//2022-10-10: only assert sequence check done if doing the check
                end

                //Ack Request State: ____________
                SR_REQ: begin
                    //Request TX Path send ACK if timer is expired
                //  rx2tx_send_req          <=  ack_timer == 32'b0;
                    rx2tx_send_req          <=  timer_gnt;

                    //Select ACK mode (ACK vs NACK/Retransmit)
                //  rx2tx_ack_mode          <=  ack_timer_expired  ? rx2tx_ack_mode : seq_in_order;
                //  rx2tx_ack_mode          <=  !ack_timer_expired ? rx2tx_ack_mode : seq_in_order;     //20220608 - correction
                    rx2tx_ack_mode          <=  timer_gnt          ? 1'b1 : //timer expired, so request an ACK (vs NACK)
                                               !ack_timer_expired  ? rx2tx_ack_mode:   //non-timer mode, hold
                                                seq_in_order;                           //normal mode as pkt coming in; 20220608 - correction

                //+/rx2tx_ack_mode          <=  chk_req_gnt ? seq_in_order :
                //+/                            timer_gnt ? 1'b1 :
                //+/                            seq_in_order;

                    rx2tx_rxack_num         <=  seq_cur_rx;

                //  ack_timer_in_progress   <=  !(ack_timer == 32'b0);
                end

                SR_WAIT: begin
                //  rx2tx_send_req  <=  1'b0;
                    rx2tx_send_req  <= rx2tx_sendreq_done ? 1'b0 : rx2tx_send_req; //CLE 20220420
                end

                SR_DONE: begin
                //  rx2tx_rxack_num <= 22'b0;
                    oxm2ackm_done   <=  1'b0;
                    oxm2ackm_accept <=  1'b0;
                end
            endcase
        end // Else
    end


    //================================================================//
    //  ACK TIMER

    always  @ (posedge clk) begin
        if (!rst_) begin
        //  ack_timer           <= 32'b0;
            ack_timer           <= ACK_TIMEOUT;          //20220505 CLE
            ack_timer_expired   <=  1'b0;
        end // if rst

        else begin
            //change to RELOAD to avoid racing condition at the start of the process
        //  if (ack_timer == 32'b0 && oxm2ackm_chk_req && master_idle_st)
        //  if (timer_gnt & !sr_idle_st ) //reload on servicing a timeout
            if( bcnt_rden & !ack_timer_in_progress) begin
                //load

                //ack_timer <= ACK_TIMEOUT - 1'b1;
                ack_timer <= ACK_TIMEOUT ;
                //ack_timer_expired   <=  1'b0;
            end // if (timer_gnt & !sr_idle_st )

            else begin
                //count and check for time out

                //ack_timer <=    ack_timer == 32'b0 ? ack_timer : ack_timer - 1'b1;
                ack_timer <=
                    !ack_timer_in_progress | (ack_timer == 32'b0) ? ack_timer :
                    ack_timer - 1'b1;
                //ack_timer_expired   <=  ack_timer == 32'b0  && ack_timer_in_progress ? 1'b1 : 1'b0;
                ack_timer_expired   <=
                    timer_gnt ? 1'b0 :
                    (ack_timer == 32'b0) && ack_timer_in_progress ? 1'b1 :
                    ack_timer_expired;
            end // else
        end // else
    end


    //reg       tx_req_gnt, chk_req_gnt, timer_gnt;     //different modes MASTER operates in

    //================================================================//
    //  Master State Machine

    always  @ (posedge clk) begin
        if (!rst_) begin
            master_state    <= MASTER_IDLE;
            tx_req_gnt      <= 1'b0 ;       //indicate servicing TX request mode
            chk_req_gnt     <= 1'b0 ;       //indicate servicing M2OX check request mode
            timer_gnt       <= 1'b0 ;       //indicate servicing ACK Timer timeout mode
            updateseq_gnt   <= 1'b0 ;       //indicate servicing ACK Timer timeout mode
        end
        else begin
            if (master_idle_st) begin
                //TODO: should not handle TX_REQ In here???
                master_state    <=    updateseq_pending || tx_req || oxm2ackm_chk_req || ack_timer_expired ? MASTER_BUSY : MASTER_IDLE;

                //arbitrate current mode on leaving IDLE
                //priority from highest to lowest
              //updateseq_gnt   <=  tx2rx_updateseq_req ;                   //for updating the local sequence number from the TX Path
                updateseq_gnt   <=  updateseq_pending ;                     //for updating the local sequence number from the TX Path
                timer_gnt       <= !updateseq_pending &  ack_timer_expired ;                                //for ACK timer times out
                chk_req_gnt     <= !updateseq_pending & !ack_timer_expired &  oxm2ackm_chk_req ;            //for RX seq checking	//-/
            //+/chk_req_gnt     <= !updateseq_pending &                       oxm2ackm_chk_req ;            //for RX seq checking
                tx_req_gnt      <= !updateseq_pending & !ack_timer_expired & !oxm2ackm_chk_req & tx_req ;   //for updating TX variables

            end
            if (master_busy_st) begin
              //master_state    <=    ua_done_st || sr_done_st || tx_done ? MASTER_IDLE : MASTER_BUSY;
              //master_state    <=    ua_done_st || sr_done_st || tx_done ? MASTER_DONE : MASTER_BUSY;
                master_state    <=          //20220513
                    updateseq_gnt ? ( us_done_st ? MASTER_DONE : MASTER_BUSY) : //case of RX receiving a pkt or chk_req
                    //chk_req_gnt ? (rx_done ? MASTER_DONE : MASTER_BUSY) : //case of RX receiving a pkt or chk_req
                        //TX side can take longer to process than RX side
                        //Need to wait for the SENDREQ SM to complete before DONE
                    chk_req_gnt ? ((oxm2ackm_done & sr_done_st) ? MASTER_DONE : MASTER_BUSY) : //case of RX receiving a pkt or chk_req
                        //??? on timer processing may need to wait until TX side had sent the ACK out to the network
                        //before going to DONE
                //-/sr_done_st || tx_done ? MASTER_DONE : //case of SEND_REQ or processing TX REQuest
                    sr_done_st || (tx_req_gnt & tx_done) ? MASTER_DONE : //case of SEND_REQ or processing TX REQuest	//2022-10-10: Only stop on tx_done if granting TX
                    MASTER_BUSY;
            end

            //-- added 20220505 to allow signals clearing out at end of an access to avoid racing condition
            if (master_done_st) begin
                master_state    <= MASTER_IDLE ;
                updateseq_gnt   <= 1'b0 ;
                timer_gnt       <= 1'b0 ;
                chk_req_gnt     <= 1'b0 ;
                tx_req_gnt      <= 1'b0 ;
            end

        end    //
    end

    // =================================== COMBINTATION LOGIC =====================================================

    always  @ (posedge clk)
        if (!rst_) begin
            updateseq_pending       <=  1'b0 ;
            seq_num_reg             <= 21'b0 ;
            ack_timer_in_progress   <=  1'b0 ;
        end
        else begin
            updateseq_pending    <=
                updateseq_gnt ? 1'b0 :
                tx2rx_updateseq_req ? 1'b1 :
                updateseq_pending ;

            seq_num_reg          <=
                tx2rx_updateseq_req ? tx2rx_seq_num :
                seq_num_reg ;

            ack_timer_in_progress   <=
                ack_timer_expired ? 1'b0 :
                bcnt_rden ? 1'b1 :
                ack_timer_in_progress ;
        end



//=============================
//synopsys translate_off
    reg [12*8:0] ascii_update_seq_state;

    always@(update_seq_state) begin
        case(update_seq_state)
             US_IDLE        : ascii_update_seq_state = "US_IDLE"      ;
             US_CHECK_SEQ   : ascii_update_seq_state = "US_CHECK_SEQ" ;
             US_UPDATE      : ascii_update_seq_state = "US_UPDATE"    ;
             US_DONE        : ascii_update_seq_state = "US_DONE"      ;
        endcase
    end

    reg [12*8:0] ascii_update_ack_state;

    always@(update_ack_state) begin
        case(update_ack_state)
             UA_IDLE        : ascii_update_ack_state = "UA_IDLE"      ;
             UA_CHECK_ACK   : ascii_update_ack_state = "UA_CHECK_ACK" ;
             UA_CALC        : ascii_update_ack_state = "UA_CALC"      ;
             UA_REQ         : ascii_update_ack_state = "UA_REQ"       ;
             UA_WAIT        : ascii_update_ack_state = "UA_WAIT"      ;
             UA_DONE        : ascii_update_ack_state = "UA_DONE"      ;
        endcase
    end

    reg [12*8:0] ascii_send_req_state;

    always@(send_req_state) begin
        case(send_req_state)
             SR_IDLE        : ascii_send_req_state = "SR_IDLE"      ;
             SR_CHECK_SEQ   : ascii_send_req_state = "SR_CHECK_SEQ" ;
             SR_CALC        : ascii_send_req_state = "SR_CALC"      ;
             SR_REQ         : ascii_send_req_state = "SR_REQ"       ;
             SR_WAIT        : ascii_send_req_state = "SR_WAIT"      ;
             SR_DONE        : ascii_send_req_state = "SR_DONE"      ;
        endcase
    end

    reg [12*8:0] ascii_master_state;

    always@(master_state) begin
        case(master_state)
             MASTER_IDLE    : ascii_master_state = "MASTER_IDLE"    ;
             MASTER_BUSY    : ascii_master_state = "MASTER_BUSY"    ;
             MASTER_DONE    : ascii_master_state = "MASTER_DONE"    ;
        endcase
    end
//synopsys translate_on

endmodule
