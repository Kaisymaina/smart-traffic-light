/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_smart_traffic (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // --------------------------------------------------
    // STATES
    // --------------------------------------------------

    localparam CAR_RED       = 3'b000;
    localparam YELLOW_TO_GREEN = 3'b001;
    localparam CAR_GREEN     = 3'b010;
    localparam YELLOW_TO_RED = 3'b011;
    localparam PED_CROSS     = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // --------------------------------------------------
    // TIMING
    // --------------------------------------------------

    `ifdef SIM
        localparam GREEN_TICKS  = 10;
        localparam YELLOW_TICKS = 5;
        localparam RED_TICKS    = 10;
        localparam PED_TICKS    = 10;
    `else
        localparam GREEN_TICKS  = 500000000;
        localparam YELLOW_TICKS = 150000000;
        localparam RED_TICKS    = 500000000;
        localparam PED_TICKS    = 500000000;
    `endif

    reg [28:0] timer;

    // --------------------------------------------------
    // PEDESTRIAN REQUEST
    // --------------------------------------------------

    reg ped_request;

    always @(posedge clk) begin
        if (!rst_n)
            ped_request <= 0;
        else if (state == PED_CROSS)
            ped_request <= 0;
        else if (ui_in[0])
            ped_request <= 1;
    end

    // --------------------------------------------------
    // EMERGENCY TOGGLE
    // --------------------------------------------------

    reg emergency;
    reg emergency_prev;

    always @(posedge clk) begin
        if (!rst_n) begin
            emergency      <= 0;
            emergency_prev <= 0;
        end
        else begin
            emergency_prev <= ui_in[1];

            if (ui_in[1] && !emergency_prev)
                emergency <= ~emergency;
        end
    end

    // --------------------------------------------------
    // STATE REGISTER
    // --------------------------------------------------

    always @(posedge clk) begin
        if (!rst_n)
            state <= CAR_RED;
        else
            state <= next_state;
    end

    // --------------------------------------------------
    // TIMER
    // --------------------------------------------------

    always @(posedge clk) begin
        if (!rst_n)
            timer <= 0;
        else if (emergency)
            timer <= 0;
        else if (state != next_state)
            timer <= 0;
        else
            timer <= timer + 1;
    end
    // --------------------------------------------------
    // NEXT STATE LOGIC
    // --------------------------------------------------

    always @(*) begin

        next_state = state;

        // Emergency forces everything to RED
        if (emergency) begin
            next_state = CAR_RED;
        end
        else begin

            case (state)

                // --------------------------------------
                // RED
                // --------------------------------------
                CAR_RED: begin
                    if (timer >= RED_TICKS - 1) begin

                        if (ped_request)
                            next_state = PED_CROSS;
                        else
                            next_state = YELLOW_TO_GREEN;

                    end
                end

                // --------------------------------------
                // YELLOW BEFORE GREEN
                // --------------------------------------
                YELLOW_TO_GREEN: begin
                    if (timer >= YELLOW_TICKS - 1)
                        next_state = CAR_GREEN;
                end

                // --------------------------------------
                // GREEN
                // --------------------------------------
                CAR_GREEN: begin
                    if (timer >= GREEN_TICKS - 1)
                        next_state = YELLOW_TO_RED;
                end

                // --------------------------------------
                // YELLOW BEFORE RED
                // --------------------------------------
                YELLOW_TO_RED: begin
                    if (timer >= YELLOW_TICKS - 1)
                        next_state = CAR_RED;
                end

                // --------------------------------------
                // PEDESTRIAN CROSSING
                // --------------------------------------
                PED_CROSS: begin
                    if (timer >= PED_TICKS - 1)
                        next_state = YELLOW_TO_GREEN;
                end

                // --------------------------------------
                // SAFETY DEFAULT
                // --------------------------------------
                default: begin
                    next_state = CAR_RED;
                end

            endcase
        end
    end

        // --------------------------------------------------
    // PEDESTRIAN BUZZER
    // --------------------------------------------------

    `ifdef SIM
        localparam BEEP_TICKS = 2;
    `else
        localparam BEEP_TICKS = 25000000;
    `endif

    reg [28:0] beep_timer;
    reg beep_state;

    always @(posedge clk) begin
        if (!rst_n) begin
            beep_timer <= 0;
            beep_state <= 0;
        end
        else if (state != PED_CROSS) begin
            beep_timer <= 0;
            beep_state <= 0;
        end
        else if (beep_timer >= BEEP_TICKS - 1) begin
            beep_timer <= 0;
            beep_state <= ~beep_state;
        end
        else begin
            beep_timer <= beep_timer + 1;
        end
    end

    // --------------------------------------------------
    // OUTPUTS
    // --------------------------------------------------

    // Car RED
    assign uo_out[0] =
        emergency ||
        state == CAR_RED ||
        state == PED_CROSS;

    // Car YELLOW
    assign uo_out[1] =
        !emergency &&
        (state == YELLOW_TO_GREEN ||
         state == YELLOW_TO_RED);

    // Car GREEN
    assign uo_out[2] =
        !emergency &&
        state == CAR_GREEN;

    assign uo_out[3] =
        emergency ||
        state != PED_CROSS;

    // Pedestrian GREEN
    assign uo_out[4] =
        !emergency &&
        state == PED_CROSS;

    // Buzzer
    assign uo_out[5] =
        !emergency &&
        state == PED_CROSS &&
        beep_state;

    // Unused outputs
    assign uo_out[6] = 1'b0;
    assign uo_out[7] = 1'b0;

    // Flexible I/O unused
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused = &{ena, uio_in, 1'b0};

endmodule
