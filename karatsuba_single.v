`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.05.2025 05:19:05
// Design Name: 
// Module Name: karatsuba_single
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module karatsuba_single #(parameter N = 32) (input [N-1:0] a,b,output [N+N-1:0] y);
    localparam power_of_two_N = ((N != 0) && ((N & (N - 1)) == 0)) == 0 ? N : 1'b1 << $rtoi($ceil($clog2(N)));
    wire [power_of_two_N-1:0] a_final = (power_of_two_N == N) ? a : {{power_of_two_N-N{1'b0}},a};
    wire [power_of_two_N-1:0] b_final = (power_of_two_N == N) ? b : {{power_of_two_N-N{1'b0}},b}; 
    n_by_n_mult #(.N(power_of_two_N),.called_from_N(0)) k_single (a_final,b_final,y);

endmodule

module n_by_n_mult #(parameter N = 4, parameter called_from_N = 0)
    (input [N-1:0] a,b,
    output wire [2*N-1:0] y);

    localparam half_of_N = N >> 1;
    localparam mult_N_by_two = N << 1;
    localparam sum_bit_no = half_of_N + 1;
    
    generate
        if ( N <= 4 ) begin
            wire [3:0] a_final = (N < 4) ? {{4-N{1'b0}},a} : a;
            wire [3:0] b_final = (N < 4) ? {{4-N{1'b0}},b} : b;
            wire [3:0] ab,cd;
            wire [3:0] mult1,mult2;
            wire [7:0] mid_term_out;
            
            
            //Karatsuba on lhs of two inputs
            base_mult base_mult_1 (
                .a(a_final[3:2]),
                .b(b_final[3:2]),
                .y(mult1)
                );
            //Karatsuba on rhs of two inputs
            base_mult base_mult_2 (
                .a(a_final[1:0]),
                .b(b_final[1:0]),
                .y(mult2)
                );
            //Compute a+b and c+d
            assign ab = a_final[3:2] + a_final[1:0];
            assign cd = b_final[3:2] + b_final[1:0];
            
            // Compute (a+b).(c+d) //////////////////
            
            // a.c value of mid term will be 1 if lhs of both are 1
            wire mid_term_ac;
            wire [3:0] mid_term_bd;
            wire [3:0] mid_term_mid_term;
            and(mid_term_ac,ab[2],cd[2]);
            
            //////////////////////////////////////////
            base_mult base_mult_3 (
                .a(ab[1:0]),
                .b(cd[1:0]),
                .y(mid_term_bd)
                );
                
            base_mult base_mult_4 (
                .a(ab[2] + ab[1:0]),
                .b(cd[2] + cd[1:0]),
                .y(mid_term_mid_term)
                );
            
            wire [3:0] mid_term_mid_term_subtracted = mid_term_mid_term - mid_term_ac - mid_term_bd;
            
            assign mid_term_out = (mid_term_ac << 4) + (mid_term_mid_term_subtracted << 2) + mid_term_bd;
            
            wire [5:0] mid_term_out_subtracted = mid_term_out - mult1 - mult2;
            
            assign y = (mult1 << 4) + (mid_term_out_subtracted << 2) + mult2;
        end
        else begin
            wire [N-1:0] mult1,mult2;
            wire [N-1:0] ab,cd;
            
            wire [N-1:0] mid_term_out_wo_pad;
            wire [mult_N_by_two-1:0] mid_term_out;
            wire [mult_N_by_two-1:0] mid_term_out_if;
            assign ab = a[N-1:half_of_N] + a[half_of_N-1:0];
            assign cd = b[N-1:half_of_N] + b[half_of_N-1:0];
            
            n_by_n_mult #(.N(half_of_N),.called_from_N(0)) n_by_n_mult1 (
                .a(a[N-1:half_of_N]),
                .b(b[N-1:half_of_N]),
                .y(mult1)
            );
            
            n_by_n_mult #(.N(half_of_N),.called_from_N(0)) n_by_n_mult_2 (
                .a(a[half_of_N-1:0]),
                .b(b[half_of_N-1:0]),
                .y(mult2)
            );
            

            if(called_from_N != 1) begin
                n_by_n_mult #(.N(N),.called_from_N(called_from_N+1)) n_by_n_mult3 (
                    .a(ab),
                    .b(cd),
                    .y(mid_term_out_if)
                );
            end
            else begin
                n_by_n_mult #(.N(half_of_N),.called_from_N(0)) n_by_n_mult3 (
                    .a(ab[half_of_N-1:0]),
                    .b(cd[half_of_N-1:0]),
                    .y(mid_term_out_wo_pad)
                );
            end
            
            wire [mult_N_by_two-1:0] mid_term_out_padded = {{half_of_N{1'b0}}, mid_term_out_wo_pad};
            assign mid_term_out = called_from_N == 1 ? mid_term_out_padded : mid_term_out_if;            
            wire [mult_N_by_two - 1:0] mid_term_out_subtracted = mid_term_out - mult1 - mult2;
            wire [mult_N_by_two - 1:0] mid_term_out_subtracted_shifted = mid_term_out_subtracted << half_of_N;
            wire [mult_N_by_two - 1:0] mult1_shifted = mult1 << N;
            
            assign y = mult1_shifted + mid_term_out_subtracted_shifted + mult2;    
        end
    endgenerate
endmodule

module base_mult(input [1:0] a,input [1:0] b, output [3:0] y);
    
    wire ac,bd;
    wire [1:0] ab,cd;
    
    and(ac,a[1],b[1]);
    and(bd,a[0],b[0]);
    
    assign ab = a[1] + a[0];
    assign cd = b[1] + b[0];
    
    ///////////////// (a+b).(c+d) ///////////////////
    wire ac2,bd2;
    wire ab2,cd2;
    
    wire [2:0] mid_term_out;
    
    wire ab2cd2;
    wire ab2cd2sub;
    
    and(ac2,ab[1],cd[1]);
    and(bd2,ab[0],cd[0]);
    
    assign ab2 = ab[1] + ab[0];
    assign cd2 = cd[1] + cd[0];
    
    and(ab2cd2,ab2,cd2);
    
    assign ab2cd2sub = ab2cd2 - ac2 - bd2;
    
    wire [2:0] ac2_shifted;
    wire [1:0] ab2cd2sub_shifted;
    
    assign ac2_shifted = ac << 2;
    assign ab2cd2sub_shifted = ab2cd2sub << 1;
    
    assign mid_term_out = ac2_shifted + ab2cd2sub_shifted + bd2;
    //////////////////////////////////////////////////
    
    wire [2:0] ac_shifted;
    assign ac_shifted = ac << 2;
    
    wire [1:0] mid_term_subtracted = mid_term_out - ac - bd;
    wire [2:0] mid_term_subtracted_shifted;
    assign mid_term_subtracted_shifted = mid_term_subtracted << 1;
    
    assign y = ac_shifted + mid_term_subtracted_shifted + bd;

endmodule