/*------------------------------------------------------------------------------
 * File          : Chip_Controller.sv
 * Project       : RTL
 * Author        : eplgda
 * Creation date : Feb 26, 2024
 * Description   :
 *------------------------------------------------------------------------------*/

module Chip_Controller (
input logic clk,
input logic rst,

input logic [511:0] inst,
input logic [299:0] read_fromFIFO,
output logic [3071:0] col_selector, // 1024*3 - 1 = 3071
output logic [191:0] row_selector, // 64*3 - 1 = 191
output logic flag_full_FIFO 
);

//////////////////////////////////////////////////////////////////////////////////important sizes 
/// localparam size_of_minimizer  = 5'b10100; // = 20 ; 
/// localparam size_of_instruction = 9'b100000000; // = 512;
localparam num_of_bits_in_read  = 9'b100111000; // = 312 ; //  150 bp + 12bits for read's index
/// localparam num_of_bits_in_ref  = 10'b1001011000; // = 600 ; //  300 bp
localparam [19:0] minimizer_of_crossbar = 20'b11110000111100001111 ; //needs to be set // size_of_minimizer - 1 = 20 - 1 =19

/// localparam num_of_bits_type_of_inst  = 2'b10; // = 2
/// localparam num_of_bits_input = 4'b1010; // = 10 ;
localparam num_of_rows_in_crossbar = 7'b1000000; // = 64
localparam num_of_cols_in_crossbar = 11'b10000000000; // = 1024
/// localparam num_of_bits_in_amount_of_minimizers = 5'b10110; // = 5 bit ///CHANGE!
/// localparam num_of_bits_minimizer_location = 4'b1000; // = 8

/// localparam num_of_bits_mini_and_loc = 6'b100000; // = 32

// TBD :  FIFO contains 5 lines - 60,61,62,63,64
localparam start_row_FIFO = 3'b001; // = first line of FIFO is 60
localparam end_row_FIFO = 3'b101; // = last line of FIFO is 64 

//////
localparam start_of_Start_Row = 479;
localparam end_of_Start_Row = 470;

localparam start_of_End_Row = 469;
localparam end_of_End_Row = 460;



///////////////////////////////////////////////////////////////////////////////////////////////////

localparam start_of_input1 = 509;
localparam end_of_input1 = 500;

localparam start_of_input2 = 499;
localparam end_of_input2 = 490;

localparam start_of_output = 489;
localparam end_of_output = 480;




//////////////////////////////

//different values of voltage that can be apply
localparam Vfloating  = 3'b000 ;
localparam Vr  = 3'b001 ;
localparam Vw1  = 3'b010 ;
localparam Vw0  = 3'b011 ;
localparam Vground  = 3'b110 ;
localparam Visolate  = 3'b101 ;
localparam Vmagic  = 3'b111 ;
localparam Vresistor = 3'b100;

//////

localparam VhelperOnes = 3'b111;
localparam VhelperZeros = 3'b000;

/////

logic flag_relevent_read;
logic flag_read_from_FIFO;
logic flag_done;


logic [7:0] location_of_minimizer; // num_of_bits_minimizer_location - 1 = 8 - 1 = 7
logic [311:0] current_read; //storing temporary read, num_of_bits_in_read - 1 = 312 - 1 = 311

logic [935:0] ones_positions; // num_of_bits_in_read*3 - 1 = 312*3 - 1 = 935
logic [935:0] zeros_positions;

logic counter_accepting_reads;
/// For the column counters we have 2 options : first - counting up to 3 because every row can contain 3 reads,in this case we must use additional ifs to the code, second - counting from 1024 down, so we need more bits
logic [1:0] counter_col_storage; // counting to 3
logic [2:0] counter_row_storage; // counting to 5
logic [1:0] counter_col_calc; // counting to 3
logic [2:0] counter_row_calc; // counting to 5



logic [191:0] start_row_selector; // 64*3 = 192 
logic [191:0] end_row_selector;

////////////////

logic [3071 : 0] start_col_selector;
logic [3071 : 0] end_col_selector;

logic [3071 : 0] input1_col_selector;
logic [3071 : 0] input2_col_selector;
logic [3071 : 0] output_col_selector;



//////



always_ff @(posedge clk or posedge rst) begin
	if (rst == 1'b1) begin
		col_selector <= {1024{Vw1}}; //{(num_of_cols_in_crossbar - num_of_bits_in_ref){Vw1}} = {(1024 - 600){Vw1}} = {424{Vw1}}
		row_selector <= {num_of_rows_in_crossbar{Vground}}; 
	
		ones_positions <= 936'd0;
		zeros_positions <= 936'd0;
		flag_full_FIFO <= 1'b0;
		flag_done <= 1'b0;
		
		counter_col_storage <= 2'b01;
		counter_row_storage <= 3'b001;
		counter_col_calc <= 2'b01;
		counter_row_calc <= 3'b001;
		
		start_col_selector <= 3072'd0;
		end_col_selector <= 3072'd0;
		
		start_row_selector <= 192'd0;
		end_row_selector <= 192'd0;
		
		input1_col_selector <= 3072'd0;
		input2_col_selector <= 3072'd0;
		output_col_selector <= 3072'd0;
		
		flag_read_from_FIFO <= 1'b0;
			
	
	end
	else begin

		if (inst[511:510] == 2'b10) begin // NOR calculation // inst[size_of_instruction-1:size_of_instruction - num_of_bits_type_of_inst] = inst[512-1:512 - 2] = inst[511:510] , /// (inst[511:510] == 2'b10)

			
		   //row_selector <= {{(num_of_rows_in_crossbar - inst[469:460]){Visolate}}, {(inst[469:460] - inst[479:470] + 1){Vfloating}}, {(inst[469:460]){Visolate}}};
		   //col_selector <= {{(num_of_cols_in_crossbar - inst[509:500]){Visolate}}, Vmagic, {(inst[509:500] - inst[499:490] - 1){Visolate}}, Vmagic, {(inst[499:490] - inst[489:480] - 1){Visolate}}, Vground, {(inst[489:480]){Visolate}}};





//////////////////////////////// 

if (inst[start_of_input1:end_of_input1] == 10'd1) begin
	start_col_selector <= {1024{VhelperZeros}};
	input1_col_selector <= {{VhelperOnes} , {1023{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd2) begin
	start_col_selector <= {{1{VhelperOnes}} , {1023{VhelperZeros}}};
	input1_col_selector <= {{1{VhelperZeros}} , {VhelperOnes} , {1022{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd3) begin
	start_col_selector <= {{2{VhelperOnes}} , {1022{VhelperZeros}}};
	input1_col_selector <= {{2{VhelperZeros}} , {VhelperOnes} , {1021{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd4) begin
	start_col_selector <= {{3{VhelperOnes}} , {1021{VhelperZeros}}};
	input1_col_selector <= {{3{VhelperZeros}} , {VhelperOnes} , {1020{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd5) begin
	start_col_selector <= {{4{VhelperOnes}} , {1020{VhelperZeros}}};
	input1_col_selector <= {{4{VhelperZeros}} , {VhelperOnes} , {1019{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd6) begin
	start_col_selector <= {{5{VhelperOnes}} , {1019{VhelperZeros}}};
	input1_col_selector <= {{5{VhelperZeros}} , {VhelperOnes} , {1018{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd7) begin
	start_col_selector <= {{6{VhelperOnes}} , {1018{VhelperZeros}}};
	input1_col_selector <= {{6{VhelperZeros}} , {VhelperOnes} , {1017{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd8) begin
	start_col_selector <= {{7{VhelperOnes}} , {1017{VhelperZeros}}};
	input1_col_selector <= {{7{VhelperZeros}} , {VhelperOnes} , {1016{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd9) begin
	start_col_selector <= {{8{VhelperOnes}} , {1016{VhelperZeros}}};
	input1_col_selector <= {{8{VhelperZeros}} , {VhelperOnes} , {1015{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd10) begin
	start_col_selector <= {{9{VhelperOnes}} , {1015{VhelperZeros}}};
	input1_col_selector <= {{9{VhelperZeros}} , {VhelperOnes} , {1014{VhelperZeros}}};	
end

else if (inst[start_of_input1:end_of_input1] == 10'd11) begin
	start_col_selector <= {{10{VhelperOnes}} , {1014{VhelperZeros}}};
	input1_col_selector <= {{10{VhelperZeros}} , {VhelperOnes} , {1013{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd12) begin
	start_col_selector <= {{11{VhelperOnes}} , {1013{VhelperZeros}}};
	input1_col_selector <= {{11{VhelperZeros}} , {VhelperOnes} , {1012{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd13) begin
	start_col_selector <= {{12{VhelperOnes}} , {1012{VhelperZeros}}};
	input1_col_selector <= {{12{VhelperZeros}} , {VhelperOnes} , {1011{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd14) begin
	start_col_selector <= {{13{VhelperOnes}} , {1011{VhelperZeros}}};
	input1_col_selector <= {{13{VhelperZeros}} , {VhelperOnes} , {1010{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd15) begin
	start_col_selector <= {{14{VhelperOnes}} , {1010{VhelperZeros}}};	
	input1_col_selector <= {{14{VhelperZeros}} , {VhelperOnes} , {1009{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd16) begin
	start_col_selector <= {{15{VhelperOnes}} , {1009{VhelperZeros}}};
	input1_col_selector <= {{15{VhelperZeros}} , {VhelperOnes} , {1008{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd17) begin
	start_col_selector <= {{16{VhelperOnes}} , {1008{VhelperZeros}}};
	input1_col_selector <= {{16{VhelperZeros}} , {VhelperOnes} , {1007{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd18) begin
	start_col_selector <= {{17{VhelperOnes}} , {1007{VhelperZeros}}};
	input1_col_selector <= {{17{VhelperZeros}} , {VhelperOnes} , {1006{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd19) begin
	start_col_selector <= {{18{VhelperOnes}} , {1006{VhelperZeros}}};
	input1_col_selector <= {{18{VhelperZeros}} , {VhelperOnes} , {1005{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd20) begin
	start_col_selector <= {{19{VhelperOnes}} , {1005{VhelperZeros}}};
	input1_col_selector <= {{19{VhelperZeros}} , {VhelperOnes} , {1004{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd21) begin
	start_col_selector <= {{20{VhelperOnes}} , {1004{VhelperZeros}}};
	input1_col_selector <= {{20{VhelperZeros}} , {VhelperOnes} , {1003{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd22) begin
	start_col_selector <= {{21{VhelperOnes}} , {1003{VhelperZeros}}};
	input1_col_selector <= {{21{VhelperZeros}} , {VhelperOnes} , {1002{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd23) begin
	start_col_selector <= {{22{VhelperOnes}} , {1002{VhelperZeros}}};
	input1_col_selector <= {{22{VhelperZeros}} , {VhelperOnes} , {1001{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd24) begin
	start_col_selector <= {{23{VhelperOnes}} , {1001{VhelperZeros}}};
	input1_col_selector <= {{23{VhelperZeros}} , {VhelperOnes} , {1000{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd25) begin
	start_col_selector <= {{24{VhelperOnes}} , {1000{VhelperZeros}}};	
	input1_col_selector <= {{24{VhelperZeros}} , {VhelperOnes} , {999{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd26) begin
	start_col_selector <= {{25{VhelperOnes}} , {999{VhelperZeros}}};
	input1_col_selector <= {{25{VhelperZeros}} , {VhelperOnes} , {998{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd27) begin
	start_col_selector <= {{26{VhelperOnes}} , {998{VhelperZeros}}};
	input1_col_selector <= {{26{VhelperZeros}} , {VhelperOnes} , {997{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd28) begin
	start_col_selector <= {{27{VhelperOnes}} , {997{VhelperZeros}}};
	input1_col_selector <= {{27{VhelperZeros}} , {VhelperOnes} , {996{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd29) begin
	start_col_selector <= {{28{VhelperOnes}} , {996{VhelperZeros}}};
	input1_col_selector <= {{28{VhelperZeros}} , {VhelperOnes} , {995{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd30) begin
	start_col_selector <= {{29{VhelperOnes}} , {995{VhelperZeros}}};
	input1_col_selector <= {{29{VhelperZeros}} , {VhelperOnes} , {994{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd31) begin
	start_col_selector <= {{30{VhelperOnes}} , {994{VhelperZeros}}};
	input1_col_selector <= {{30{VhelperZeros}} , {VhelperOnes} , {993{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd32) begin
	start_col_selector <= {{31{VhelperOnes}} , {993{VhelperZeros}}};
	input1_col_selector <= {{31{VhelperZeros}} , {VhelperOnes} , {992{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd33) begin
	start_col_selector <= {{32{VhelperOnes}} , {992{VhelperZeros}}};
	input1_col_selector <= {{32{VhelperZeros}} , {VhelperOnes} , {991{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd34) begin
	start_col_selector <= {{33{VhelperOnes}} , {991{VhelperZeros}}};
	input1_col_selector <= {{33{VhelperZeros}} , {VhelperOnes} , {990{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd35) begin
	start_col_selector <= {{34{VhelperOnes}} , {990{VhelperZeros}}};	
	input1_col_selector <= {{34{VhelperZeros}} , {VhelperOnes} , {989{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd36) begin
	start_col_selector <= {{35{VhelperOnes}} , {989{VhelperZeros}}};
	input1_col_selector <= {{35{VhelperZeros}} , {VhelperOnes} , {988{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd37) begin
	start_col_selector <= {{36{VhelperOnes}} , {988{VhelperZeros}}};
	input1_col_selector <= {{36{VhelperZeros}} , {VhelperOnes} , {987{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd38) begin
	start_col_selector <= {{37{VhelperOnes}} , {987{VhelperZeros}}};
	input1_col_selector <= {{37{VhelperZeros}} , {VhelperOnes} , {986{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd39) begin
	start_col_selector <= {{38{VhelperOnes}} , {986{VhelperZeros}}};
	input1_col_selector <= {{38{VhelperZeros}} , {VhelperOnes} , {985{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd40) begin
	start_col_selector <= {{39{VhelperOnes}} , {985{VhelperZeros}}};
	input1_col_selector <= {{39{VhelperZeros}} , {VhelperOnes} , {984{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd41) begin
	start_col_selector <= {{40{VhelperOnes}} , {984{VhelperZeros}}};
	input1_col_selector <= {{40{VhelperZeros}} , {VhelperOnes} , {983{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd42) begin
	start_col_selector <= {{41{VhelperOnes}} , {983{VhelperZeros}}};
	input1_col_selector <= {{41{VhelperZeros}} , {VhelperOnes} , {982{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd43) begin
	start_col_selector <= {{42{VhelperOnes}} , {982{VhelperZeros}}};
	input1_col_selector <= {{42{VhelperZeros}} , {VhelperOnes} , {981{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd44) begin
	start_col_selector <= {{43{VhelperOnes}} , {981{VhelperZeros}}};
	input1_col_selector <= {{43{VhelperZeros}} , {VhelperOnes} , {980{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd45) begin
	start_col_selector <= {{44{VhelperOnes}} , {980{VhelperZeros}}};	
	input1_col_selector <= {{44{VhelperZeros}} , {VhelperOnes} , {979{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd46) begin
	start_col_selector <= {{45{VhelperOnes}} , {979{VhelperZeros}}};
	input1_col_selector <= {{45{VhelperZeros}} , {VhelperOnes} , {978{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd47) begin
	start_col_selector <= {{46{VhelperOnes}} , {978{VhelperZeros}}};
	input1_col_selector <= {{46{VhelperZeros}} , {VhelperOnes} , {977{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd48) begin
	start_col_selector <= {{47{VhelperOnes}} , {977{VhelperZeros}}};
	input1_col_selector <= {{47{VhelperZeros}} , {VhelperOnes} , {976{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd49) begin
	start_col_selector <= {{48{VhelperOnes}} , {976{VhelperZeros}}};
	input1_col_selector <= {{48{VhelperZeros}} , {VhelperOnes} , {975{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd50) begin
	start_col_selector <= {{49{VhelperOnes}} , {975{VhelperZeros}}};
	input1_col_selector <= {{49{VhelperZeros}} , {VhelperOnes} , {974{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd51) begin
	start_col_selector <= {{50{VhelperOnes}} , {974{VhelperZeros}}};
	input1_col_selector <= {{50{VhelperZeros}} , {VhelperOnes} , {973{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd52) begin
	start_col_selector <= {{51{VhelperOnes}} , {973{VhelperZeros}}};
	input1_col_selector <= {{51{VhelperZeros}} , {VhelperOnes} , {972{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd53) begin
	start_col_selector <= {{52{VhelperOnes}} , {972{VhelperZeros}}};
	input1_col_selector <= {{52{VhelperZeros}} , {VhelperOnes} , {971{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd54) begin
	start_col_selector <= {{53{VhelperOnes}} , {971{VhelperZeros}}};
	input1_col_selector <= {{53{VhelperZeros}} , {VhelperOnes} , {970{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd55) begin
	start_col_selector <= {{54{VhelperOnes}} , {970{VhelperZeros}}};	
	input1_col_selector <= {{54{VhelperZeros}} , {VhelperOnes} , {969{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd56) begin
	start_col_selector <= {{55{VhelperOnes}} , {969{VhelperZeros}}};
	input1_col_selector <= {{55{VhelperZeros}} , {VhelperOnes} , {968{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd57) begin
	start_col_selector <= {{56{VhelperOnes}} , {968{VhelperZeros}}};
	input1_col_selector <= {{56{VhelperZeros}} , {VhelperOnes} , {967{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd58) begin
	start_col_selector <= {{57{VhelperOnes}} , {967{VhelperZeros}}};
	input1_col_selector <= {{57{VhelperZeros}} , {VhelperOnes} , {966{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd59) begin
	start_col_selector <= {{58{VhelperOnes}} , {966{VhelperZeros}}};
	input1_col_selector <= {{58{VhelperZeros}} , {VhelperOnes} , {965{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd60) begin
	start_col_selector <= {{59{VhelperOnes}} , {965{VhelperZeros}}};
	input1_col_selector <= {{59{VhelperZeros}} , {VhelperOnes} , {964{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd61) begin
	start_col_selector <= {{60{VhelperOnes}} , {964{VhelperZeros}}};
	input1_col_selector <= {{60{VhelperZeros}} , {VhelperOnes} , {963{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd62) begin
	start_col_selector <= {{61{VhelperOnes}} , {963{VhelperZeros}}};
	input1_col_selector <= {{61{VhelperZeros}} , {VhelperOnes} , {962{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd63) begin
	start_col_selector <= {{62{VhelperOnes}} , {962{VhelperZeros}}};
	input1_col_selector <= {{62{VhelperZeros}} , {VhelperOnes} , {961{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd64) begin
	start_col_selector <= {{63{VhelperOnes}} , {961{VhelperZeros}}};
	input1_col_selector <= {{63{VhelperZeros}} , {VhelperOnes} , {960{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd65) begin
	start_col_selector <= {{64{VhelperOnes}} , {960{VhelperZeros}}};	
	input1_col_selector <= {{64{VhelperZeros}} , {VhelperOnes} , {959{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd66) begin
	start_col_selector <= {{65{VhelperOnes}} , {959{VhelperZeros}}};
	input1_col_selector <= {{65{VhelperZeros}} , {VhelperOnes} , {958{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd67) begin
	start_col_selector <= {{66{VhelperOnes}} , {958{VhelperZeros}}};
	input1_col_selector <= {{66{VhelperZeros}} , {VhelperOnes} , {957{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd68) begin
	start_col_selector <= {{67{VhelperOnes}} , {957{VhelperZeros}}};
	input1_col_selector <= {{67{VhelperZeros}} , {VhelperOnes} , {956{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd69) begin
	start_col_selector <= {{68{VhelperOnes}} , {956{VhelperZeros}}};
	input1_col_selector <= {{68{VhelperZeros}} , {VhelperOnes} , {955{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd70) begin
	start_col_selector <= {{69{VhelperOnes}} , {955{VhelperZeros}}};
	input1_col_selector <= {{69{VhelperZeros}} , {VhelperOnes} , {954{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd71) begin
	start_col_selector <= {{70{VhelperOnes}} , {954{VhelperZeros}}};
	input1_col_selector <= {{70{VhelperZeros}} , {VhelperOnes} , {953{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd72) begin
	start_col_selector <= {{71{VhelperOnes}} , {953{VhelperZeros}}};
	input1_col_selector <= {{71{VhelperZeros}} , {VhelperOnes} , {952{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd73) begin
	start_col_selector <= {{72{VhelperOnes}} , {952{VhelperZeros}}};
	input1_col_selector <= {{72{VhelperZeros}} , {VhelperOnes} , {951{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd74) begin
	start_col_selector <= {{73{VhelperOnes}} , {951{VhelperZeros}}};
	input1_col_selector <= {{73{VhelperZeros}} , {VhelperOnes} , {950{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd75) begin
	start_col_selector <= {{74{VhelperOnes}} , {950{VhelperZeros}}};	
	input1_col_selector <= {{74{VhelperZeros}} , {VhelperOnes} , {949{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd76) begin
	start_col_selector <= {{75{VhelperOnes}} , {949{VhelperZeros}}};
	input1_col_selector <= {{75{VhelperZeros}} , {VhelperOnes} , {948{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd77) begin
	start_col_selector <= {{76{VhelperOnes}} , {948{VhelperZeros}}};
	input1_col_selector <= {{76{VhelperZeros}} , {VhelperOnes} , {947{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd78) begin
	start_col_selector <= {{77{VhelperOnes}} , {947{VhelperZeros}}};
	input1_col_selector <= {{77{VhelperZeros}} , {VhelperOnes} , {946{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd79) begin
	start_col_selector <= {{78{VhelperOnes}} , {946{VhelperZeros}}};
	input1_col_selector <= {{78{VhelperZeros}} , {VhelperOnes} , {945{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd80) begin
	start_col_selector <= {{79{VhelperOnes}} , {945{VhelperZeros}}};
	input1_col_selector <= {{79{VhelperZeros}} , {VhelperOnes} , {944{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd81) begin
	start_col_selector <= {{80{VhelperOnes}} , {944{VhelperZeros}}};
	input1_col_selector <= {{80{VhelperZeros}} , {VhelperOnes} , {943{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd82) begin
	start_col_selector <= {{81{VhelperOnes}} , {943{VhelperZeros}}};
	input1_col_selector <= {{81{VhelperZeros}} , {VhelperOnes} , {942{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd83) begin
	start_col_selector <= {{82{VhelperOnes}} , {942{VhelperZeros}}};
	input1_col_selector <= {{82{VhelperZeros}} , {VhelperOnes} , {941{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd84) begin
	start_col_selector <= {{83{VhelperOnes}} , {941{VhelperZeros}}};
	input1_col_selector <= {{83{VhelperZeros}} , {VhelperOnes} , {940{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd85) begin
	start_col_selector <= {{84{VhelperOnes}} , {940{VhelperZeros}}};	
	input1_col_selector <= {{84{VhelperZeros}} , {VhelperOnes} , {939{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd86) begin
	start_col_selector <= {{85{VhelperOnes}} , {939{VhelperZeros}}};
	input1_col_selector <= {{85{VhelperZeros}} , {VhelperOnes} , {938{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd87) begin
	start_col_selector <= {{86{VhelperOnes}} , {938{VhelperZeros}}};
	input1_col_selector <= {{86{VhelperZeros}} , {VhelperOnes} , {937{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd88) begin
	start_col_selector <= {{87{VhelperOnes}} , {937{VhelperZeros}}};
	input1_col_selector <= {{87{VhelperZeros}} , {VhelperOnes} , {936{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd89) begin
	start_col_selector <= {{88{VhelperOnes}} , {936{VhelperZeros}}};
	input1_col_selector <= {{88{VhelperZeros}} , {VhelperOnes} , {935{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd90) begin
	start_col_selector <= {{89{VhelperOnes}} , {935{VhelperZeros}}};
	input1_col_selector <= {{89{VhelperZeros}} , {VhelperOnes} , {934{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd91) begin
	start_col_selector <= {{90{VhelperOnes}} , {934{VhelperZeros}}};
	input1_col_selector <= {{90{VhelperZeros}} , {VhelperOnes} , {933{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd92) begin
	start_col_selector <= {{91{VhelperOnes}} , {933{VhelperZeros}}};
	input1_col_selector <= {{91{VhelperZeros}} , {VhelperOnes} , {932{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd93) begin
	start_col_selector <= {{92{VhelperOnes}} , {932{VhelperZeros}}};
	input1_col_selector <= {{92{VhelperZeros}} , {VhelperOnes} , {931{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd94) begin
	start_col_selector <= {{93{VhelperOnes}} , {931{VhelperZeros}}};
	input1_col_selector <= {{93{VhelperZeros}} , {VhelperOnes} , {930{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd95) begin
	start_col_selector <= {{94{VhelperOnes}} , {930{VhelperZeros}}};	
	input1_col_selector <= {{94{VhelperZeros}} , {VhelperOnes} , {929{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd96) begin
	start_col_selector <= {{95{VhelperOnes}} , {929{VhelperZeros}}};
	input1_col_selector <= {{95{VhelperZeros}} , {VhelperOnes} , {928{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd97) begin
	start_col_selector <= {{96{VhelperOnes}} , {928{VhelperZeros}}};
	input1_col_selector <= {{96{VhelperZeros}} , {VhelperOnes} , {927{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd98) begin
	start_col_selector <= {{97{VhelperOnes}} , {927{VhelperZeros}}};
	input1_col_selector <= {{97{VhelperZeros}} , {VhelperOnes} , {926{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd99) begin
	start_col_selector <= {{98{VhelperOnes}} , {926{VhelperZeros}}};
	input1_col_selector <= {{98{VhelperZeros}} , {VhelperOnes} , {925{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd100) begin
	start_col_selector <= {{99{VhelperOnes}} , {925{VhelperZeros}}};
	input1_col_selector <= {{99{VhelperZeros}} , {VhelperOnes} , {924{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd101) begin
	start_col_selector <= {{100{VhelperOnes}} , {924{VhelperZeros}}};
	input1_col_selector <= {{100{VhelperZeros}} , {VhelperOnes} , {923{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd102) begin
	start_col_selector <= {{101{VhelperOnes}} , {923{VhelperZeros}}};
	input1_col_selector <= {{101{VhelperZeros}} , {VhelperOnes} , {922{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd103) begin
	start_col_selector <= {{102{VhelperOnes}} , {922{VhelperZeros}}};
	input1_col_selector <= {{102{VhelperZeros}} , {VhelperOnes} , {921{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd104) begin
	start_col_selector <= {{103{VhelperOnes}} , {921{VhelperZeros}}};
	input1_col_selector <= {{103{VhelperZeros}} , {VhelperOnes} , {920{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd105) begin
	start_col_selector <= {{104{VhelperOnes}} , {920{VhelperZeros}}};	
	input1_col_selector <= {{104{VhelperZeros}} , {VhelperOnes} , {919{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd106) begin
	start_col_selector <= {{105{VhelperOnes}} , {919{VhelperZeros}}};
	input1_col_selector <= {{105{VhelperZeros}} , {VhelperOnes} , {918{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd107) begin
	start_col_selector <= {{106{VhelperOnes}} , {918{VhelperZeros}}};
	input1_col_selector <= {{106{VhelperZeros}} , {VhelperOnes} , {917{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd108) begin
	start_col_selector <= {{107{VhelperOnes}} , {917{VhelperZeros}}};
	input1_col_selector <= {{107{VhelperZeros}} , {VhelperOnes} , {916{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd109) begin
	start_col_selector <= {{108{VhelperOnes}} , {916{VhelperZeros}}};
	input1_col_selector <= {{108{VhelperZeros}} , {VhelperOnes} , {915{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd110) begin
	start_col_selector <= {{109{VhelperOnes}} , {915{VhelperZeros}}};
	input1_col_selector <= {{109{VhelperZeros}} , {VhelperOnes} , {914{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd111) begin
	start_col_selector <= {{110{VhelperOnes}} , {914{VhelperZeros}}};
	input1_col_selector <= {{110{VhelperZeros}} , {VhelperOnes} , {913{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd112) begin
	start_col_selector <= {{111{VhelperOnes}} , {913{VhelperZeros}}};
	input1_col_selector <= {{111{VhelperZeros}} , {VhelperOnes} , {912{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd113) begin
	start_col_selector <= {{112{VhelperOnes}} , {912{VhelperZeros}}};
	input1_col_selector <= {{112{VhelperZeros}} , {VhelperOnes} , {911{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd114) begin
	start_col_selector <= {{113{VhelperOnes}} , {911{VhelperZeros}}};
	input1_col_selector <= {{113{VhelperZeros}} , {VhelperOnes} , {910{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd115) begin
	start_col_selector <= {{114{VhelperOnes}} , {910{VhelperZeros}}};	
	input1_col_selector <= {{114{VhelperZeros}} , {VhelperOnes} , {909{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd116) begin
	start_col_selector <= {{115{VhelperOnes}} , {909{VhelperZeros}}};
	input1_col_selector <= {{115{VhelperZeros}} , {VhelperOnes} , {908{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd117) begin
	start_col_selector <= {{116{VhelperOnes}} , {908{VhelperZeros}}};
	input1_col_selector <= {{116{VhelperZeros}} , {VhelperOnes} , {907{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd118) begin
	start_col_selector <= {{117{VhelperOnes}} , {907{VhelperZeros}}};
	input1_col_selector <= {{117{VhelperZeros}} , {VhelperOnes} , {906{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd119) begin
	start_col_selector <= {{118{VhelperOnes}} , {906{VhelperZeros}}};
	input1_col_selector <= {{118{VhelperZeros}} , {VhelperOnes} , {905{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd120) begin
	start_col_selector <= {{119{VhelperOnes}} , {905{VhelperZeros}}};
	input1_col_selector <= {{119{VhelperZeros}} , {VhelperOnes} , {904{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd121) begin
	start_col_selector <= {{120{VhelperOnes}} , {904{VhelperZeros}}};
	input1_col_selector <= {{120{VhelperZeros}} , {VhelperOnes} , {903{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd122) begin
	start_col_selector <= {{121{VhelperOnes}} , {903{VhelperZeros}}};
	input1_col_selector <= {{121{VhelperZeros}} , {VhelperOnes} , {902{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd123) begin
	start_col_selector <= {{122{VhelperOnes}} , {902{VhelperZeros}}};
	input1_col_selector <= {{122{VhelperZeros}} , {VhelperOnes} , {901{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd124) begin
	start_col_selector <= {{123{VhelperOnes}} , {901{VhelperZeros}}};
	input1_col_selector <= {{123{VhelperZeros}} , {VhelperOnes} , {900{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd125) begin
	start_col_selector <= {{124{VhelperOnes}} , {900{VhelperZeros}}};	
	input1_col_selector <= {{124{VhelperZeros}} , {VhelperOnes} , {899{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd126) begin
	start_col_selector <= {{125{VhelperOnes}} , {899{VhelperZeros}}};
	input1_col_selector <= {{125{VhelperZeros}} , {VhelperOnes} , {898{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd127) begin
	start_col_selector <= {{126{VhelperOnes}} , {898{VhelperZeros}}};
	input1_col_selector <= {{126{VhelperZeros}} , {VhelperOnes} , {897{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd128) begin
	start_col_selector <= {{127{VhelperOnes}} , {897{VhelperZeros}}};
	input1_col_selector <= {{127{VhelperZeros}} , {VhelperOnes} , {896{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd129) begin
	start_col_selector <= {{128{VhelperOnes}} , {896{VhelperZeros}}};
	input1_col_selector <= {{128{VhelperZeros}} , {VhelperOnes} , {895{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd130) begin
	start_col_selector <= {{129{VhelperOnes}} , {895{VhelperZeros}}};
	input1_col_selector <= {{129{VhelperZeros}} , {VhelperOnes} , {894{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd131) begin
	start_col_selector <= {{130{VhelperOnes}} , {894{VhelperZeros}}};
	input1_col_selector <= {{130{VhelperZeros}} , {VhelperOnes} , {893{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd132) begin
	start_col_selector <= {{131{VhelperOnes}} , {893{VhelperZeros}}};
	input1_col_selector <= {{131{VhelperZeros}} , {VhelperOnes} , {892{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd133) begin
	start_col_selector <= {{132{VhelperOnes}} , {892{VhelperZeros}}};
	input1_col_selector <= {{132{VhelperZeros}} , {VhelperOnes} , {891{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd134) begin
	start_col_selector <= {{133{VhelperOnes}} , {891{VhelperZeros}}};
	input1_col_selector <= {{133{VhelperZeros}} , {VhelperOnes} , {890{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd135) begin
	start_col_selector <= {{134{VhelperOnes}} , {890{VhelperZeros}}};	
	input1_col_selector <= {{134{VhelperZeros}} , {VhelperOnes} , {889{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd136) begin
	start_col_selector <= {{135{VhelperOnes}} , {889{VhelperZeros}}};
	input1_col_selector <= {{135{VhelperZeros}} , {VhelperOnes} , {888{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd137) begin
	start_col_selector <= {{136{VhelperOnes}} , {888{VhelperZeros}}};
	input1_col_selector <= {{136{VhelperZeros}} , {VhelperOnes} , {887{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd138) begin
	start_col_selector <= {{137{VhelperOnes}} , {887{VhelperZeros}}};
	input1_col_selector <= {{137{VhelperZeros}} , {VhelperOnes} , {886{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd139) begin
	start_col_selector <= {{138{VhelperOnes}} , {886{VhelperZeros}}};
	input1_col_selector <= {{138{VhelperZeros}} , {VhelperOnes} , {885{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd140) begin
	start_col_selector <= {{139{VhelperOnes}} , {885{VhelperZeros}}};
	input1_col_selector <= {{139{VhelperZeros}} , {VhelperOnes} , {884{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd141) begin
	start_col_selector <= {{140{VhelperOnes}} , {884{VhelperZeros}}};
	input1_col_selector <= {{140{VhelperZeros}} , {VhelperOnes} , {883{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd142) begin
	start_col_selector <= {{141{VhelperOnes}} , {883{VhelperZeros}}};
	input1_col_selector <= {{141{VhelperZeros}} , {VhelperOnes} , {882{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd143) begin
	start_col_selector <= {{142{VhelperOnes}} , {882{VhelperZeros}}};
	input1_col_selector <= {{142{VhelperZeros}} , {VhelperOnes} , {881{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd144) begin
	start_col_selector <= {{143{VhelperOnes}} , {881{VhelperZeros}}};
	input1_col_selector <= {{143{VhelperZeros}} , {VhelperOnes} , {880{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd145) begin
	start_col_selector <= {{144{VhelperOnes}} , {880{VhelperZeros}}};	
	input1_col_selector <= {{144{VhelperZeros}} , {VhelperOnes} , {879{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd146) begin
	start_col_selector <= {{145{VhelperOnes}} , {879{VhelperZeros}}};
	input1_col_selector <= {{145{VhelperZeros}} , {VhelperOnes} , {878{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd147) begin
	start_col_selector <= {{146{VhelperOnes}} , {878{VhelperZeros}}};
	input1_col_selector <= {{146{VhelperZeros}} , {VhelperOnes} , {877{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd148) begin
	start_col_selector <= {{147{VhelperOnes}} , {877{VhelperZeros}}};
	input1_col_selector <= {{147{VhelperZeros}} , {VhelperOnes} , {876{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd149) begin
	start_col_selector <= {{148{VhelperOnes}} , {876{VhelperZeros}}};
	input1_col_selector <= {{148{VhelperZeros}} , {VhelperOnes} , {875{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd150) begin
	start_col_selector <= {{149{VhelperOnes}} , {875{VhelperZeros}}};
	input1_col_selector <= {{149{VhelperZeros}} , {VhelperOnes} , {874{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd151) begin
	start_col_selector <= {{150{VhelperOnes}} , {874{VhelperZeros}}};
	input1_col_selector <= {{150{VhelperZeros}} , {VhelperOnes} , {873{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd152) begin
	start_col_selector <= {{151{VhelperOnes}} , {873{VhelperZeros}}};
	input1_col_selector <= {{151{VhelperZeros}} , {VhelperOnes} , {872{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd153) begin
	start_col_selector <= {{152{VhelperOnes}} , {872{VhelperZeros}}};
	input1_col_selector <= {{152{VhelperZeros}} , {VhelperOnes} , {871{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd154) begin
	start_col_selector <= {{153{VhelperOnes}} , {871{VhelperZeros}}};
	input1_col_selector <= {{153{VhelperZeros}} , {VhelperOnes} , {870{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd155) begin
	start_col_selector <= {{154{VhelperOnes}} , {870{VhelperZeros}}};	
	input1_col_selector <= {{154{VhelperZeros}} , {VhelperOnes} , {869{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd156) begin
	start_col_selector <= {{155{VhelperOnes}} , {869{VhelperZeros}}};
	input1_col_selector <= {{155{VhelperZeros}} , {VhelperOnes} , {868{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd157) begin
	start_col_selector <= {{156{VhelperOnes}} , {868{VhelperZeros}}};
	input1_col_selector <= {{156{VhelperZeros}} , {VhelperOnes} , {867{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd158) begin
	start_col_selector <= {{157{VhelperOnes}} , {867{VhelperZeros}}};
	input1_col_selector <= {{157{VhelperZeros}} , {VhelperOnes} , {866{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd159) begin
	start_col_selector <= {{158{VhelperOnes}} , {866{VhelperZeros}}};
	input1_col_selector <= {{158{VhelperZeros}} , {VhelperOnes} , {865{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd160) begin
	start_col_selector <= {{159{VhelperOnes}} , {865{VhelperZeros}}};
	input1_col_selector <= {{159{VhelperZeros}} , {VhelperOnes} , {864{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd161) begin
	start_col_selector <= {{160{VhelperOnes}} , {864{VhelperZeros}}};
	input1_col_selector <= {{160{VhelperZeros}} , {VhelperOnes} , {863{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd162) begin
	start_col_selector <= {{161{VhelperOnes}} , {863{VhelperZeros}}};
	input1_col_selector <= {{161{VhelperZeros}} , {VhelperOnes} , {862{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd163) begin
	start_col_selector <= {{162{VhelperOnes}} , {862{VhelperZeros}}};
	input1_col_selector <= {{162{VhelperZeros}} , {VhelperOnes} , {861{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd164) begin
	start_col_selector <= {{163{VhelperOnes}} , {861{VhelperZeros}}};
	input1_col_selector <= {{163{VhelperZeros}} , {VhelperOnes} , {860{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd165) begin
	start_col_selector <= {{164{VhelperOnes}} , {860{VhelperZeros}}};	
	input1_col_selector <= {{164{VhelperZeros}} , {VhelperOnes} , {859{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd166) begin
	start_col_selector <= {{165{VhelperOnes}} , {859{VhelperZeros}}};
	input1_col_selector <= {{165{VhelperZeros}} , {VhelperOnes} , {858{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd167) begin
	start_col_selector <= {{166{VhelperOnes}} , {858{VhelperZeros}}};
	input1_col_selector <= {{166{VhelperZeros}} , {VhelperOnes} , {857{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd168) begin
	start_col_selector <= {{167{VhelperOnes}} , {857{VhelperZeros}}};
	input1_col_selector <= {{167{VhelperZeros}} , {VhelperOnes} , {856{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd169) begin
	start_col_selector <= {{168{VhelperOnes}} , {856{VhelperZeros}}};
	input1_col_selector <= {{168{VhelperZeros}} , {VhelperOnes} , {855{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd170) begin
	start_col_selector <= {{169{VhelperOnes}} , {855{VhelperZeros}}};
	input1_col_selector <= {{169{VhelperZeros}} , {VhelperOnes} , {854{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd171) begin
	start_col_selector <= {{170{VhelperOnes}} , {854{VhelperZeros}}};
	input1_col_selector <= {{170{VhelperZeros}} , {VhelperOnes} , {853{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd172) begin
	start_col_selector <= {{171{VhelperOnes}} , {853{VhelperZeros}}};
	input1_col_selector <= {{171{VhelperZeros}} , {VhelperOnes} , {852{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd173) begin
	start_col_selector <= {{172{VhelperOnes}} , {852{VhelperZeros}}};
	input1_col_selector <= {{172{VhelperZeros}} , {VhelperOnes} , {851{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd174) begin
	start_col_selector <= {{173{VhelperOnes}} , {851{VhelperZeros}}};
	input1_col_selector <= {{173{VhelperZeros}} , {VhelperOnes} , {850{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd175) begin
	start_col_selector <= {{174{VhelperOnes}} , {850{VhelperZeros}}};	
	input1_col_selector <= {{174{VhelperZeros}} , {VhelperOnes} , {849{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd176) begin
	start_col_selector <= {{175{VhelperOnes}} , {849{VhelperZeros}}};
	input1_col_selector <= {{175{VhelperZeros}} , {VhelperOnes} , {848{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd177) begin
	start_col_selector <= {{176{VhelperOnes}} , {848{VhelperZeros}}};
	input1_col_selector <= {{176{VhelperZeros}} , {VhelperOnes} , {847{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd178) begin
	start_col_selector <= {{177{VhelperOnes}} , {847{VhelperZeros}}};
	input1_col_selector <= {{177{VhelperZeros}} , {VhelperOnes} , {846{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd179) begin
	start_col_selector <= {{178{VhelperOnes}} , {846{VhelperZeros}}};
	input1_col_selector <= {{178{VhelperZeros}} , {VhelperOnes} , {845{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd180) begin
	start_col_selector <= {{179{VhelperOnes}} , {845{VhelperZeros}}};
	input1_col_selector <= {{179{VhelperZeros}} , {VhelperOnes} , {844{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd181) begin
	start_col_selector <= {{180{VhelperOnes}} , {844{VhelperZeros}}};
	input1_col_selector <= {{180{VhelperZeros}} , {VhelperOnes} , {843{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd182) begin
	start_col_selector <= {{181{VhelperOnes}} , {843{VhelperZeros}}};
	input1_col_selector <= {{181{VhelperZeros}} , {VhelperOnes} , {842{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd183) begin
	start_col_selector <= {{182{VhelperOnes}} , {842{VhelperZeros}}};
	input1_col_selector <= {{182{VhelperZeros}} , {VhelperOnes} , {841{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd184) begin
	start_col_selector <= {{183{VhelperOnes}} , {841{VhelperZeros}}};
	input1_col_selector <= {{183{VhelperZeros}} , {VhelperOnes} , {840{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd185) begin
	start_col_selector <= {{184{VhelperOnes}} , {840{VhelperZeros}}};	
	input1_col_selector <= {{184{VhelperZeros}} , {VhelperOnes} , {839{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd186) begin
	start_col_selector <= {{185{VhelperOnes}} , {839{VhelperZeros}}};
	input1_col_selector <= {{185{VhelperZeros}} , {VhelperOnes} , {838{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd187) begin
	start_col_selector <= {{186{VhelperOnes}} , {838{VhelperZeros}}};
	input1_col_selector <= {{186{VhelperZeros}} , {VhelperOnes} , {837{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd188) begin
	start_col_selector <= {{187{VhelperOnes}} , {837{VhelperZeros}}};
	input1_col_selector <= {{187{VhelperZeros}} , {VhelperOnes} , {836{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd189) begin
	start_col_selector <= {{188{VhelperOnes}} , {836{VhelperZeros}}};
	input1_col_selector <= {{188{VhelperZeros}} , {VhelperOnes} , {835{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd190) begin
	start_col_selector <= {{189{VhelperOnes}} , {835{VhelperZeros}}};
	input1_col_selector <= {{189{VhelperZeros}} , {VhelperOnes} , {834{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd191) begin
	start_col_selector <= {{190{VhelperOnes}} , {834{VhelperZeros}}};
	input1_col_selector <= {{190{VhelperZeros}} , {VhelperOnes} , {833{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd192) begin
	start_col_selector <= {{191{VhelperOnes}} , {833{VhelperZeros}}};
	input1_col_selector <= {{191{VhelperZeros}} , {VhelperOnes} , {832{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd193) begin
	start_col_selector <= {{192{VhelperOnes}} , {832{VhelperZeros}}};
	input1_col_selector <= {{192{VhelperZeros}} , {VhelperOnes} , {831{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd194) begin
	start_col_selector <= {{193{VhelperOnes}} , {831{VhelperZeros}}};
	input1_col_selector <= {{193{VhelperZeros}} , {VhelperOnes} , {830{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd195) begin
	start_col_selector <= {{194{VhelperOnes}} , {830{VhelperZeros}}};	
	input1_col_selector <= {{194{VhelperZeros}} , {VhelperOnes} , {829{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd196) begin
	start_col_selector <= {{195{VhelperOnes}} , {829{VhelperZeros}}};
	input1_col_selector <= {{195{VhelperZeros}} , {VhelperOnes} , {828{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd197) begin
	start_col_selector <= {{196{VhelperOnes}} , {828{VhelperZeros}}};
	input1_col_selector <= {{196{VhelperZeros}} , {VhelperOnes} , {827{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd198) begin
	start_col_selector <= {{197{VhelperOnes}} , {827{VhelperZeros}}};
	input1_col_selector <= {{197{VhelperZeros}} , {VhelperOnes} , {826{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd199) begin
	start_col_selector <= {{198{VhelperOnes}} , {826{VhelperZeros}}};
	input1_col_selector <= {{198{VhelperZeros}} , {VhelperOnes} , {825{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd200) begin
	start_col_selector <= {{199{VhelperOnes}} , {825{VhelperZeros}}};
	input1_col_selector <= {{199{VhelperZeros}} , {VhelperOnes} , {824{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd201) begin
	start_col_selector <= {{200{VhelperOnes}} , {824{VhelperZeros}}};
	input1_col_selector <= {{200{VhelperZeros}} , {VhelperOnes} , {823{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd202) begin
	start_col_selector <= {{201{VhelperOnes}} , {823{VhelperZeros}}};
	input1_col_selector <= {{201{VhelperZeros}} , {VhelperOnes} , {822{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd203) begin
	start_col_selector <= {{202{VhelperOnes}} , {822{VhelperZeros}}};
	input1_col_selector <= {{202{VhelperZeros}} , {VhelperOnes} , {821{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd204) begin
	start_col_selector <= {{203{VhelperOnes}} , {821{VhelperZeros}}};
	input1_col_selector <= {{203{VhelperZeros}} , {VhelperOnes} , {820{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd205) begin
	start_col_selector <= {{204{VhelperOnes}} , {820{VhelperZeros}}};	
	input1_col_selector <= {{204{VhelperZeros}} , {VhelperOnes} , {819{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd206) begin
	start_col_selector <= {{205{VhelperOnes}} , {819{VhelperZeros}}};
	input1_col_selector <= {{205{VhelperZeros}} , {VhelperOnes} , {818{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd207) begin
	start_col_selector <= {{206{VhelperOnes}} , {818{VhelperZeros}}};
	input1_col_selector <= {{206{VhelperZeros}} , {VhelperOnes} , {817{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd208) begin
	start_col_selector <= {{207{VhelperOnes}} , {817{VhelperZeros}}};
	input1_col_selector <= {{207{VhelperZeros}} , {VhelperOnes} , {816{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd209) begin
	start_col_selector <= {{208{VhelperOnes}} , {816{VhelperZeros}}};
	input1_col_selector <= {{208{VhelperZeros}} , {VhelperOnes} , {815{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd210) begin
	start_col_selector <= {{209{VhelperOnes}} , {815{VhelperZeros}}};
	input1_col_selector <= {{209{VhelperZeros}} , {VhelperOnes} , {814{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd211) begin
	start_col_selector <= {{210{VhelperOnes}} , {814{VhelperZeros}}};
	input1_col_selector <= {{210{VhelperZeros}} , {VhelperOnes} , {813{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd212) begin
	start_col_selector <= {{211{VhelperOnes}} , {813{VhelperZeros}}};
	input1_col_selector <= {{211{VhelperZeros}} , {VhelperOnes} , {812{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd213) begin
	start_col_selector <= {{212{VhelperOnes}} , {812{VhelperZeros}}};
	input1_col_selector <= {{212{VhelperZeros}} , {VhelperOnes} , {811{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd214) begin
	start_col_selector <= {{213{VhelperOnes}} , {811{VhelperZeros}}};
	input1_col_selector <= {{213{VhelperZeros}} , {VhelperOnes} , {810{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd215) begin
	start_col_selector <= {{214{VhelperOnes}} , {810{VhelperZeros}}};	
	input1_col_selector <= {{214{VhelperZeros}} , {VhelperOnes} , {809{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd216) begin
	start_col_selector <= {{215{VhelperOnes}} , {809{VhelperZeros}}};
	input1_col_selector <= {{215{VhelperZeros}} , {VhelperOnes} , {808{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd217) begin
	start_col_selector <= {{216{VhelperOnes}} , {808{VhelperZeros}}};
	input1_col_selector <= {{216{VhelperZeros}} , {VhelperOnes} , {807{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd218) begin
	start_col_selector <= {{217{VhelperOnes}} , {807{VhelperZeros}}};
	input1_col_selector <= {{217{VhelperZeros}} , {VhelperOnes} , {806{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd219) begin
	start_col_selector <= {{218{VhelperOnes}} , {806{VhelperZeros}}};
	input1_col_selector <= {{218{VhelperZeros}} , {VhelperOnes} , {805{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd220) begin
	start_col_selector <= {{219{VhelperOnes}} , {805{VhelperZeros}}};
	input1_col_selector <= {{219{VhelperZeros}} , {VhelperOnes} , {804{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd221) begin
	start_col_selector <= {{220{VhelperOnes}} , {804{VhelperZeros}}};
	input1_col_selector <= {{220{VhelperZeros}} , {VhelperOnes} , {803{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd222) begin
	start_col_selector <= {{221{VhelperOnes}} , {803{VhelperZeros}}};
	input1_col_selector <= {{221{VhelperZeros}} , {VhelperOnes} , {802{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd223) begin
	start_col_selector <= {{222{VhelperOnes}} , {802{VhelperZeros}}};
	input1_col_selector <= {{222{VhelperZeros}} , {VhelperOnes} , {801{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd224) begin
	start_col_selector <= {{223{VhelperOnes}} , {801{VhelperZeros}}};
	input1_col_selector <= {{223{VhelperZeros}} , {VhelperOnes} , {800{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd225) begin
	start_col_selector <= {{224{VhelperOnes}} , {800{VhelperZeros}}};	
	input1_col_selector <= {{224{VhelperZeros}} , {VhelperOnes} , {799{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd226) begin
	start_col_selector <= {{225{VhelperOnes}} , {799{VhelperZeros}}};
	input1_col_selector <= {{225{VhelperZeros}} , {VhelperOnes} , {798{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd227) begin
	start_col_selector <= {{226{VhelperOnes}} , {798{VhelperZeros}}};
	input1_col_selector <= {{226{VhelperZeros}} , {VhelperOnes} , {797{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd228) begin
	start_col_selector <= {{227{VhelperOnes}} , {797{VhelperZeros}}};
	input1_col_selector <= {{227{VhelperZeros}} , {VhelperOnes} , {796{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd229) begin
	start_col_selector <= {{228{VhelperOnes}} , {796{VhelperZeros}}};
	input1_col_selector <= {{228{VhelperZeros}} , {VhelperOnes} , {795{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd230) begin
	start_col_selector <= {{229{VhelperOnes}} , {795{VhelperZeros}}};
	input1_col_selector <= {{229{VhelperZeros}} , {VhelperOnes} , {794{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd231) begin
	start_col_selector <= {{230{VhelperOnes}} , {794{VhelperZeros}}};
	input1_col_selector <= {{230{VhelperZeros}} , {VhelperOnes} , {793{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd232) begin
	start_col_selector <= {{231{VhelperOnes}} , {793{VhelperZeros}}};
	input1_col_selector <= {{231{VhelperZeros}} , {VhelperOnes} , {792{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd233) begin
	start_col_selector <= {{232{VhelperOnes}} , {792{VhelperZeros}}};
	input1_col_selector <= {{232{VhelperZeros}} , {VhelperOnes} , {791{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd234) begin
	start_col_selector <= {{233{VhelperOnes}} , {791{VhelperZeros}}};
	input1_col_selector <= {{233{VhelperZeros}} , {VhelperOnes} , {790{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd235) begin
	start_col_selector <= {{234{VhelperOnes}} , {790{VhelperZeros}}};	
	input1_col_selector <= {{234{VhelperZeros}} , {VhelperOnes} , {789{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd236) begin
	start_col_selector <= {{235{VhelperOnes}} , {789{VhelperZeros}}};
	input1_col_selector <= {{235{VhelperZeros}} , {VhelperOnes} , {788{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd237) begin
	start_col_selector <= {{236{VhelperOnes}} , {788{VhelperZeros}}};
	input1_col_selector <= {{236{VhelperZeros}} , {VhelperOnes} , {787{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd238) begin
	start_col_selector <= {{237{VhelperOnes}} , {787{VhelperZeros}}};
	input1_col_selector <= {{237{VhelperZeros}} , {VhelperOnes} , {786{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd239) begin
	start_col_selector <= {{238{VhelperOnes}} , {786{VhelperZeros}}};
	input1_col_selector <= {{238{VhelperZeros}} , {VhelperOnes} , {785{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd240) begin
	start_col_selector <= {{239{VhelperOnes}} , {785{VhelperZeros}}};
	input1_col_selector <= {{239{VhelperZeros}} , {VhelperOnes} , {784{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd241) begin
	start_col_selector <= {{240{VhelperOnes}} , {784{VhelperZeros}}};
	input1_col_selector <= {{240{VhelperZeros}} , {VhelperOnes} , {783{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd242) begin
	start_col_selector <= {{241{VhelperOnes}} , {783{VhelperZeros}}};
	input1_col_selector <= {{241{VhelperZeros}} , {VhelperOnes} , {782{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd243) begin
	start_col_selector <= {{242{VhelperOnes}} , {782{VhelperZeros}}};
	input1_col_selector <= {{242{VhelperZeros}} , {VhelperOnes} , {781{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd244) begin
	start_col_selector <= {{243{VhelperOnes}} , {781{VhelperZeros}}};
	input1_col_selector <= {{243{VhelperZeros}} , {VhelperOnes} , {780{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd245) begin
	start_col_selector <= {{244{VhelperOnes}} , {780{VhelperZeros}}};	
	input1_col_selector <= {{244{VhelperZeros}} , {VhelperOnes} , {779{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd246) begin
	start_col_selector <= {{245{VhelperOnes}} , {779{VhelperZeros}}};
	input1_col_selector <= {{245{VhelperZeros}} , {VhelperOnes} , {778{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd247) begin
	start_col_selector <= {{246{VhelperOnes}} , {778{VhelperZeros}}};
	input1_col_selector <= {{246{VhelperZeros}} , {VhelperOnes} , {777{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd248) begin
	start_col_selector <= {{247{VhelperOnes}} , {777{VhelperZeros}}};
	input1_col_selector <= {{247{VhelperZeros}} , {VhelperOnes} , {776{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd249) begin
	start_col_selector <= {{248{VhelperOnes}} , {776{VhelperZeros}}};
	input1_col_selector <= {{248{VhelperZeros}} , {VhelperOnes} , {775{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd250) begin
	start_col_selector <= {{249{VhelperOnes}} , {775{VhelperZeros}}};
	input1_col_selector <= {{249{VhelperZeros}} , {VhelperOnes} , {774{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd251) begin
	start_col_selector <= {{250{VhelperOnes}} , {774{VhelperZeros}}};
	input1_col_selector <= {{250{VhelperZeros}} , {VhelperOnes} , {773{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd252) begin
	start_col_selector <= {{251{VhelperOnes}} , {773{VhelperZeros}}};
	input1_col_selector <= {{251{VhelperZeros}} , {VhelperOnes} , {772{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd253) begin
	start_col_selector <= {{252{VhelperOnes}} , {772{VhelperZeros}}};
	input1_col_selector <= {{252{VhelperZeros}} , {VhelperOnes} , {771{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd254) begin
	start_col_selector <= {{253{VhelperOnes}} , {771{VhelperZeros}}};
	input1_col_selector <= {{253{VhelperZeros}} , {VhelperOnes} , {770{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd255) begin
	start_col_selector <= {{254{VhelperOnes}} , {770{VhelperZeros}}};	
	input1_col_selector <= {{254{VhelperZeros}} , {VhelperOnes} , {769{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd256) begin
	start_col_selector <= {{255{VhelperOnes}} , {769{VhelperZeros}}};
	input1_col_selector <= {{255{VhelperZeros}} , {VhelperOnes} , {768{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd257) begin
	start_col_selector <= {{256{VhelperOnes}} , {768{VhelperZeros}}};
	input1_col_selector <= {{256{VhelperZeros}} , {VhelperOnes} , {767{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd258) begin
	start_col_selector <= {{257{VhelperOnes}} , {767{VhelperZeros}}};
	input1_col_selector <= {{257{VhelperZeros}} , {VhelperOnes} , {766{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd259) begin
	start_col_selector <= {{258{VhelperOnes}} , {766{VhelperZeros}}};
	input1_col_selector <= {{258{VhelperZeros}} , {VhelperOnes} , {765{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd260) begin
	start_col_selector <= {{259{VhelperOnes}} , {765{VhelperZeros}}};
	input1_col_selector <= {{259{VhelperZeros}} , {VhelperOnes} , {764{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd261) begin
	start_col_selector <= {{260{VhelperOnes}} , {764{VhelperZeros}}};
	input1_col_selector <= {{260{VhelperZeros}} , {VhelperOnes} , {763{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd262) begin
	start_col_selector <= {{261{VhelperOnes}} , {763{VhelperZeros}}};
	input1_col_selector <= {{261{VhelperZeros}} , {VhelperOnes} , {762{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd263) begin
	start_col_selector <= {{262{VhelperOnes}} , {762{VhelperZeros}}};
	input1_col_selector <= {{262{VhelperZeros}} , {VhelperOnes} , {761{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd264) begin
	start_col_selector <= {{263{VhelperOnes}} , {761{VhelperZeros}}};
	input1_col_selector <= {{263{VhelperZeros}} , {VhelperOnes} , {760{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd265) begin
	start_col_selector <= {{264{VhelperOnes}} , {760{VhelperZeros}}};	
	input1_col_selector <= {{264{VhelperZeros}} , {VhelperOnes} , {759{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd266) begin
	start_col_selector <= {{265{VhelperOnes}} , {759{VhelperZeros}}};
	input1_col_selector <= {{265{VhelperZeros}} , {VhelperOnes} , {758{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd267) begin
	start_col_selector <= {{266{VhelperOnes}} , {758{VhelperZeros}}};
	input1_col_selector <= {{266{VhelperZeros}} , {VhelperOnes} , {757{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd268) begin
	start_col_selector <= {{267{VhelperOnes}} , {757{VhelperZeros}}};
	input1_col_selector <= {{267{VhelperZeros}} , {VhelperOnes} , {756{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd269) begin
	start_col_selector <= {{268{VhelperOnes}} , {756{VhelperZeros}}};
	input1_col_selector <= {{268{VhelperZeros}} , {VhelperOnes} , {755{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd270) begin
	start_col_selector <= {{269{VhelperOnes}} , {755{VhelperZeros}}};
	input1_col_selector <= {{269{VhelperZeros}} , {VhelperOnes} , {754{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd271) begin
	start_col_selector <= {{270{VhelperOnes}} , {754{VhelperZeros}}};
	input1_col_selector <= {{270{VhelperZeros}} , {VhelperOnes} , {753{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd272) begin
	start_col_selector <= {{271{VhelperOnes}} , {753{VhelperZeros}}};
	input1_col_selector <= {{271{VhelperZeros}} , {VhelperOnes} , {752{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd273) begin
	start_col_selector <= {{272{VhelperOnes}} , {752{VhelperZeros}}};
	input1_col_selector <= {{272{VhelperZeros}} , {VhelperOnes} , {751{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd274) begin
	start_col_selector <= {{273{VhelperOnes}} , {751{VhelperZeros}}};
	input1_col_selector <= {{273{VhelperZeros}} , {VhelperOnes} , {750{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd275) begin
	start_col_selector <= {{274{VhelperOnes}} , {750{VhelperZeros}}};	
	input1_col_selector <= {{274{VhelperZeros}} , {VhelperOnes} , {749{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd276) begin
	start_col_selector <= {{275{VhelperOnes}} , {749{VhelperZeros}}};
	input1_col_selector <= {{275{VhelperZeros}} , {VhelperOnes} , {748{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd277) begin
	start_col_selector <= {{276{VhelperOnes}} , {748{VhelperZeros}}};
	input1_col_selector <= {{276{VhelperZeros}} , {VhelperOnes} , {747{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd278) begin
	start_col_selector <= {{277{VhelperOnes}} , {747{VhelperZeros}}};
	input1_col_selector <= {{277{VhelperZeros}} , {VhelperOnes} , {746{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd279) begin
	start_col_selector <= {{278{VhelperOnes}} , {746{VhelperZeros}}};
	input1_col_selector <= {{278{VhelperZeros}} , {VhelperOnes} , {745{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd280) begin
	start_col_selector <= {{279{VhelperOnes}} , {745{VhelperZeros}}};
	input1_col_selector <= {{279{VhelperZeros}} , {VhelperOnes} , {744{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd281) begin
	start_col_selector <= {{280{VhelperOnes}} , {744{VhelperZeros}}};
	input1_col_selector <= {{280{VhelperZeros}} , {VhelperOnes} , {743{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd282) begin
	start_col_selector <= {{281{VhelperOnes}} , {743{VhelperZeros}}};
	input1_col_selector <= {{281{VhelperZeros}} , {VhelperOnes} , {742{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd283) begin
	start_col_selector <= {{282{VhelperOnes}} , {742{VhelperZeros}}};
	input1_col_selector <= {{282{VhelperZeros}} , {VhelperOnes} , {741{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd284) begin
	start_col_selector <= {{283{VhelperOnes}} , {741{VhelperZeros}}};
	input1_col_selector <= {{283{VhelperZeros}} , {VhelperOnes} , {740{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd285) begin
	start_col_selector <= {{284{VhelperOnes}} , {740{VhelperZeros}}};	
	input1_col_selector <= {{284{VhelperZeros}} , {VhelperOnes} , {739{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd286) begin
	start_col_selector <= {{285{VhelperOnes}} , {739{VhelperZeros}}};
	input1_col_selector <= {{285{VhelperZeros}} , {VhelperOnes} , {738{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd287) begin
	start_col_selector <= {{286{VhelperOnes}} , {738{VhelperZeros}}};
	input1_col_selector <= {{286{VhelperZeros}} , {VhelperOnes} , {737{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd288) begin
	start_col_selector <= {{287{VhelperOnes}} , {737{VhelperZeros}}};
	input1_col_selector <= {{287{VhelperZeros}} , {VhelperOnes} , {736{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd289) begin
	start_col_selector <= {{288{VhelperOnes}} , {736{VhelperZeros}}};
	input1_col_selector <= {{288{VhelperZeros}} , {VhelperOnes} , {735{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd290) begin
	start_col_selector <= {{289{VhelperOnes}} , {735{VhelperZeros}}};
	input1_col_selector <= {{289{VhelperZeros}} , {VhelperOnes} , {734{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd291) begin
	start_col_selector <= {{290{VhelperOnes}} , {734{VhelperZeros}}};
	input1_col_selector <= {{290{VhelperZeros}} , {VhelperOnes} , {733{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd292) begin
	start_col_selector <= {{291{VhelperOnes}} , {733{VhelperZeros}}};
	input1_col_selector <= {{291{VhelperZeros}} , {VhelperOnes} , {732{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd293) begin
	start_col_selector <= {{292{VhelperOnes}} , {732{VhelperZeros}}};
	input1_col_selector <= {{292{VhelperZeros}} , {VhelperOnes} , {731{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd294) begin
	start_col_selector <= {{293{VhelperOnes}} , {731{VhelperZeros}}};
	input1_col_selector <= {{293{VhelperZeros}} , {VhelperOnes} , {730{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd295) begin
	start_col_selector <= {{294{VhelperOnes}} , {730{VhelperZeros}}};	
	input1_col_selector <= {{294{VhelperZeros}} , {VhelperOnes} , {729{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd296) begin
	start_col_selector <= {{295{VhelperOnes}} , {729{VhelperZeros}}};
	input1_col_selector <= {{295{VhelperZeros}} , {VhelperOnes} , {728{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd297) begin
	start_col_selector <= {{296{VhelperOnes}} , {728{VhelperZeros}}};
	input1_col_selector <= {{296{VhelperZeros}} , {VhelperOnes} , {727{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd298) begin
	start_col_selector <= {{297{VhelperOnes}} , {727{VhelperZeros}}};
	input1_col_selector <= {{297{VhelperZeros}} , {VhelperOnes} , {726{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd299) begin
	start_col_selector <= {{298{VhelperOnes}} , {726{VhelperZeros}}};
	input1_col_selector <= {{298{VhelperZeros}} , {VhelperOnes} , {725{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd300) begin
	start_col_selector <= {{299{VhelperOnes}} , {725{VhelperZeros}}};
	input1_col_selector <= {{299{VhelperZeros}} , {VhelperOnes} , {724{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd301) begin
	start_col_selector <= {{300{VhelperOnes}} , {724{VhelperZeros}}};
	input1_col_selector <= {{300{VhelperZeros}} , {VhelperOnes} , {723{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd302) begin
	start_col_selector <= {{301{VhelperOnes}} , {723{VhelperZeros}}};
	input1_col_selector <= {{301{VhelperZeros}} , {VhelperOnes} , {722{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd303) begin
	start_col_selector <= {{302{VhelperOnes}} , {722{VhelperZeros}}};
	input1_col_selector <= {{302{VhelperZeros}} , {VhelperOnes} , {721{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd304) begin
	start_col_selector <= {{303{VhelperOnes}} , {721{VhelperZeros}}};
	input1_col_selector <= {{303{VhelperZeros}} , {VhelperOnes} , {720{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd305) begin
	start_col_selector <= {{304{VhelperOnes}} , {720{VhelperZeros}}};	
	input1_col_selector <= {{304{VhelperZeros}} , {VhelperOnes} , {719{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd306) begin
	start_col_selector <= {{305{VhelperOnes}} , {719{VhelperZeros}}};
	input1_col_selector <= {{305{VhelperZeros}} , {VhelperOnes} , {718{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd307) begin
	start_col_selector <= {{306{VhelperOnes}} , {718{VhelperZeros}}};
	input1_col_selector <= {{306{VhelperZeros}} , {VhelperOnes} , {717{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd308) begin
	start_col_selector <= {{307{VhelperOnes}} , {717{VhelperZeros}}};
	input1_col_selector <= {{307{VhelperZeros}} , {VhelperOnes} , {716{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd309) begin
	start_col_selector <= {{308{VhelperOnes}} , {716{VhelperZeros}}};
	input1_col_selector <= {{308{VhelperZeros}} , {VhelperOnes} , {715{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd310) begin
	start_col_selector <= {{309{VhelperOnes}} , {715{VhelperZeros}}};
	input1_col_selector <= {{309{VhelperZeros}} , {VhelperOnes} , {714{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd311) begin
	start_col_selector <= {{310{VhelperOnes}} , {714{VhelperZeros}}};
	input1_col_selector <= {{310{VhelperZeros}} , {VhelperOnes} , {713{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd312) begin
	start_col_selector <= {{311{VhelperOnes}} , {713{VhelperZeros}}};
	input1_col_selector <= {{311{VhelperZeros}} , {VhelperOnes} , {712{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd313) begin
	start_col_selector <= {{312{VhelperOnes}} , {712{VhelperZeros}}};
	input1_col_selector <= {{312{VhelperZeros}} , {VhelperOnes} , {711{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd314) begin
	start_col_selector <= {{313{VhelperOnes}} , {711{VhelperZeros}}};
	input1_col_selector <= {{313{VhelperZeros}} , {VhelperOnes} , {710{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd315) begin
	start_col_selector <= {{314{VhelperOnes}} , {710{VhelperZeros}}};	
	input1_col_selector <= {{314{VhelperZeros}} , {VhelperOnes} , {709{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd316) begin
	start_col_selector <= {{315{VhelperOnes}} , {709{VhelperZeros}}};
	input1_col_selector <= {{315{VhelperZeros}} , {VhelperOnes} , {708{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd317) begin
	start_col_selector <= {{316{VhelperOnes}} , {708{VhelperZeros}}};
	input1_col_selector <= {{316{VhelperZeros}} , {VhelperOnes} , {707{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd318) begin
	start_col_selector <= {{317{VhelperOnes}} , {707{VhelperZeros}}};
	input1_col_selector <= {{317{VhelperZeros}} , {VhelperOnes} , {706{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd319) begin
	start_col_selector <= {{318{VhelperOnes}} , {706{VhelperZeros}}};
	input1_col_selector <= {{318{VhelperZeros}} , {VhelperOnes} , {705{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd320) begin
	start_col_selector <= {{319{VhelperOnes}} , {705{VhelperZeros}}};
	input1_col_selector <= {{319{VhelperZeros}} , {VhelperOnes} , {704{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd321) begin
	start_col_selector <= {{320{VhelperOnes}} , {704{VhelperZeros}}};
	input1_col_selector <= {{320{VhelperZeros}} , {VhelperOnes} , {703{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd322) begin
	start_col_selector <= {{321{VhelperOnes}} , {703{VhelperZeros}}};
	input1_col_selector <= {{321{VhelperZeros}} , {VhelperOnes} , {702{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd323) begin
	start_col_selector <= {{322{VhelperOnes}} , {702{VhelperZeros}}};
	input1_col_selector <= {{322{VhelperZeros}} , {VhelperOnes} , {701{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd324) begin
	start_col_selector <= {{323{VhelperOnes}} , {701{VhelperZeros}}};
	input1_col_selector <= {{323{VhelperZeros}} , {VhelperOnes} , {700{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd325) begin
	start_col_selector <= {{324{VhelperOnes}} , {700{VhelperZeros}}};	
	input1_col_selector <= {{324{VhelperZeros}} , {VhelperOnes} , {699{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd326) begin
	start_col_selector <= {{325{VhelperOnes}} , {699{VhelperZeros}}};
	input1_col_selector <= {{325{VhelperZeros}} , {VhelperOnes} , {698{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd327) begin
	start_col_selector <= {{326{VhelperOnes}} , {698{VhelperZeros}}};
	input1_col_selector <= {{326{VhelperZeros}} , {VhelperOnes} , {697{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd328) begin
	start_col_selector <= {{327{VhelperOnes}} , {697{VhelperZeros}}};
	input1_col_selector <= {{327{VhelperZeros}} , {VhelperOnes} , {696{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd329) begin
	start_col_selector <= {{328{VhelperOnes}} , {696{VhelperZeros}}};
	input1_col_selector <= {{328{VhelperZeros}} , {VhelperOnes} , {695{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd330) begin
	start_col_selector <= {{329{VhelperOnes}} , {695{VhelperZeros}}};
	input1_col_selector <= {{329{VhelperZeros}} , {VhelperOnes} , {694{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd331) begin
	start_col_selector <= {{330{VhelperOnes}} , {694{VhelperZeros}}};
	input1_col_selector <= {{330{VhelperZeros}} , {VhelperOnes} , {693{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd332) begin
	start_col_selector <= {{331{VhelperOnes}} , {693{VhelperZeros}}};
	input1_col_selector <= {{331{VhelperZeros}} , {VhelperOnes} , {692{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd333) begin
	start_col_selector <= {{332{VhelperOnes}} , {692{VhelperZeros}}};
	input1_col_selector <= {{332{VhelperZeros}} , {VhelperOnes} , {691{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd334) begin
	start_col_selector <= {{333{VhelperOnes}} , {691{VhelperZeros}}};
	input1_col_selector <= {{333{VhelperZeros}} , {VhelperOnes} , {690{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd335) begin
	start_col_selector <= {{334{VhelperOnes}} , {690{VhelperZeros}}};	
	input1_col_selector <= {{334{VhelperZeros}} , {VhelperOnes} , {689{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd336) begin
	start_col_selector <= {{335{VhelperOnes}} , {689{VhelperZeros}}};
	input1_col_selector <= {{335{VhelperZeros}} , {VhelperOnes} , {688{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd337) begin
	start_col_selector <= {{336{VhelperOnes}} , {688{VhelperZeros}}};
	input1_col_selector <= {{336{VhelperZeros}} , {VhelperOnes} , {687{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd338) begin
	start_col_selector <= {{337{VhelperOnes}} , {687{VhelperZeros}}};
	input1_col_selector <= {{337{VhelperZeros}} , {VhelperOnes} , {686{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd339) begin
	start_col_selector <= {{338{VhelperOnes}} , {686{VhelperZeros}}};
	input1_col_selector <= {{338{VhelperZeros}} , {VhelperOnes} , {685{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd340) begin
	start_col_selector <= {{339{VhelperOnes}} , {685{VhelperZeros}}};
	input1_col_selector <= {{339{VhelperZeros}} , {VhelperOnes} , {684{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd341) begin
	start_col_selector <= {{340{VhelperOnes}} , {684{VhelperZeros}}};
	input1_col_selector <= {{340{VhelperZeros}} , {VhelperOnes} , {683{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd342) begin
	start_col_selector <= {{341{VhelperOnes}} , {683{VhelperZeros}}};
	input1_col_selector <= {{341{VhelperZeros}} , {VhelperOnes} , {682{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd343) begin
	start_col_selector <= {{342{VhelperOnes}} , {682{VhelperZeros}}};
	input1_col_selector <= {{342{VhelperZeros}} , {VhelperOnes} , {681{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd344) begin
	start_col_selector <= {{343{VhelperOnes}} , {681{VhelperZeros}}};
	input1_col_selector <= {{343{VhelperZeros}} , {VhelperOnes} , {680{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd345) begin
	start_col_selector <= {{344{VhelperOnes}} , {680{VhelperZeros}}};	
	input1_col_selector <= {{344{VhelperZeros}} , {VhelperOnes} , {679{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd346) begin
	start_col_selector <= {{345{VhelperOnes}} , {679{VhelperZeros}}};
	input1_col_selector <= {{345{VhelperZeros}} , {VhelperOnes} , {678{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd347) begin
	start_col_selector <= {{346{VhelperOnes}} , {678{VhelperZeros}}};
	input1_col_selector <= {{346{VhelperZeros}} , {VhelperOnes} , {677{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd348) begin
	start_col_selector <= {{347{VhelperOnes}} , {677{VhelperZeros}}};
	input1_col_selector <= {{347{VhelperZeros}} , {VhelperOnes} , {676{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd349) begin
	start_col_selector <= {{348{VhelperOnes}} , {676{VhelperZeros}}};
	input1_col_selector <= {{348{VhelperZeros}} , {VhelperOnes} , {675{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd350) begin
	start_col_selector <= {{349{VhelperOnes}} , {675{VhelperZeros}}};
	input1_col_selector <= {{349{VhelperZeros}} , {VhelperOnes} , {674{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd351) begin
	start_col_selector <= {{350{VhelperOnes}} , {674{VhelperZeros}}};
	input1_col_selector <= {{350{VhelperZeros}} , {VhelperOnes} , {673{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd352) begin
	start_col_selector <= {{351{VhelperOnes}} , {673{VhelperZeros}}};
	input1_col_selector <= {{351{VhelperZeros}} , {VhelperOnes} , {672{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd353) begin
	start_col_selector <= {{352{VhelperOnes}} , {672{VhelperZeros}}};
	input1_col_selector <= {{352{VhelperZeros}} , {VhelperOnes} , {671{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd354) begin
	start_col_selector <= {{353{VhelperOnes}} , {671{VhelperZeros}}};
	input1_col_selector <= {{353{VhelperZeros}} , {VhelperOnes} , {670{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd355) begin
	start_col_selector <= {{354{VhelperOnes}} , {670{VhelperZeros}}};	
	input1_col_selector <= {{354{VhelperZeros}} , {VhelperOnes} , {669{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd356) begin
	start_col_selector <= {{355{VhelperOnes}} , {669{VhelperZeros}}};
	input1_col_selector <= {{355{VhelperZeros}} , {VhelperOnes} , {668{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd357) begin
	start_col_selector <= {{356{VhelperOnes}} , {668{VhelperZeros}}};
	input1_col_selector <= {{356{VhelperZeros}} , {VhelperOnes} , {667{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd358) begin
	start_col_selector <= {{357{VhelperOnes}} , {667{VhelperZeros}}};
	input1_col_selector <= {{357{VhelperZeros}} , {VhelperOnes} , {666{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd359) begin
	start_col_selector <= {{358{VhelperOnes}} , {666{VhelperZeros}}};
	input1_col_selector <= {{358{VhelperZeros}} , {VhelperOnes} , {665{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd360) begin
	start_col_selector <= {{359{VhelperOnes}} , {665{VhelperZeros}}};
	input1_col_selector <= {{359{VhelperZeros}} , {VhelperOnes} , {664{VhelperZeros}}};	
end








else if (inst[start_of_input1:end_of_input1] == 10'd361) begin
	start_col_selector <= {{360{VhelperOnes}} , {664{VhelperZeros}}};
	input1_col_selector <= {{360{VhelperZeros}} , {VhelperOnes} , {663{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd362) begin
	start_col_selector <= {{361{VhelperOnes}} , {663{VhelperZeros}}};
	input1_col_selector <= {{361{VhelperZeros}} , {VhelperOnes} , {662{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd363) begin
	start_col_selector <= {{362{VhelperOnes}} , {662{VhelperZeros}}};
	input1_col_selector <= {{362{VhelperZeros}} , {VhelperOnes} , {661{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd364) begin
	start_col_selector <= {{363{VhelperOnes}} , {661{VhelperZeros}}};
	input1_col_selector <= {{363{VhelperZeros}} , {VhelperOnes} , {660{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd365) begin
	start_col_selector <= {{364{VhelperOnes}} , {660{VhelperZeros}}};	
	input1_col_selector <= {{364{VhelperZeros}} , {VhelperOnes} , {659{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd366) begin
	start_col_selector <= {{365{VhelperOnes}} , {659{VhelperZeros}}};
	input1_col_selector <= {{365{VhelperZeros}} , {VhelperOnes} , {658{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd367) begin
	start_col_selector <= {{366{VhelperOnes}} , {658{VhelperZeros}}};
	input1_col_selector <= {{366{VhelperZeros}} , {VhelperOnes} , {657{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd368) begin
	start_col_selector <= {{367{VhelperOnes}} , {657{VhelperZeros}}};
	input1_col_selector <= {{367{VhelperZeros}} , {VhelperOnes} , {656{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd369) begin
	start_col_selector <= {{368{VhelperOnes}} , {656{VhelperZeros}}};
	input1_col_selector <= {{368{VhelperZeros}} , {VhelperOnes} , {655{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd370) begin
	start_col_selector <= {{369{VhelperOnes}} , {655{VhelperZeros}}};
	input1_col_selector <= {{369{VhelperZeros}} , {VhelperOnes} , {654{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd371) begin
	start_col_selector <= {{370{VhelperOnes}} , {654{VhelperZeros}}};
	input1_col_selector <= {{370{VhelperZeros}} , {VhelperOnes} , {653{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd372) begin
	start_col_selector <= {{371{VhelperOnes}} , {653{VhelperZeros}}};
	input1_col_selector <= {{371{VhelperZeros}} , {VhelperOnes} , {652{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd373) begin
	start_col_selector <= {{372{VhelperOnes}} , {652{VhelperZeros}}};
	input1_col_selector <= {{372{VhelperZeros}} , {VhelperOnes} , {651{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd374) begin
	start_col_selector <= {{373{VhelperOnes}} , {651{VhelperZeros}}};
	input1_col_selector <= {{373{VhelperZeros}} , {VhelperOnes} , {650{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd375) begin
	start_col_selector <= {{374{VhelperOnes}} , {650{VhelperZeros}}};	
	input1_col_selector <= {{374{VhelperZeros}} , {VhelperOnes} , {649{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd376) begin
	start_col_selector <= {{375{VhelperOnes}} , {649{VhelperZeros}}};
	input1_col_selector <= {{375{VhelperZeros}} , {VhelperOnes} , {648{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd377) begin
	start_col_selector <= {{376{VhelperOnes}} , {648{VhelperZeros}}};
	input1_col_selector <= {{376{VhelperZeros}} , {VhelperOnes} , {647{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd378) begin
	start_col_selector <= {{377{VhelperOnes}} , {647{VhelperZeros}}};
	input1_col_selector <= {{377{VhelperZeros}} , {VhelperOnes} , {646{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd379) begin
	start_col_selector <= {{378{VhelperOnes}} , {646{VhelperZeros}}};
	input1_col_selector <= {{378{VhelperZeros}} , {VhelperOnes} , {645{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd380) begin
	start_col_selector <= {{379{VhelperOnes}} , {645{VhelperZeros}}};
	input1_col_selector <= {{379{VhelperZeros}} , {VhelperOnes} , {644{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd381) begin
	start_col_selector <= {{380{VhelperOnes}} , {644{VhelperZeros}}};
	input1_col_selector <= {{380{VhelperZeros}} , {VhelperOnes} , {643{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd382) begin
	start_col_selector <= {{381{VhelperOnes}} , {643{VhelperZeros}}};
	input1_col_selector <= {{381{VhelperZeros}} , {VhelperOnes} , {642{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd383) begin
	start_col_selector <= {{382{VhelperOnes}} , {642{VhelperZeros}}};
	input1_col_selector <= {{382{VhelperZeros}} , {VhelperOnes} , {641{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd384) begin
	start_col_selector <= {{383{VhelperOnes}} , {641{VhelperZeros}}};
	input1_col_selector <= {{383{VhelperZeros}} , {VhelperOnes} , {640{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd385) begin
	start_col_selector <= {{384{VhelperOnes}} , {640{VhelperZeros}}};	
	input1_col_selector <= {{384{VhelperZeros}} , {VhelperOnes} , {639{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd386) begin
	start_col_selector <= {{385{VhelperOnes}} , {639{VhelperZeros}}};
	input1_col_selector <= {{385{VhelperZeros}} , {VhelperOnes} , {638{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd387) begin
	start_col_selector <= {{386{VhelperOnes}} , {638{VhelperZeros}}};
	input1_col_selector <= {{386{VhelperZeros}} , {VhelperOnes} , {637{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd388) begin
	start_col_selector <= {{387{VhelperOnes}} , {637{VhelperZeros}}};
	input1_col_selector <= {{387{VhelperZeros}} , {VhelperOnes} , {636{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd389) begin
	start_col_selector <= {{388{VhelperOnes}} , {636{VhelperZeros}}};
	input1_col_selector <= {{388{VhelperZeros}} , {VhelperOnes} , {635{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd390) begin
	start_col_selector <= {{389{VhelperOnes}} , {635{VhelperZeros}}};
	input1_col_selector <= {{389{VhelperZeros}} , {VhelperOnes} , {634{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd391) begin
	start_col_selector <= {{390{VhelperOnes}} , {634{VhelperZeros}}};
	input1_col_selector <= {{390{VhelperZeros}} , {VhelperOnes} , {633{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd392) begin
	start_col_selector <= {{391{VhelperOnes}} , {633{VhelperZeros}}};
	input1_col_selector <= {{391{VhelperZeros}} , {VhelperOnes} , {632{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd393) begin
	start_col_selector <= {{392{VhelperOnes}} , {632{VhelperZeros}}};
	input1_col_selector <= {{392{VhelperZeros}} , {VhelperOnes} , {631{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd394) begin
	start_col_selector <= {{393{VhelperOnes}} , {631{VhelperZeros}}};
	input1_col_selector <= {{393{VhelperZeros}} , {VhelperOnes} , {630{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd395) begin
	start_col_selector <= {{394{VhelperOnes}} , {630{VhelperZeros}}};	
	input1_col_selector <= {{394{VhelperZeros}} , {VhelperOnes} , {629{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd396) begin
	start_col_selector <= {{395{VhelperOnes}} , {629{VhelperZeros}}};
	input1_col_selector <= {{395{VhelperZeros}} , {VhelperOnes} , {628{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd397) begin
	start_col_selector <= {{396{VhelperOnes}} , {628{VhelperZeros}}};
	input1_col_selector <= {{396{VhelperZeros}} , {VhelperOnes} , {627{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd398) begin
	start_col_selector <= {{397{VhelperOnes}} , {627{VhelperZeros}}};
	input1_col_selector <= {{397{VhelperZeros}} , {VhelperOnes} , {626{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd399) begin
	start_col_selector <= {{398{VhelperOnes}} , {626{VhelperZeros}}};
	input1_col_selector <= {{398{VhelperZeros}} , {VhelperOnes} , {625{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd400) begin
	start_col_selector <= {{399{VhelperOnes}} , {625{VhelperZeros}}};
	input1_col_selector <= {{399{VhelperZeros}} , {VhelperOnes} , {624{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd401) begin
	start_col_selector <= {{400{VhelperOnes}} , {624{VhelperZeros}}};
	input1_col_selector <= {{400{VhelperZeros}} , {VhelperOnes} , {623{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd402) begin
	start_col_selector <= {{401{VhelperOnes}} , {623{VhelperZeros}}};
	input1_col_selector <= {{401{VhelperZeros}} , {VhelperOnes} , {622{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd403) begin
	start_col_selector <= {{402{VhelperOnes}} , {622{VhelperZeros}}};
	input1_col_selector <= {{402{VhelperZeros}} , {VhelperOnes} , {621{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd404) begin
	start_col_selector <= {{403{VhelperOnes}} , {621{VhelperZeros}}};
	input1_col_selector <= {{403{VhelperZeros}} , {VhelperOnes} , {620{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd405) begin
	start_col_selector <= {{404{VhelperOnes}} , {620{VhelperZeros}}};	
	input1_col_selector <= {{404{VhelperZeros}} , {VhelperOnes} , {619{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd406) begin
	start_col_selector <= {{405{VhelperOnes}} , {619{VhelperZeros}}};
	input1_col_selector <= {{405{VhelperZeros}} , {VhelperOnes} , {618{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd407) begin
	start_col_selector <= {{406{VhelperOnes}} , {618{VhelperZeros}}};
	input1_col_selector <= {{406{VhelperZeros}} , {VhelperOnes} , {617{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd408) begin
	start_col_selector <= {{407{VhelperOnes}} , {617{VhelperZeros}}};
	input1_col_selector <= {{407{VhelperZeros}} , {VhelperOnes} , {616{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd409) begin
	start_col_selector <= {{408{VhelperOnes}} , {616{VhelperZeros}}};
	input1_col_selector <= {{408{VhelperZeros}} , {VhelperOnes} , {615{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd410) begin
	start_col_selector <= {{409{VhelperOnes}} , {615{VhelperZeros}}};
	input1_col_selector <= {{409{VhelperZeros}} , {VhelperOnes} , {614{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd411) begin
	start_col_selector <= {{410{VhelperOnes}} , {614{VhelperZeros}}};
	input1_col_selector <= {{410{VhelperZeros}} , {VhelperOnes} , {613{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd412) begin
	start_col_selector <= {{411{VhelperOnes}} , {613{VhelperZeros}}};
	input1_col_selector <= {{411{VhelperZeros}} , {VhelperOnes} , {612{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd413) begin
	start_col_selector <= {{412{VhelperOnes}} , {612{VhelperZeros}}};
	input1_col_selector <= {{412{VhelperZeros}} , {VhelperOnes} , {611{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd414) begin
	start_col_selector <= {{413{VhelperOnes}} , {611{VhelperZeros}}};
	input1_col_selector <= {{413{VhelperZeros}} , {VhelperOnes} , {610{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd415) begin
	start_col_selector <= {{414{VhelperOnes}} , {610{VhelperZeros}}};	
	input1_col_selector <= {{414{VhelperZeros}} , {VhelperOnes} , {609{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd416) begin
	start_col_selector <= {{415{VhelperOnes}} , {609{VhelperZeros}}};
	input1_col_selector <= {{415{VhelperZeros}} , {VhelperOnes} , {608{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd417) begin
	start_col_selector <= {{416{VhelperOnes}} , {608{VhelperZeros}}};
	input1_col_selector <= {{416{VhelperZeros}} , {VhelperOnes} , {607{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd418) begin
	start_col_selector <= {{417{VhelperOnes}} , {607{VhelperZeros}}};
	input1_col_selector <= {{417{VhelperZeros}} , {VhelperOnes} , {606{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd419) begin
	start_col_selector <= {{418{VhelperOnes}} , {606{VhelperZeros}}};
	input1_col_selector <= {{418{VhelperZeros}} , {VhelperOnes} , {605{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd420) begin
	start_col_selector <= {{419{VhelperOnes}} , {605{VhelperZeros}}};
	input1_col_selector <= {{419{VhelperZeros}} , {VhelperOnes} , {604{VhelperZeros}}};	
end

else if (inst[start_of_input1:end_of_input1] == 10'd421) begin
	start_col_selector <= {{420{VhelperOnes}} , {604{VhelperZeros}}};
	input1_col_selector <= {{420{VhelperZeros}} , {VhelperOnes} , {603{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd422) begin
	start_col_selector <= {{421{VhelperOnes}} , {603{VhelperZeros}}};
	input1_col_selector <= {{421{VhelperZeros}} , {VhelperOnes} , {602{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd423) begin
	start_col_selector <= {{422{VhelperOnes}} , {602{VhelperZeros}}};
	input1_col_selector <= {{422{VhelperZeros}} , {VhelperOnes} , {601{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd424) begin
	start_col_selector <= {{423{VhelperOnes}} , {601{VhelperZeros}}};
	input1_col_selector <= {{423{VhelperZeros}} , {VhelperOnes} , {600{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd425) begin
	start_col_selector <= {{424{VhelperOnes}} , {600{VhelperZeros}}};	
	input1_col_selector <= {{424{VhelperZeros}} , {VhelperOnes} , {599{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd426) begin
	start_col_selector <= {{425{VhelperOnes}} , {599{VhelperZeros}}};
	input1_col_selector <= {{425{VhelperZeros}} , {VhelperOnes} , {598{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd427) begin
	start_col_selector <= {{426{VhelperOnes}} , {598{VhelperZeros}}};
	input1_col_selector <= {{426{VhelperZeros}} , {VhelperOnes} , {597{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd428) begin
	start_col_selector <= {{427{VhelperOnes}} , {597{VhelperZeros}}};
	input1_col_selector <= {{427{VhelperZeros}} , {VhelperOnes} , {596{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd429) begin
	start_col_selector <= {{428{VhelperOnes}} , {596{VhelperZeros}}};
	input1_col_selector <= {{428{VhelperZeros}} , {VhelperOnes} , {595{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd430) begin
	start_col_selector <= {{429{VhelperOnes}} , {595{VhelperZeros}}};
	input1_col_selector <= {{429{VhelperZeros}} , {VhelperOnes} , {594{VhelperZeros}}};	
end

else if (inst[start_of_input1:end_of_input1] == 10'd431) begin
	start_col_selector <= {{430{VhelperOnes}} , {594{VhelperZeros}}};
	input1_col_selector <= {{430{VhelperZeros}} , {VhelperOnes} , {593{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd432) begin
	start_col_selector <= {{431{VhelperOnes}} , {593{VhelperZeros}}};
	input1_col_selector <= {{431{VhelperZeros}} , {VhelperOnes} , {592{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd433) begin
	start_col_selector <= {{432{VhelperOnes}} , {592{VhelperZeros}}};
	input1_col_selector <= {{432{VhelperZeros}} , {VhelperOnes} , {591{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd434) begin
	start_col_selector <= {{433{VhelperOnes}} , {591{VhelperZeros}}};
	input1_col_selector <= {{433{VhelperZeros}} , {VhelperOnes} , {590{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd435) begin
	start_col_selector <= {{434{VhelperOnes}} , {590{VhelperZeros}}};	
	input1_col_selector <= {{434{VhelperZeros}} , {VhelperOnes} , {589{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd436) begin
	start_col_selector <= {{435{VhelperOnes}} , {589{VhelperZeros}}};
	input1_col_selector <= {{435{VhelperZeros}} , {VhelperOnes} , {588{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd437) begin
	start_col_selector <= {{436{VhelperOnes}} , {588{VhelperZeros}}};
	input1_col_selector <= {{436{VhelperZeros}} , {VhelperOnes} , {587{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd438) begin
	start_col_selector <= {{437{VhelperOnes}} , {587{VhelperZeros}}};
	input1_col_selector <= {{437{VhelperZeros}} , {VhelperOnes} , {586{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd439) begin
	start_col_selector <= {{438{VhelperOnes}} , {586{VhelperZeros}}};
	input1_col_selector <= {{438{VhelperZeros}} , {VhelperOnes} , {585{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd440) begin
	start_col_selector <= {{439{VhelperOnes}} , {585{VhelperZeros}}};
	input1_col_selector <= {{439{VhelperZeros}} , {VhelperOnes} , {584{VhelperZeros}}};	
end

else if (inst[start_of_input1:end_of_input1] == 10'd441) begin
	start_col_selector <= {{440{VhelperOnes}} , {584{VhelperZeros}}};
	input1_col_selector <= {{440{VhelperZeros}} , {VhelperOnes} , {583{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd442) begin
	start_col_selector <= {{441{VhelperOnes}} , {583{VhelperZeros}}};
	input1_col_selector <= {{441{VhelperZeros}} , {VhelperOnes} , {582{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd443) begin
	start_col_selector <= {{442{VhelperOnes}} , {582{VhelperZeros}}};
	input1_col_selector <= {{442{VhelperZeros}} , {VhelperOnes} , {581{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd444) begin
	start_col_selector <= {{443{VhelperOnes}} , {581{VhelperZeros}}};
	input1_col_selector <= {{443{VhelperZeros}} , {VhelperOnes} , {580{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd445) begin
	start_col_selector <= {{444{VhelperOnes}} , {580{VhelperZeros}}};	
	input1_col_selector <= {{444{VhelperZeros}} , {VhelperOnes} , {579{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd446) begin
	start_col_selector <= {{445{VhelperOnes}} , {579{VhelperZeros}}};
	input1_col_selector <= {{445{VhelperZeros}} , {VhelperOnes} , {578{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd447) begin
	start_col_selector <= {{446{VhelperOnes}} , {578{VhelperZeros}}};
	input1_col_selector <= {{446{VhelperZeros}} , {VhelperOnes} , {577{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd448) begin
	start_col_selector <= {{447{VhelperOnes}} , {577{VhelperZeros}}};
	input1_col_selector <= {{447{VhelperZeros}} , {VhelperOnes} , {576{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd449) begin
	start_col_selector <= {{448{VhelperOnes}} , {576{VhelperZeros}}};
	input1_col_selector <= {{448{VhelperZeros}} , {VhelperOnes} , {575{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd450) begin
	start_col_selector <= {{449{VhelperOnes}} , {575{VhelperZeros}}};
	input1_col_selector <= {{449{VhelperZeros}} , {VhelperOnes} , {574{VhelperZeros}}};	
end

else if (inst[start_of_input1:end_of_input1] == 10'd451) begin
	start_col_selector <= {{450{VhelperOnes}} , {574{VhelperZeros}}};
	input1_col_selector <= {{450{VhelperZeros}} , {VhelperOnes} , {573{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd452) begin
	start_col_selector <= {{451{VhelperOnes}} , {573{VhelperZeros}}};
	input1_col_selector <= {{451{VhelperZeros}} , {VhelperOnes} , {572{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd453) begin
	start_col_selector <= {{452{VhelperOnes}} , {572{VhelperZeros}}};
	input1_col_selector <= {{452{VhelperZeros}} , {VhelperOnes} , {571{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd454) begin
	start_col_selector <= {{453{VhelperOnes}} , {571{VhelperZeros}}};
	input1_col_selector <= {{453{VhelperZeros}} , {VhelperOnes} , {570{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd455) begin
	start_col_selector <= {{454{VhelperOnes}} , {570{VhelperZeros}}};	
	input1_col_selector <= {{454{VhelperZeros}} , {VhelperOnes} , {569{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd456) begin
	start_col_selector <= {{455{VhelperOnes}} , {569{VhelperZeros}}};
	input1_col_selector <= {{455{VhelperZeros}} , {VhelperOnes} , {568{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd457) begin
	start_col_selector <= {{456{VhelperOnes}} , {568{VhelperZeros}}};
	input1_col_selector <= {{456{VhelperZeros}} , {VhelperOnes} , {567{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd458) begin
	start_col_selector <= {{457{VhelperOnes}} , {567{VhelperZeros}}};
	input1_col_selector <= {{457{VhelperZeros}} , {VhelperOnes} , {566{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd459) begin
	start_col_selector <= {{458{VhelperOnes}} , {566{VhelperZeros}}};
	input1_col_selector <= {{458{VhelperZeros}} , {VhelperOnes} , {565{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd460) begin
	start_col_selector <= {{459{VhelperOnes}} , {565{VhelperZeros}}};
	input1_col_selector <= {{459{VhelperZeros}} , {VhelperOnes} , {564{VhelperZeros}}};	
end






else if (inst[start_of_input1:end_of_input1] == 10'd461) begin
	start_col_selector <= {{460{VhelperOnes}} , {564{VhelperZeros}}};
	input1_col_selector <= {{460{VhelperZeros}} , {VhelperOnes} , {563{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd462) begin
	start_col_selector <= {{461{VhelperOnes}} , {563{VhelperZeros}}};
	input1_col_selector <= {{461{VhelperZeros}} , {VhelperOnes} , {562{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd463) begin
	start_col_selector <= {{462{VhelperOnes}} , {562{VhelperZeros}}};
	input1_col_selector <= {{462{VhelperZeros}} , {VhelperOnes} , {561{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd464) begin
	start_col_selector <= {{463{VhelperOnes}} , {561{VhelperZeros}}};
	input1_col_selector <= {{463{VhelperZeros}} , {VhelperOnes} , {560{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd465) begin
	start_col_selector <= {{464{VhelperOnes}} , {560{VhelperZeros}}};	
	input1_col_selector <= {{464{VhelperZeros}} , {VhelperOnes} , {559{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd466) begin
	start_col_selector <= {{465{VhelperOnes}} , {559{VhelperZeros}}};
	input1_col_selector <= {{465{VhelperZeros}} , {VhelperOnes} , {558{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd467) begin
	start_col_selector <= {{466{VhelperOnes}} , {558{VhelperZeros}}};
	input1_col_selector <= {{466{VhelperZeros}} , {VhelperOnes} , {557{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd468) begin
	start_col_selector <= {{467{VhelperOnes}} , {557{VhelperZeros}}};
	input1_col_selector <= {{467{VhelperZeros}} , {VhelperOnes} , {556{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd469) begin
	start_col_selector <= {{468{VhelperOnes}} , {556{VhelperZeros}}};
	input1_col_selector <= {{468{VhelperZeros}} , {VhelperOnes} , {555{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd470) begin
	start_col_selector <= {{469{VhelperOnes}} , {555{VhelperZeros}}};
	input1_col_selector <= {{469{VhelperZeros}} , {VhelperOnes} , {554{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd471) begin
	start_col_selector <= {{470{VhelperOnes}} , {554{VhelperZeros}}};
	input1_col_selector <= {{470{VhelperZeros}} , {VhelperOnes} , {553{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd472) begin
	start_col_selector <= {{471{VhelperOnes}} , {553{VhelperZeros}}};
	input1_col_selector <= {{471{VhelperZeros}} , {VhelperOnes} , {552{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd473) begin
	start_col_selector <= {{472{VhelperOnes}} , {552{VhelperZeros}}};
	input1_col_selector <= {{472{VhelperZeros}} , {VhelperOnes} , {551{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd474) begin
	start_col_selector <= {{473{VhelperOnes}} , {551{VhelperZeros}}};
	input1_col_selector <= {{473{VhelperZeros}} , {VhelperOnes} , {550{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd475) begin
	start_col_selector <= {{474{VhelperOnes}} , {550{VhelperZeros}}};	
	input1_col_selector <= {{474{VhelperZeros}} , {VhelperOnes} , {549{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd476) begin
	start_col_selector <= {{475{VhelperOnes}} , {549{VhelperZeros}}};
	input1_col_selector <= {{475{VhelperZeros}} , {VhelperOnes} , {548{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd477) begin
	start_col_selector <= {{476{VhelperOnes}} , {548{VhelperZeros}}};
	input1_col_selector <= {{476{VhelperZeros}} , {VhelperOnes} , {547{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd478) begin
	start_col_selector <= {{477{VhelperOnes}} , {547{VhelperZeros}}};
	input1_col_selector <= {{477{VhelperZeros}} , {VhelperOnes} , {546{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd479) begin
	start_col_selector <= {{478{VhelperOnes}} , {546{VhelperZeros}}};
	input1_col_selector <= {{478{VhelperZeros}} , {VhelperOnes} , {545{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd480) begin
	start_col_selector <= {{479{VhelperOnes}} , {545{VhelperZeros}}};
	input1_col_selector <= {{479{VhelperZeros}} , {VhelperOnes} , {544{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd481) begin
	start_col_selector <= {{480{VhelperOnes}} , {544{VhelperZeros}}};
	input1_col_selector <= {{480{VhelperZeros}} , {VhelperOnes} , {543{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd482) begin
	start_col_selector <= {{481{VhelperOnes}} , {543{VhelperZeros}}};
	input1_col_selector <= {{481{VhelperZeros}} , {VhelperOnes} , {542{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd483) begin
	start_col_selector <= {{482{VhelperOnes}} , {542{VhelperZeros}}};
	input1_col_selector <= {{482{VhelperZeros}} , {VhelperOnes} , {541{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd484) begin
	start_col_selector <= {{483{VhelperOnes}} , {541{VhelperZeros}}};
	input1_col_selector <= {{483{VhelperZeros}} , {VhelperOnes} , {540{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd485) begin
	start_col_selector <= {{484{VhelperOnes}} , {540{VhelperZeros}}};	
	input1_col_selector <= {{484{VhelperZeros}} , {VhelperOnes} , {539{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd486) begin
	start_col_selector <= {{485{VhelperOnes}} , {539{VhelperZeros}}};
	input1_col_selector <= {{485{VhelperZeros}} , {VhelperOnes} , {538{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd487) begin
	start_col_selector <= {{486{VhelperOnes}} , {538{VhelperZeros}}};
	input1_col_selector <= {{486{VhelperZeros}} , {VhelperOnes} , {537{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd488) begin
	start_col_selector <= {{487{VhelperOnes}} , {537{VhelperZeros}}};
	input1_col_selector <= {{487{VhelperZeros}} , {VhelperOnes} , {536{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd489) begin
	start_col_selector <= {{488{VhelperOnes}} , {536{VhelperZeros}}};
	input1_col_selector <= {{488{VhelperZeros}} , {VhelperOnes} , {535{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd490) begin
	start_col_selector <= {{489{VhelperOnes}} , {535{VhelperZeros}}};
	input1_col_selector <= {{489{VhelperZeros}} , {VhelperOnes} , {534{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd491) begin
	start_col_selector <= {{490{VhelperOnes}} , {534{VhelperZeros}}};
	input1_col_selector <= {{490{VhelperZeros}} , {VhelperOnes} , {533{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd492) begin
	start_col_selector <= {{491{VhelperOnes}} , {533{VhelperZeros}}};
	input1_col_selector <= {{491{VhelperZeros}} , {VhelperOnes} , {532{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd493) begin
	start_col_selector <= {{492{VhelperOnes}} , {532{VhelperZeros}}};
	input1_col_selector <= {{492{VhelperZeros}} , {VhelperOnes} , {531{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd494) begin
	start_col_selector <= {{493{VhelperOnes}} , {531{VhelperZeros}}};
	input1_col_selector <= {{493{VhelperZeros}} , {VhelperOnes} , {530{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd495) begin
	start_col_selector <= {{494{VhelperOnes}} , {530{VhelperZeros}}};	
	input1_col_selector <= {{494{VhelperZeros}} , {VhelperOnes} , {529{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd496) begin
	start_col_selector <= {{495{VhelperOnes}} , {529{VhelperZeros}}};
	input1_col_selector <= {{495{VhelperZeros}} , {VhelperOnes} , {528{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd497) begin
	start_col_selector <= {{496{VhelperOnes}} , {528{VhelperZeros}}};
	input1_col_selector <= {{496{VhelperZeros}} , {VhelperOnes} , {527{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd498) begin
	start_col_selector <= {{497{VhelperOnes}} , {527{VhelperZeros}}};
	input1_col_selector <= {{497{VhelperZeros}} , {VhelperOnes} , {526{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd499) begin
	start_col_selector <= {{498{VhelperOnes}} , {526{VhelperZeros}}};
	input1_col_selector <= {{498{VhelperZeros}} , {VhelperOnes} , {525{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd500) begin
	start_col_selector <= {{499{VhelperOnes}} , {525{VhelperZeros}}};
	input1_col_selector <= {{499{VhelperZeros}} , {VhelperOnes} , {524{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd501) begin
	start_col_selector <= {{500{VhelperOnes}} , {524{VhelperZeros}}};
	input1_col_selector <= {{500{VhelperZeros}} , {VhelperOnes} , {523{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd502) begin
	start_col_selector <= {{501{VhelperOnes}} , {523{VhelperZeros}}};
	input1_col_selector <= {{501{VhelperZeros}} , {VhelperOnes} , {522{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd503) begin
	start_col_selector <= {{502{VhelperOnes}} , {522{VhelperZeros}}};
	input1_col_selector <= {{502{VhelperZeros}} , {VhelperOnes} , {521{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd504) begin
	start_col_selector <= {{503{VhelperOnes}} , {521{VhelperZeros}}};
	input1_col_selector <= {{503{VhelperZeros}} , {VhelperOnes} , {520{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd505) begin
	start_col_selector <= {{504{VhelperOnes}} , {520{VhelperZeros}}};	
	input1_col_selector <= {{504{VhelperZeros}} , {VhelperOnes} , {519{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd506) begin
	start_col_selector <= {{505{VhelperOnes}} , {519{VhelperZeros}}};
	input1_col_selector <= {{505{VhelperZeros}} , {VhelperOnes} , {518{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd507) begin
	start_col_selector <= {{506{VhelperOnes}} , {518{VhelperZeros}}};
	input1_col_selector <= {{506{VhelperZeros}} , {VhelperOnes} , {517{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd508) begin
	start_col_selector <= {{507{VhelperOnes}} , {517{VhelperZeros}}};
	input1_col_selector <= {{507{VhelperZeros}} , {VhelperOnes} , {516{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd509) begin
	start_col_selector <= {{508{VhelperOnes}} , {516{VhelperZeros}}};
	input1_col_selector <= {{508{VhelperZeros}} , {VhelperOnes} , {515{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd510) begin
	start_col_selector <= {{509{VhelperOnes}} , {515{VhelperZeros}}};
	input1_col_selector <= {{509{VhelperZeros}} , {VhelperOnes} , {514{VhelperZeros}}};	
end









else if (inst[start_of_input1:end_of_input1] == 10'd511) begin
	start_col_selector <= {{510{VhelperOnes}} , {514{VhelperZeros}}};
	input1_col_selector <= {{510{VhelperZeros}} , {VhelperOnes} , {513{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd512) begin
	start_col_selector <= {{511{VhelperOnes}} , {513{VhelperZeros}}};
	input1_col_selector <= {{511{VhelperZeros}} , {VhelperOnes} , {512{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd513) begin
	start_col_selector <= {{512{VhelperOnes}} , {512{VhelperZeros}}};
	input1_col_selector <= {{512{VhelperZeros}} , {VhelperOnes} , {511{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd514) begin
	start_col_selector <= {{513{VhelperOnes}} , {511{VhelperZeros}}};
	input1_col_selector <= {{513{VhelperZeros}} , {VhelperOnes} , {510{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd515) begin
	start_col_selector <= {{514{VhelperOnes}} , {510{VhelperZeros}}};	
	input1_col_selector <= {{514{VhelperZeros}} , {VhelperOnes} , {509{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd516) begin
	start_col_selector <= {{515{VhelperOnes}} , {509{VhelperZeros}}};
	input1_col_selector <= {{515{VhelperZeros}} , {VhelperOnes} , {508{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd517) begin
	start_col_selector <= {{516{VhelperOnes}} , {508{VhelperZeros}}};
	input1_col_selector <= {{516{VhelperZeros}} , {VhelperOnes} , {507{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd518) begin
	start_col_selector <= {{517{VhelperOnes}} , {507{VhelperZeros}}};
	input1_col_selector <= {{517{VhelperZeros}} , {VhelperOnes} , {506{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd519) begin
	start_col_selector <= {{518{VhelperOnes}} , {506{VhelperZeros}}};
	input1_col_selector <= {{518{VhelperZeros}} , {VhelperOnes} , {505{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd520) begin
	start_col_selector <= {{519{VhelperOnes}} , {505{VhelperZeros}}};
	input1_col_selector <= {{519{VhelperZeros}} , {VhelperOnes} , {504{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd521) begin
	start_col_selector <= {{520{VhelperOnes}} , {504{VhelperZeros}}};
	input1_col_selector <= {{520{VhelperZeros}} , {VhelperOnes} , {503{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd522) begin
	start_col_selector <= {{521{VhelperOnes}} , {503{VhelperZeros}}};
	input1_col_selector <= {{521{VhelperZeros}} , {VhelperOnes} , {502{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd523) begin
	start_col_selector <= {{522{VhelperOnes}} , {502{VhelperZeros}}};
	input1_col_selector <= {{522{VhelperZeros}} , {VhelperOnes} , {501{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd524) begin
	start_col_selector <= {{523{VhelperOnes}} , {501{VhelperZeros}}};
	input1_col_selector <= {{523{VhelperZeros}} , {VhelperOnes} , {500{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd525) begin
	start_col_selector <= {{524{VhelperOnes}} , {500{VhelperZeros}}};	
	input1_col_selector <= {{524{VhelperZeros}} , {VhelperOnes} , {499{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd526) begin
	start_col_selector <= {{525{VhelperOnes}} , {499{VhelperZeros}}};
	input1_col_selector <= {{525{VhelperZeros}} , {VhelperOnes} , {498{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd527) begin
	start_col_selector <= {{526{VhelperOnes}} , {498{VhelperZeros}}};
	input1_col_selector <= {{526{VhelperZeros}} , {VhelperOnes} , {497{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd528) begin
	start_col_selector <= {{527{VhelperOnes}} , {497{VhelperZeros}}};
	input1_col_selector <= {{527{VhelperZeros}} , {VhelperOnes} , {496{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd529) begin
	start_col_selector <= {{528{VhelperOnes}} , {496{VhelperZeros}}};
	input1_col_selector <= {{528{VhelperZeros}} , {VhelperOnes} , {495{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd530) begin
	start_col_selector <= {{529{VhelperOnes}} , {495{VhelperZeros}}};
	input1_col_selector <= {{529{VhelperZeros}} , {VhelperOnes} , {494{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd531) begin
	start_col_selector <= {{530{VhelperOnes}} , {494{VhelperZeros}}};
	input1_col_selector <= {{530{VhelperZeros}} , {VhelperOnes} , {493{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd532) begin
	start_col_selector <= {{531{VhelperOnes}} , {493{VhelperZeros}}};
	input1_col_selector <= {{531{VhelperZeros}} , {VhelperOnes} , {492{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd533) begin
	start_col_selector <= {{532{VhelperOnes}} , {492{VhelperZeros}}};
	input1_col_selector <= {{532{VhelperZeros}} , {VhelperOnes} , {491{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd534) begin
	start_col_selector <= {{533{VhelperOnes}} , {491{VhelperZeros}}};
	input1_col_selector <= {{533{VhelperZeros}} , {VhelperOnes} , {490{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd535) begin
	start_col_selector <= {{534{VhelperOnes}} , {490{VhelperZeros}}};	
	input1_col_selector <= {{534{VhelperZeros}} , {VhelperOnes} , {489{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd536) begin
	start_col_selector <= {{535{VhelperOnes}} , {489{VhelperZeros}}};
	input1_col_selector <= {{535{VhelperZeros}} , {VhelperOnes} , {488{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd537) begin
	start_col_selector <= {{536{VhelperOnes}} , {488{VhelperZeros}}};
	input1_col_selector <= {{536{VhelperZeros}} , {VhelperOnes} , {487{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd538) begin
	start_col_selector <= {{537{VhelperOnes}} , {487{VhelperZeros}}};
	input1_col_selector <= {{537{VhelperZeros}} , {VhelperOnes} , {486{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd539) begin
	start_col_selector <= {{538{VhelperOnes}} , {486{VhelperZeros}}};
	input1_col_selector <= {{538{VhelperZeros}} , {VhelperOnes} , {485{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd540) begin
	start_col_selector <= {{539{VhelperOnes}} , {485{VhelperZeros}}};
	input1_col_selector <= {{539{VhelperZeros}} , {VhelperOnes} , {484{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd541) begin
	start_col_selector <= {{540{VhelperOnes}} , {484{VhelperZeros}}};
	input1_col_selector <= {{540{VhelperZeros}} , {VhelperOnes} , {483{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd542) begin
	start_col_selector <= {{541{VhelperOnes}} , {483{VhelperZeros}}};
	input1_col_selector <= {{541{VhelperZeros}} , {VhelperOnes} , {482{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd543) begin
	start_col_selector <= {{542{VhelperOnes}} , {482{VhelperZeros}}};
	input1_col_selector <= {{542{VhelperZeros}} , {VhelperOnes} , {481{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd544) begin
	start_col_selector <= {{543{VhelperOnes}} , {481{VhelperZeros}}};
	input1_col_selector <= {{543{VhelperZeros}} , {VhelperOnes} , {480{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd545) begin
	start_col_selector <= {{544{VhelperOnes}} , {480{VhelperZeros}}};	
	input1_col_selector <= {{544{VhelperZeros}} , {VhelperOnes} , {479{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd546) begin
	start_col_selector <= {{545{VhelperOnes}} , {479{VhelperZeros}}};
	input1_col_selector <= {{545{VhelperZeros}} , {VhelperOnes} , {478{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd547) begin
	start_col_selector <= {{546{VhelperOnes}} , {478{VhelperZeros}}};
	input1_col_selector <= {{546{VhelperZeros}} , {VhelperOnes} , {477{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd548) begin
	start_col_selector <= {{547{VhelperOnes}} , {477{VhelperZeros}}};
	input1_col_selector <= {{547{VhelperZeros}} , {VhelperOnes} , {476{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd549) begin
	start_col_selector <= {{548{VhelperOnes}} , {476{VhelperZeros}}};
	input1_col_selector <= {{548{VhelperZeros}} , {VhelperOnes} , {475{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd550) begin
	start_col_selector <= {{549{VhelperOnes}} , {475{VhelperZeros}}};
	input1_col_selector <= {{549{VhelperZeros}} , {VhelperOnes} , {474{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd551) begin
	start_col_selector <= {{550{VhelperOnes}} , {474{VhelperZeros}}};
	input1_col_selector <= {{550{VhelperZeros}} , {VhelperOnes} , {473{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd552) begin
	start_col_selector <= {{551{VhelperOnes}} , {473{VhelperZeros}}};
	input1_col_selector <= {{551{VhelperZeros}} , {VhelperOnes} , {472{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd553) begin
	start_col_selector <= {{552{VhelperOnes}} , {472{VhelperZeros}}};
	input1_col_selector <= {{552{VhelperZeros}} , {VhelperOnes} , {471{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd554) begin
	start_col_selector <= {{553{VhelperOnes}} , {471{VhelperZeros}}};
	input1_col_selector <= {{553{VhelperZeros}} , {VhelperOnes} , {470{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd555) begin
	start_col_selector <= {{554{VhelperOnes}} , {470{VhelperZeros}}};	
	input1_col_selector <= {{554{VhelperZeros}} , {VhelperOnes} , {469{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd556) begin
	start_col_selector <= {{555{VhelperOnes}} , {469{VhelperZeros}}};
	input1_col_selector <= {{555{VhelperZeros}} , {VhelperOnes} , {468{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd557) begin
	start_col_selector <= {{556{VhelperOnes}} , {468{VhelperZeros}}};
	input1_col_selector <= {{556{VhelperZeros}} , {VhelperOnes} , {467{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd558) begin
	start_col_selector <= {{557{VhelperOnes}} , {467{VhelperZeros}}};
	input1_col_selector <= {{557{VhelperZeros}} , {VhelperOnes} , {466{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd559) begin
	start_col_selector <= {{558{VhelperOnes}} , {466{VhelperZeros}}};
	input1_col_selector <= {{558{VhelperZeros}} , {VhelperOnes} , {465{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd560) begin
	start_col_selector <= {{559{VhelperOnes}} , {465{VhelperZeros}}};
	input1_col_selector <= {{559{VhelperZeros}} , {VhelperOnes} , {464{VhelperZeros}}};	
end








else if (inst[start_of_input1:end_of_input1] == 10'd561) begin
	start_col_selector <= {{560{VhelperOnes}} , {464{VhelperZeros}}};
	input1_col_selector <= {{560{VhelperZeros}} , {VhelperOnes} , {463{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd562) begin
	start_col_selector <= {{561{VhelperOnes}} , {463{VhelperZeros}}};
	input1_col_selector <= {{561{VhelperZeros}} , {VhelperOnes} , {462{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd563) begin
	start_col_selector <= {{562{VhelperOnes}} , {462{VhelperZeros}}};
	input1_col_selector <= {{562{VhelperZeros}} , {VhelperOnes} , {461{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd564) begin
	start_col_selector <= {{563{VhelperOnes}} , {461{VhelperZeros}}};
	input1_col_selector <= {{563{VhelperZeros}} , {VhelperOnes} , {460{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd565) begin
	start_col_selector <= {{564{VhelperOnes}} , {460{VhelperZeros}}};	
	input1_col_selector <= {{564{VhelperZeros}} , {VhelperOnes} , {459{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd566) begin
	start_col_selector <= {{565{VhelperOnes}} , {459{VhelperZeros}}};
	input1_col_selector <= {{565{VhelperZeros}} , {VhelperOnes} , {458{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd567) begin
	start_col_selector <= {{566{VhelperOnes}} , {458{VhelperZeros}}};
	input1_col_selector <= {{566{VhelperZeros}} , {VhelperOnes} , {457{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd568) begin
	start_col_selector <= {{567{VhelperOnes}} , {457{VhelperZeros}}};
	input1_col_selector <= {{567{VhelperZeros}} , {VhelperOnes} , {456{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd569) begin
	start_col_selector <= {{568{VhelperOnes}} , {456{VhelperZeros}}};
	input1_col_selector <= {{568{VhelperZeros}} , {VhelperOnes} , {455{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd570) begin
	start_col_selector <= {{569{VhelperOnes}} , {455{VhelperZeros}}};
	input1_col_selector <= {{569{VhelperZeros}} , {VhelperOnes} , {454{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd571) begin
	start_col_selector <= {{570{VhelperOnes}} , {454{VhelperZeros}}};
	input1_col_selector <= {{570{VhelperZeros}} , {VhelperOnes} , {453{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd572) begin
	start_col_selector <= {{571{VhelperOnes}} , {453{VhelperZeros}}};
	input1_col_selector <= {{571{VhelperZeros}} , {VhelperOnes} , {452{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd573) begin
	start_col_selector <= {{572{VhelperOnes}} , {452{VhelperZeros}}};
	input1_col_selector <= {{572{VhelperZeros}} , {VhelperOnes} , {451{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd574) begin
	start_col_selector <= {{573{VhelperOnes}} , {451{VhelperZeros}}};
	input1_col_selector <= {{573{VhelperZeros}} , {VhelperOnes} , {450{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd575) begin
	start_col_selector <= {{574{VhelperOnes}} , {450{VhelperZeros}}};	
	input1_col_selector <= {{574{VhelperZeros}} , {VhelperOnes} , {449{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd576) begin
	start_col_selector <= {{575{VhelperOnes}} , {449{VhelperZeros}}};
	input1_col_selector <= {{575{VhelperZeros}} , {VhelperOnes} , {448{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd577) begin
	start_col_selector <= {{576{VhelperOnes}} , {448{VhelperZeros}}};
	input1_col_selector <= {{576{VhelperZeros}} , {VhelperOnes} , {447{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd578) begin
	start_col_selector <= {{577{VhelperOnes}} , {447{VhelperZeros}}};
	input1_col_selector <= {{577{VhelperZeros}} , {VhelperOnes} , {446{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd579) begin
	start_col_selector <= {{578{VhelperOnes}} , {446{VhelperZeros}}};
	input1_col_selector <= {{578{VhelperZeros}} , {VhelperOnes} , {445{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd580) begin
	start_col_selector <= {{579{VhelperOnes}} , {445{VhelperZeros}}};
	input1_col_selector <= {{579{VhelperZeros}} , {VhelperOnes} , {444{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd581) begin
	start_col_selector <= {{580{VhelperOnes}} , {444{VhelperZeros}}};
	input1_col_selector <= {{580{VhelperZeros}} , {VhelperOnes} , {443{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd582) begin
	start_col_selector <= {{581{VhelperOnes}} , {443{VhelperZeros}}};
	input1_col_selector <= {{581{VhelperZeros}} , {VhelperOnes} , {442{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd583) begin
	start_col_selector <= {{582{VhelperOnes}} , {442{VhelperZeros}}};
	input1_col_selector <= {{582{VhelperZeros}} , {VhelperOnes} , {441{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd584) begin
	start_col_selector <= {{583{VhelperOnes}} , {441{VhelperZeros}}};
	input1_col_selector <= {{583{VhelperZeros}} , {VhelperOnes} , {440{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd585) begin
	start_col_selector <= {{584{VhelperOnes}} , {440{VhelperZeros}}};	
	input1_col_selector <= {{584{VhelperZeros}} , {VhelperOnes} , {439{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd586) begin
	start_col_selector <= {{585{VhelperOnes}} , {439{VhelperZeros}}};
	input1_col_selector <= {{585{VhelperZeros}} , {VhelperOnes} , {438{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd587) begin
	start_col_selector <= {{586{VhelperOnes}} , {438{VhelperZeros}}};
	input1_col_selector <= {{586{VhelperZeros}} , {VhelperOnes} , {437{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd588) begin
	start_col_selector <= {{587{VhelperOnes}} , {437{VhelperZeros}}};
	input1_col_selector <= {{587{VhelperZeros}} , {VhelperOnes} , {436{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd589) begin
	start_col_selector <= {{588{VhelperOnes}} , {436{VhelperZeros}}};
	input1_col_selector <= {{588{VhelperZeros}} , {VhelperOnes} , {435{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd590) begin
	start_col_selector <= {{589{VhelperOnes}} , {435{VhelperZeros}}};
	input1_col_selector <= {{589{VhelperZeros}} , {VhelperOnes} , {434{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd591) begin
	start_col_selector <= {{590{VhelperOnes}} , {434{VhelperZeros}}};
	input1_col_selector <= {{590{VhelperZeros}} , {VhelperOnes} , {433{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd592) begin
	start_col_selector <= {{591{VhelperOnes}} , {433{VhelperZeros}}};
	input1_col_selector <= {{591{VhelperZeros}} , {VhelperOnes} , {432{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd593) begin
	start_col_selector <= {{592{VhelperOnes}} , {432{VhelperZeros}}};
	input1_col_selector <= {{592{VhelperZeros}} , {VhelperOnes} , {431{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd594) begin
	start_col_selector <= {{593{VhelperOnes}} , {431{VhelperZeros}}};
	input1_col_selector <= {{593{VhelperZeros}} , {VhelperOnes} , {430{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd595) begin
	start_col_selector <= {{594{VhelperOnes}} , {430{VhelperZeros}}};	
	input1_col_selector <= {{594{VhelperZeros}} , {VhelperOnes} , {429{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd596) begin
	start_col_selector <= {{595{VhelperOnes}} , {429{VhelperZeros}}};
	input1_col_selector <= {{595{VhelperZeros}} , {VhelperOnes} , {428{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd597) begin
	start_col_selector <= {{596{VhelperOnes}} , {428{VhelperZeros}}};
	input1_col_selector <= {{596{VhelperZeros}} , {VhelperOnes} , {427{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd598) begin
	start_col_selector <= {{597{VhelperOnes}} , {427{VhelperZeros}}};
	input1_col_selector <= {{597{VhelperZeros}} , {VhelperOnes} , {426{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd599) begin
	start_col_selector <= {{598{VhelperOnes}} , {426{VhelperZeros}}};
	input1_col_selector <= {{598{VhelperZeros}} , {VhelperOnes} , {425{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd600) begin
	start_col_selector <= {{599{VhelperOnes}} , {425{VhelperZeros}}};
	input1_col_selector <= {{599{VhelperZeros}} , {VhelperOnes} , {424{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd601) begin
	start_col_selector <= {{600{VhelperOnes}} , {424{VhelperZeros}}};
	input1_col_selector <= {{600{VhelperZeros}} , {VhelperOnes} , {423{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd602) begin
	start_col_selector <= {{601{VhelperOnes}} , {423{VhelperZeros}}};
	input1_col_selector <= {{601{VhelperZeros}} , {VhelperOnes} , {422{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd603) begin
	start_col_selector <= {{602{VhelperOnes}} , {422{VhelperZeros}}};
	input1_col_selector <= {{602{VhelperZeros}} , {VhelperOnes} , {421{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd604) begin
	start_col_selector <= {{603{VhelperOnes}} , {421{VhelperZeros}}};
	input1_col_selector <= {{603{VhelperZeros}} , {VhelperOnes} , {420{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd605) begin
	start_col_selector <= {{604{VhelperOnes}} , {420{VhelperZeros}}};	
	input1_col_selector <= {{604{VhelperZeros}} , {VhelperOnes} , {419{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd606) begin
	start_col_selector <= {{605{VhelperOnes}} , {419{VhelperZeros}}};
	input1_col_selector <= {{605{VhelperZeros}} , {VhelperOnes} , {418{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd607) begin
	start_col_selector <= {{606{VhelperOnes}} , {418{VhelperZeros}}};
	input1_col_selector <= {{606{VhelperZeros}} , {VhelperOnes} , {417{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd608) begin
	start_col_selector <= {{607{VhelperOnes}} , {417{VhelperZeros}}};
	input1_col_selector <= {{607{VhelperZeros}} , {VhelperOnes} , {416{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd609) begin
	start_col_selector <= {{608{VhelperOnes}} , {416{VhelperZeros}}};
	input1_col_selector <= {{608{VhelperZeros}} , {VhelperOnes} , {415{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd610) begin
	start_col_selector <= {{609{VhelperOnes}} , {415{VhelperZeros}}};
	input1_col_selector <= {{609{VhelperZeros}} , {VhelperOnes} , {414{VhelperZeros}}};	
end








else if (inst[start_of_input1:end_of_input1] == 10'd611) begin
	start_col_selector <= {{610{VhelperOnes}} , {414{VhelperZeros}}};
	input1_col_selector <= {{610{VhelperZeros}} , {VhelperOnes} , {413{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd612) begin
	start_col_selector <= {{611{VhelperOnes}} , {413{VhelperZeros}}};
	input1_col_selector <= {{611{VhelperZeros}} , {VhelperOnes} , {412{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd613) begin
	start_col_selector <= {{612{VhelperOnes}} , {412{VhelperZeros}}};
	input1_col_selector <= {{612{VhelperZeros}} , {VhelperOnes} , {411{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd614) begin
	start_col_selector <= {{613{VhelperOnes}} , {411{VhelperZeros}}};
	input1_col_selector <= {{613{VhelperZeros}} , {VhelperOnes} , {410{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd615) begin
	start_col_selector <= {{614{VhelperOnes}} , {410{VhelperZeros}}};	
	input1_col_selector <= {{614{VhelperZeros}} , {VhelperOnes} , {409{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd616) begin
	start_col_selector <= {{615{VhelperOnes}} , {409{VhelperZeros}}};
	input1_col_selector <= {{615{VhelperZeros}} , {VhelperOnes} , {408{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd617) begin
	start_col_selector <= {{616{VhelperOnes}} , {408{VhelperZeros}}};
	input1_col_selector <= {{616{VhelperZeros}} , {VhelperOnes} , {407{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd618) begin
	start_col_selector <= {{617{VhelperOnes}} , {407{VhelperZeros}}};
	input1_col_selector <= {{617{VhelperZeros}} , {VhelperOnes} , {406{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd619) begin
	start_col_selector <= {{618{VhelperOnes}} , {406{VhelperZeros}}};
	input1_col_selector <= {{618{VhelperZeros}} , {VhelperOnes} , {405{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd620) begin
	start_col_selector <= {{619{VhelperOnes}} , {405{VhelperZeros}}};
	input1_col_selector <= {{619{VhelperZeros}} , {VhelperOnes} , {404{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd621) begin
	start_col_selector <= {{620{VhelperOnes}} , {404{VhelperZeros}}};
	input1_col_selector <= {{620{VhelperZeros}} , {VhelperOnes} , {403{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd622) begin
	start_col_selector <= {{621{VhelperOnes}} , {403{VhelperZeros}}};
	input1_col_selector <= {{621{VhelperZeros}} , {VhelperOnes} , {402{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd623) begin
	start_col_selector <= {{622{VhelperOnes}} , {402{VhelperZeros}}};
	input1_col_selector <= {{622{VhelperZeros}} , {VhelperOnes} , {401{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd624) begin
	start_col_selector <= {{623{VhelperOnes}} , {401{VhelperZeros}}};
	input1_col_selector <= {{623{VhelperZeros}} , {VhelperOnes} , {400{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd625) begin
	start_col_selector <= {{624{VhelperOnes}} , {400{VhelperZeros}}};	
	input1_col_selector <= {{624{VhelperZeros}} , {VhelperOnes} , {399{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd626) begin
	start_col_selector <= {{625{VhelperOnes}} , {399{VhelperZeros}}};
	input1_col_selector <= {{625{VhelperZeros}} , {VhelperOnes} , {398{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd627) begin
	start_col_selector <= {{626{VhelperOnes}} , {398{VhelperZeros}}};
	input1_col_selector <= {{626{VhelperZeros}} , {VhelperOnes} , {397{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd628) begin
	start_col_selector <= {{627{VhelperOnes}} , {397{VhelperZeros}}};
	input1_col_selector <= {{627{VhelperZeros}} , {VhelperOnes} , {396{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd629) begin
	start_col_selector <= {{628{VhelperOnes}} , {396{VhelperZeros}}};
	input1_col_selector <= {{628{VhelperZeros}} , {VhelperOnes} , {395{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd630) begin
	start_col_selector <= {{629{VhelperOnes}} , {395{VhelperZeros}}};
	input1_col_selector <= {{629{VhelperZeros}} , {VhelperOnes} , {394{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd631) begin
	start_col_selector <= {{630{VhelperOnes}} , {394{VhelperZeros}}};
	input1_col_selector <= {{630{VhelperZeros}} , {VhelperOnes} , {393{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd632) begin
	start_col_selector <= {{631{VhelperOnes}} , {393{VhelperZeros}}};
	input1_col_selector <= {{631{VhelperZeros}} , {VhelperOnes} , {392{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd633) begin
	start_col_selector <= {{632{VhelperOnes}} , {392{VhelperZeros}}};
	input1_col_selector <= {{632{VhelperZeros}} , {VhelperOnes} , {391{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd634) begin
	start_col_selector <= {{633{VhelperOnes}} , {391{VhelperZeros}}};
	input1_col_selector <= {{633{VhelperZeros}} , {VhelperOnes} , {390{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd635) begin
	start_col_selector <= {{634{VhelperOnes}} , {390{VhelperZeros}}};	
	input1_col_selector <= {{634{VhelperZeros}} , {VhelperOnes} , {389{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd636) begin
	start_col_selector <= {{635{VhelperOnes}} , {389{VhelperZeros}}};
	input1_col_selector <= {{635{VhelperZeros}} , {VhelperOnes} , {388{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd637) begin
	start_col_selector <= {{636{VhelperOnes}} , {388{VhelperZeros}}};
	input1_col_selector <= {{636{VhelperZeros}} , {VhelperOnes} , {387{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd638) begin
	start_col_selector <= {{637{VhelperOnes}} , {387{VhelperZeros}}};
	input1_col_selector <= {{637{VhelperZeros}} , {VhelperOnes} , {386{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd639) begin
	start_col_selector <= {{638{VhelperOnes}} , {386{VhelperZeros}}};
	input1_col_selector <= {{638{VhelperZeros}} , {VhelperOnes} , {385{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd640) begin
	start_col_selector <= {{639{VhelperOnes}} , {385{VhelperZeros}}};
	input1_col_selector <= {{639{VhelperZeros}} , {VhelperOnes} , {384{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd641) begin
	start_col_selector <= {{640{VhelperOnes}} , {384{VhelperZeros}}};
	input1_col_selector <= {{640{VhelperZeros}} , {VhelperOnes} , {383{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd642) begin
	start_col_selector <= {{641{VhelperOnes}} , {383{VhelperZeros}}};
	input1_col_selector <= {{641{VhelperZeros}} , {VhelperOnes} , {382{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd643) begin
	start_col_selector <= {{642{VhelperOnes}} , {382{VhelperZeros}}};
	input1_col_selector <= {{642{VhelperZeros}} , {VhelperOnes} , {381{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd644) begin
	start_col_selector <= {{643{VhelperOnes}} , {381{VhelperZeros}}};
	input1_col_selector <= {{643{VhelperZeros}} , {VhelperOnes} , {380{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd645) begin
	start_col_selector <= {{644{VhelperOnes}} , {380{VhelperZeros}}};	
	input1_col_selector <= {{644{VhelperZeros}} , {VhelperOnes} , {379{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd646) begin
	start_col_selector <= {{645{VhelperOnes}} , {379{VhelperZeros}}};
	input1_col_selector <= {{645{VhelperZeros}} , {VhelperOnes} , {378{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd647) begin
	start_col_selector <= {{646{VhelperOnes}} , {378{VhelperZeros}}};
	input1_col_selector <= {{646{VhelperZeros}} , {VhelperOnes} , {377{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd648) begin
	start_col_selector <= {{647{VhelperOnes}} , {377{VhelperZeros}}};
	input1_col_selector <= {{647{VhelperZeros}} , {VhelperOnes} , {376{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd649) begin
	start_col_selector <= {{648{VhelperOnes}} , {376{VhelperZeros}}};
	input1_col_selector <= {{648{VhelperZeros}} , {VhelperOnes} , {375{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd650) begin
	start_col_selector <= {{649{VhelperOnes}} , {375{VhelperZeros}}};
	input1_col_selector <= {{649{VhelperZeros}} , {VhelperOnes} , {374{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd651) begin
	start_col_selector <= {{650{VhelperOnes}} , {374{VhelperZeros}}};
	input1_col_selector <= {{650{VhelperZeros}} , {VhelperOnes} , {373{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd652) begin
	start_col_selector <= {{651{VhelperOnes}} , {373{VhelperZeros}}};
	input1_col_selector <= {{651{VhelperZeros}} , {VhelperOnes} , {372{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd653) begin
	start_col_selector <= {{652{VhelperOnes}} , {372{VhelperZeros}}};
	input1_col_selector <= {{652{VhelperZeros}} , {VhelperOnes} , {371{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd654) begin
	start_col_selector <= {{653{VhelperOnes}} , {371{VhelperZeros}}};
	input1_col_selector <= {{653{VhelperZeros}} , {VhelperOnes} , {370{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd655) begin
	start_col_selector <= {{654{VhelperOnes}} , {370{VhelperZeros}}};	
	input1_col_selector <= {{654{VhelperZeros}} , {VhelperOnes} , {369{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd656) begin
	start_col_selector <= {{655{VhelperOnes}} , {369{VhelperZeros}}};
	input1_col_selector <= {{655{VhelperZeros}} , {VhelperOnes} , {368{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd657) begin
	start_col_selector <= {{656{VhelperOnes}} , {368{VhelperZeros}}};
	input1_col_selector <= {{656{VhelperZeros}} , {VhelperOnes} , {367{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd658) begin
	start_col_selector <= {{657{VhelperOnes}} , {367{VhelperZeros}}};
	input1_col_selector <= {{657{VhelperZeros}} , {VhelperOnes} , {366{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd659) begin
	start_col_selector <= {{658{VhelperOnes}} , {366{VhelperZeros}}};
	input1_col_selector <= {{658{VhelperZeros}} , {VhelperOnes} , {365{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd660) begin
	start_col_selector <= {{659{VhelperOnes}} , {365{VhelperZeros}}};
	input1_col_selector <= {{659{VhelperZeros}} , {VhelperOnes} , {364{VhelperZeros}}};	
end











else if (inst[start_of_input1:end_of_input1] == 10'd661) begin
	start_col_selector <= {{660{VhelperOnes}} , {364{VhelperZeros}}};
	input1_col_selector <= {{660{VhelperZeros}} , {VhelperOnes} , {363{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd662) begin
	start_col_selector <= {{661{VhelperOnes}} , {363{VhelperZeros}}};
	input1_col_selector <= {{661{VhelperZeros}} , {VhelperOnes} , {362{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd663) begin
	start_col_selector <= {{662{VhelperOnes}} , {362{VhelperZeros}}};
	input1_col_selector <= {{662{VhelperZeros}} , {VhelperOnes} , {361{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd664) begin
	start_col_selector <= {{663{VhelperOnes}} , {361{VhelperZeros}}};
	input1_col_selector <= {{663{VhelperZeros}} , {VhelperOnes} , {360{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd665) begin
	start_col_selector <= {{664{VhelperOnes}} , {360{VhelperZeros}}};	
	input1_col_selector <= {{664{VhelperZeros}} , {VhelperOnes} , {359{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd666) begin
	start_col_selector <= {{665{VhelperOnes}} , {359{VhelperZeros}}};
	input1_col_selector <= {{665{VhelperZeros}} , {VhelperOnes} , {358{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd667) begin
	start_col_selector <= {{666{VhelperOnes}} , {358{VhelperZeros}}};
	input1_col_selector <= {{666{VhelperZeros}} , {VhelperOnes} , {357{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd668) begin
	start_col_selector <= {{667{VhelperOnes}} , {357{VhelperZeros}}};
	input1_col_selector <= {{667{VhelperZeros}} , {VhelperOnes} , {356{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd669) begin
	start_col_selector <= {{668{VhelperOnes}} , {356{VhelperZeros}}};
	input1_col_selector <= {{668{VhelperZeros}} , {VhelperOnes} , {355{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd670) begin
	start_col_selector <= {{669{VhelperOnes}} , {355{VhelperZeros}}};
	input1_col_selector <= {{669{VhelperZeros}} , {VhelperOnes} , {354{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd671) begin
	start_col_selector <= {{670{VhelperOnes}} , {354{VhelperZeros}}};
	input1_col_selector <= {{670{VhelperZeros}} , {VhelperOnes} , {353{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd672) begin
	start_col_selector <= {{671{VhelperOnes}} , {353{VhelperZeros}}};
	input1_col_selector <= {{671{VhelperZeros}} , {VhelperOnes} , {352{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd673) begin
	start_col_selector <= {{672{VhelperOnes}} , {352{VhelperZeros}}};
	input1_col_selector <= {{672{VhelperZeros}} , {VhelperOnes} , {351{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd674) begin
	start_col_selector <= {{673{VhelperOnes}} , {351{VhelperZeros}}};
	input1_col_selector <= {{673{VhelperZeros}} , {VhelperOnes} , {350{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd675) begin
	start_col_selector <= {{674{VhelperOnes}} , {350{VhelperZeros}}};	
	input1_col_selector <= {{674{VhelperZeros}} , {VhelperOnes} , {349{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd676) begin
	start_col_selector <= {{675{VhelperOnes}} , {349{VhelperZeros}}};
	input1_col_selector <= {{675{VhelperZeros}} , {VhelperOnes} , {348{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd677) begin
	start_col_selector <= {{676{VhelperOnes}} , {348{VhelperZeros}}};
	input1_col_selector <= {{676{VhelperZeros}} , {VhelperOnes} , {347{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd678) begin
	start_col_selector <= {{677{VhelperOnes}} , {347{VhelperZeros}}};
	input1_col_selector <= {{677{VhelperZeros}} , {VhelperOnes} , {346{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd679) begin
	start_col_selector <= {{678{VhelperOnes}} , {346{VhelperZeros}}};
	input1_col_selector <= {{678{VhelperZeros}} , {VhelperOnes} , {345{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd680) begin
	start_col_selector <= {{679{VhelperOnes}} , {345{VhelperZeros}}};
	input1_col_selector <= {{679{VhelperZeros}} , {VhelperOnes} , {344{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd681) begin
	start_col_selector <= {{680{VhelperOnes}} , {344{VhelperZeros}}};
	input1_col_selector <= {{680{VhelperZeros}} , {VhelperOnes} , {343{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd682) begin
	start_col_selector <= {{681{VhelperOnes}} , {343{VhelperZeros}}};
	input1_col_selector <= {{681{VhelperZeros}} , {VhelperOnes} , {342{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd683) begin
	start_col_selector <= {{682{VhelperOnes}} , {342{VhelperZeros}}};
	input1_col_selector <= {{682{VhelperZeros}} , {VhelperOnes} , {341{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd684) begin
	start_col_selector <= {{683{VhelperOnes}} , {341{VhelperZeros}}};
	input1_col_selector <= {{683{VhelperZeros}} , {VhelperOnes} , {340{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd685) begin
	start_col_selector <= {{684{VhelperOnes}} , {340{VhelperZeros}}};	
	input1_col_selector <= {{684{VhelperZeros}} , {VhelperOnes} , {339{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd686) begin
	start_col_selector <= {{685{VhelperOnes}} , {339{VhelperZeros}}};
	input1_col_selector <= {{685{VhelperZeros}} , {VhelperOnes} , {338{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd687) begin
	start_col_selector <= {{686{VhelperOnes}} , {338{VhelperZeros}}};
	input1_col_selector <= {{686{VhelperZeros}} , {VhelperOnes} , {337{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd688) begin
	start_col_selector <= {{687{VhelperOnes}} , {337{VhelperZeros}}};
	input1_col_selector <= {{687{VhelperZeros}} , {VhelperOnes} , {336{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd689) begin
	start_col_selector <= {{688{VhelperOnes}} , {336{VhelperZeros}}};
	input1_col_selector <= {{688{VhelperZeros}} , {VhelperOnes} , {335{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd690) begin
	start_col_selector <= {{689{VhelperOnes}} , {335{VhelperZeros}}};
	input1_col_selector <= {{689{VhelperZeros}} , {VhelperOnes} , {334{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd691) begin
	start_col_selector <= {{690{VhelperOnes}} , {334{VhelperZeros}}};
	input1_col_selector <= {{690{VhelperZeros}} , {VhelperOnes} , {333{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd692) begin
	start_col_selector <= {{691{VhelperOnes}} , {333{VhelperZeros}}};
	input1_col_selector <= {{691{VhelperZeros}} , {VhelperOnes} , {332{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd693) begin
	start_col_selector <= {{692{VhelperOnes}} , {332{VhelperZeros}}};
	input1_col_selector <= {{692{VhelperZeros}} , {VhelperOnes} , {331{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd694) begin
	start_col_selector <= {{693{VhelperOnes}} , {331{VhelperZeros}}};
	input1_col_selector <= {{693{VhelperZeros}} , {VhelperOnes} , {330{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd695) begin
	start_col_selector <= {{694{VhelperOnes}} , {330{VhelperZeros}}};	
	input1_col_selector <= {{694{VhelperZeros}} , {VhelperOnes} , {329{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd696) begin
	start_col_selector <= {{695{VhelperOnes}} , {329{VhelperZeros}}};
	input1_col_selector <= {{695{VhelperZeros}} , {VhelperOnes} , {328{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd697) begin
	start_col_selector <= {{696{VhelperOnes}} , {328{VhelperZeros}}};
	input1_col_selector <= {{696{VhelperZeros}} , {VhelperOnes} , {327{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd698) begin
	start_col_selector <= {{697{VhelperOnes}} , {327{VhelperZeros}}};
	input1_col_selector <= {{697{VhelperZeros}} , {VhelperOnes} , {326{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd699) begin
	start_col_selector <= {{698{VhelperOnes}} , {326{VhelperZeros}}};
	input1_col_selector <= {{698{VhelperZeros}} , {VhelperOnes} , {325{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd700) begin
	start_col_selector <= {{699{VhelperOnes}} , {325{VhelperZeros}}};
	input1_col_selector <= {{699{VhelperZeros}} , {VhelperOnes} , {324{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd701) begin
	start_col_selector <= {{700{VhelperOnes}} , {324{VhelperZeros}}};
	input1_col_selector <= {{700{VhelperZeros}} , {VhelperOnes} , {323{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd702) begin
	start_col_selector <= {{701{VhelperOnes}} , {323{VhelperZeros}}};
	input1_col_selector <= {{701{VhelperZeros}} , {VhelperOnes} , {322{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd703) begin
	start_col_selector <= {{702{VhelperOnes}} , {322{VhelperZeros}}};
	input1_col_selector <= {{702{VhelperZeros}} , {VhelperOnes} , {321{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd704) begin
	start_col_selector <= {{703{VhelperOnes}} , {321{VhelperZeros}}};
	input1_col_selector <= {{703{VhelperZeros}} , {VhelperOnes} , {320{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd705) begin
	start_col_selector <= {{704{VhelperOnes}} , {320{VhelperZeros}}};	
	input1_col_selector <= {{704{VhelperZeros}} , {VhelperOnes} , {319{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd706) begin
	start_col_selector <= {{705{VhelperOnes}} , {319{VhelperZeros}}};
	input1_col_selector <= {{705{VhelperZeros}} , {VhelperOnes} , {318{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd707) begin
	start_col_selector <= {{706{VhelperOnes}} , {318{VhelperZeros}}};
	input1_col_selector <= {{706{VhelperZeros}} , {VhelperOnes} , {317{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd708) begin
	start_col_selector <= {{707{VhelperOnes}} , {317{VhelperZeros}}};
	input1_col_selector <= {{707{VhelperZeros}} , {VhelperOnes} , {316{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd709) begin
	start_col_selector <= {{708{VhelperOnes}} , {316{VhelperZeros}}};
	input1_col_selector <= {{708{VhelperZeros}} , {VhelperOnes} , {315{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd710) begin
	start_col_selector <= {{709{VhelperOnes}} , {315{VhelperZeros}}};
	input1_col_selector <= {{709{VhelperZeros}} , {VhelperOnes} , {314{VhelperZeros}}};	
end








else if (inst[start_of_input1:end_of_input1] == 10'd711) begin
	start_col_selector <= {{710{VhelperOnes}} , {314{VhelperZeros}}};
	input1_col_selector <= {{710{VhelperZeros}} , {VhelperOnes} , {313{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd712) begin
	start_col_selector <= {{711{VhelperOnes}} , {313{VhelperZeros}}};
	input1_col_selector <= {{711{VhelperZeros}} , {VhelperOnes} , {312{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd713) begin
	start_col_selector <= {{712{VhelperOnes}} , {312{VhelperZeros}}};
	input1_col_selector <= {{712{VhelperZeros}} , {VhelperOnes} , {311{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd714) begin
	start_col_selector <= {{713{VhelperOnes}} , {311{VhelperZeros}}};
	input1_col_selector <= {{713{VhelperZeros}} , {VhelperOnes} , {310{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd715) begin
	start_col_selector <= {{714{VhelperOnes}} , {310{VhelperZeros}}};	
	input1_col_selector <= {{714{VhelperZeros}} , {VhelperOnes} , {309{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd716) begin
	start_col_selector <= {{715{VhelperOnes}} , {309{VhelperZeros}}};
	input1_col_selector <= {{715{VhelperZeros}} , {VhelperOnes} , {308{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd717) begin
	start_col_selector <= {{716{VhelperOnes}} , {308{VhelperZeros}}};
	input1_col_selector <= {{716{VhelperZeros}} , {VhelperOnes} , {307{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd718) begin
	start_col_selector <= {{717{VhelperOnes}} , {307{VhelperZeros}}};
	input1_col_selector <= {{717{VhelperZeros}} , {VhelperOnes} , {306{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd719) begin
	start_col_selector <= {{718{VhelperOnes}} , {306{VhelperZeros}}};
	input1_col_selector <= {{718{VhelperZeros}} , {VhelperOnes} , {305{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd720) begin
	start_col_selector <= {{719{VhelperOnes}} , {305{VhelperZeros}}};
	input1_col_selector <= {{719{VhelperZeros}} , {VhelperOnes} , {304{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd721) begin
	start_col_selector <= {{720{VhelperOnes}} , {304{VhelperZeros}}};
	input1_col_selector <= {{720{VhelperZeros}} , {VhelperOnes} , {303{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd722) begin
	start_col_selector <= {{721{VhelperOnes}} , {303{VhelperZeros}}};
	input1_col_selector <= {{721{VhelperZeros}} , {VhelperOnes} , {302{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd723) begin
	start_col_selector <= {{722{VhelperOnes}} , {302{VhelperZeros}}};
	input1_col_selector <= {{722{VhelperZeros}} , {VhelperOnes} , {301{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd724) begin
	start_col_selector <= {{723{VhelperOnes}} , {301{VhelperZeros}}};
	input1_col_selector <= {{723{VhelperZeros}} , {VhelperOnes} , {300{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd725) begin
	start_col_selector <= {{724{VhelperOnes}} , {300{VhelperZeros}}};	
	input1_col_selector <= {{724{VhelperZeros}} , {VhelperOnes} , {299{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd726) begin
	start_col_selector <= {{725{VhelperOnes}} , {299{VhelperZeros}}};
	input1_col_selector <= {{725{VhelperZeros}} , {VhelperOnes} , {298{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd727) begin
	start_col_selector <= {{726{VhelperOnes}} , {298{VhelperZeros}}};
	input1_col_selector <= {{726{VhelperZeros}} , {VhelperOnes} , {297{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd728) begin
	start_col_selector <= {{727{VhelperOnes}} , {297{VhelperZeros}}};
	input1_col_selector <= {{727{VhelperZeros}} , {VhelperOnes} , {296{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd729) begin
	start_col_selector <= {{728{VhelperOnes}} , {296{VhelperZeros}}};
	input1_col_selector <= {{728{VhelperZeros}} , {VhelperOnes} , {295{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd730) begin
	start_col_selector <= {{729{VhelperOnes}} , {295{VhelperZeros}}};
	input1_col_selector <= {{729{VhelperZeros}} , {VhelperOnes} , {294{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd731) begin
	start_col_selector <= {{730{VhelperOnes}} , {294{VhelperZeros}}};
	input1_col_selector <= {{730{VhelperZeros}} , {VhelperOnes} , {293{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd732) begin
	start_col_selector <= {{731{VhelperOnes}} , {293{VhelperZeros}}};
	input1_col_selector <= {{731{VhelperZeros}} , {VhelperOnes} , {292{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd733) begin
	start_col_selector <= {{732{VhelperOnes}} , {292{VhelperZeros}}};
	input1_col_selector <= {{732{VhelperZeros}} , {VhelperOnes} , {291{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd734) begin
	start_col_selector <= {{733{VhelperOnes}} , {291{VhelperZeros}}};
	input1_col_selector <= {{733{VhelperZeros}} , {VhelperOnes} , {290{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd735) begin
	start_col_selector <= {{734{VhelperOnes}} , {290{VhelperZeros}}};	
	input1_col_selector <= {{734{VhelperZeros}} , {VhelperOnes} , {289{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd736) begin
	start_col_selector <= {{735{VhelperOnes}} , {289{VhelperZeros}}};
	input1_col_selector <= {{735{VhelperZeros}} , {VhelperOnes} , {288{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd737) begin
	start_col_selector <= {{736{VhelperOnes}} , {288{VhelperZeros}}};
	input1_col_selector <= {{736{VhelperZeros}} , {VhelperOnes} , {287{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd738) begin
	start_col_selector <= {{737{VhelperOnes}} , {287{VhelperZeros}}};
	input1_col_selector <= {{737{VhelperZeros}} , {VhelperOnes} , {286{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd739) begin
	start_col_selector <= {{738{VhelperOnes}} , {286{VhelperZeros}}};
	input1_col_selector <= {{738{VhelperZeros}} , {VhelperOnes} , {285{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd740) begin
	start_col_selector <= {{739{VhelperOnes}} , {285{VhelperZeros}}};
	input1_col_selector <= {{739{VhelperZeros}} , {VhelperOnes} , {284{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd741) begin
	start_col_selector <= {{740{VhelperOnes}} , {284{VhelperZeros}}};
	input1_col_selector <= {{740{VhelperZeros}} , {VhelperOnes} , {283{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd742) begin
	start_col_selector <= {{741{VhelperOnes}} , {283{VhelperZeros}}};
	input1_col_selector <= {{741{VhelperZeros}} , {VhelperOnes} , {282{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd743) begin
	start_col_selector <= {{742{VhelperOnes}} , {282{VhelperZeros}}};
	input1_col_selector <= {{742{VhelperZeros}} , {VhelperOnes} , {281{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd744) begin
	start_col_selector <= {{743{VhelperOnes}} , {281{VhelperZeros}}};
	input1_col_selector <= {{743{VhelperZeros}} , {VhelperOnes} , {280{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd745) begin
	start_col_selector <= {{744{VhelperOnes}} , {280{VhelperZeros}}};	
	input1_col_selector <= {{744{VhelperZeros}} , {VhelperOnes} , {279{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd746) begin
	start_col_selector <= {{745{VhelperOnes}} , {279{VhelperZeros}}};
	input1_col_selector <= {{745{VhelperZeros}} , {VhelperOnes} , {278{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd747) begin
	start_col_selector <= {{746{VhelperOnes}} , {278{VhelperZeros}}};
	input1_col_selector <= {{746{VhelperZeros}} , {VhelperOnes} , {277{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd748) begin
	start_col_selector <= {{747{VhelperOnes}} , {277{VhelperZeros}}};
	input1_col_selector <= {{747{VhelperZeros}} , {VhelperOnes} , {276{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd749) begin
	start_col_selector <= {{748{VhelperOnes}} , {276{VhelperZeros}}};
	input1_col_selector <= {{748{VhelperZeros}} , {VhelperOnes} , {275{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd750) begin
	start_col_selector <= {{749{VhelperOnes}} , {275{VhelperZeros}}};
	input1_col_selector <= {{749{VhelperZeros}} , {VhelperOnes} , {274{VhelperZeros}}};	
end




else if (inst[start_of_input1:end_of_input1] == 10'd751) begin
	start_col_selector <= {{750{VhelperOnes}} , {274{VhelperZeros}}};
	input1_col_selector <= {{750{VhelperZeros}} , {VhelperOnes} , {273{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd752) begin
	start_col_selector <= {{751{VhelperOnes}} , {273{VhelperZeros}}};
	input1_col_selector <= {{751{VhelperZeros}} , {VhelperOnes} , {272{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd753) begin
	start_col_selector <= {{752{VhelperOnes}} , {272{VhelperZeros}}};
	input1_col_selector <= {{752{VhelperZeros}} , {VhelperOnes} , {271{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd754) begin
	start_col_selector <= {{753{VhelperOnes}} , {271{VhelperZeros}}};
	input1_col_selector <= {{753{VhelperZeros}} , {VhelperOnes} , {270{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd755) begin
	start_col_selector <= {{754{VhelperOnes}} , {270{VhelperZeros}}};	
	input1_col_selector <= {{754{VhelperZeros}} , {VhelperOnes} , {269{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd756) begin
	start_col_selector <= {{755{VhelperOnes}} , {269{VhelperZeros}}};
	input1_col_selector <= {{755{VhelperZeros}} , {VhelperOnes} , {268{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd757) begin
	start_col_selector <= {{756{VhelperOnes}} , {268{VhelperZeros}}};
	input1_col_selector <= {{756{VhelperZeros}} , {VhelperOnes} , {267{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd758) begin
	start_col_selector <= {{757{VhelperOnes}} , {267{VhelperZeros}}};
	input1_col_selector <= {{757{VhelperZeros}} , {VhelperOnes} , {266{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd759) begin
	start_col_selector <= {{758{VhelperOnes}} , {266{VhelperZeros}}};
	input1_col_selector <= {{758{VhelperZeros}} , {VhelperOnes} , {265{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd760) begin
	start_col_selector <= {{759{VhelperOnes}} , {265{VhelperZeros}}};
	input1_col_selector <= {{759{VhelperZeros}} , {VhelperOnes} , {264{VhelperZeros}}};	
end











else if (inst[start_of_input1:end_of_input1] == 10'd761) begin
	start_col_selector <= {{760{VhelperOnes}} , {264{VhelperZeros}}};
	input1_col_selector <= {{760{VhelperZeros}} , {VhelperOnes} , {263{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd762) begin
	start_col_selector <= {{761{VhelperOnes}} , {263{VhelperZeros}}};
	input1_col_selector <= {{761{VhelperZeros}} , {VhelperOnes} , {262{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd763) begin
	start_col_selector <= {{762{VhelperOnes}} , {262{VhelperZeros}}};
	input1_col_selector <= {{762{VhelperZeros}} , {VhelperOnes} , {261{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd764) begin
	start_col_selector <= {{763{VhelperOnes}} , {261{VhelperZeros}}};
	input1_col_selector <= {{763{VhelperZeros}} , {VhelperOnes} , {260{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd765) begin
	start_col_selector <= {{764{VhelperOnes}} , {260{VhelperZeros}}};	
	input1_col_selector <= {{764{VhelperZeros}} , {VhelperOnes} , {259{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd766) begin
	start_col_selector <= {{765{VhelperOnes}} , {259{VhelperZeros}}};
	input1_col_selector <= {{765{VhelperZeros}} , {VhelperOnes} , {258{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd767) begin
	start_col_selector <= {{766{VhelperOnes}} , {258{VhelperZeros}}};
	input1_col_selector <= {{766{VhelperZeros}} , {VhelperOnes} , {257{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd768) begin
	start_col_selector <= {{767{VhelperOnes}} , {257{VhelperZeros}}};
	input1_col_selector <= {{767{VhelperZeros}} , {VhelperOnes} , {256{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd769) begin
	start_col_selector <= {{768{VhelperOnes}} , {256{VhelperZeros}}};
	input1_col_selector <= {{768{VhelperZeros}} , {VhelperOnes} , {255{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd770) begin
	start_col_selector <= {{769{VhelperOnes}} , {255{VhelperZeros}}};
	input1_col_selector <= {{769{VhelperZeros}} , {VhelperOnes} , {254{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd771) begin
	start_col_selector <= {{770{VhelperOnes}} , {254{VhelperZeros}}};
	input1_col_selector <= {{770{VhelperZeros}} , {VhelperOnes} , {253{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd772) begin
	start_col_selector <= {{771{VhelperOnes}} , {253{VhelperZeros}}};
	input1_col_selector <= {{771{VhelperZeros}} , {VhelperOnes} , {252{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd773) begin
	start_col_selector <= {{772{VhelperOnes}} , {252{VhelperZeros}}};
	input1_col_selector <= {{772{VhelperZeros}} , {VhelperOnes} , {251{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd774) begin
	start_col_selector <= {{773{VhelperOnes}} , {251{VhelperZeros}}};
	input1_col_selector <= {{773{VhelperZeros}} , {VhelperOnes} , {250{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd775) begin
	start_col_selector <= {{774{VhelperOnes}} , {250{VhelperZeros}}};	
	input1_col_selector <= {{774{VhelperZeros}} , {VhelperOnes} , {249{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd776) begin
	start_col_selector <= {{775{VhelperOnes}} , {249{VhelperZeros}}};
	input1_col_selector <= {{775{VhelperZeros}} , {VhelperOnes} , {248{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd777) begin
	start_col_selector <= {{776{VhelperOnes}} , {248{VhelperZeros}}};
	input1_col_selector <= {{776{VhelperZeros}} , {VhelperOnes} , {247{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd778) begin
	start_col_selector <= {{777{VhelperOnes}} , {247{VhelperZeros}}};
	input1_col_selector <= {{777{VhelperZeros}} , {VhelperOnes} , {246{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd779) begin
	start_col_selector <= {{778{VhelperOnes}} , {246{VhelperZeros}}};
	input1_col_selector <= {{778{VhelperZeros}} , {VhelperOnes} , {245{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd780) begin
	start_col_selector <= {{779{VhelperOnes}} , {245{VhelperZeros}}};
	input1_col_selector <= {{779{VhelperZeros}} , {VhelperOnes} , {244{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd781) begin
	start_col_selector <= {{780{VhelperOnes}} , {244{VhelperZeros}}};
	input1_col_selector <= {{780{VhelperZeros}} , {VhelperOnes} , {243{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd782) begin
	start_col_selector <= {{781{VhelperOnes}} , {243{VhelperZeros}}};
	input1_col_selector <= {{781{VhelperZeros}} , {VhelperOnes} , {242{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd783) begin
	start_col_selector <= {{782{VhelperOnes}} , {242{VhelperZeros}}};
	input1_col_selector <= {{782{VhelperZeros}} , {VhelperOnes} , {241{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd784) begin
	start_col_selector <= {{783{VhelperOnes}} , {241{VhelperZeros}}};
	input1_col_selector <= {{783{VhelperZeros}} , {VhelperOnes} , {240{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd785) begin
	start_col_selector <= {{784{VhelperOnes}} , {240{VhelperZeros}}};	
	input1_col_selector <= {{784{VhelperZeros}} , {VhelperOnes} , {239{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd786) begin
	start_col_selector <= {{785{VhelperOnes}} , {239{VhelperZeros}}};
	input1_col_selector <= {{785{VhelperZeros}} , {VhelperOnes} , {238{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd787) begin
	start_col_selector <= {{786{VhelperOnes}} , {238{VhelperZeros}}};
	input1_col_selector <= {{786{VhelperZeros}} , {VhelperOnes} , {237{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd788) begin
	start_col_selector <= {{787{VhelperOnes}} , {237{VhelperZeros}}};
	input1_col_selector <= {{787{VhelperZeros}} , {VhelperOnes} , {236{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd789) begin
	start_col_selector <= {{788{VhelperOnes}} , {236{VhelperZeros}}};
	input1_col_selector <= {{788{VhelperZeros}} , {VhelperOnes} , {235{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd790) begin
	start_col_selector <= {{789{VhelperOnes}} , {235{VhelperZeros}}};
	input1_col_selector <= {{789{VhelperZeros}} , {VhelperOnes} , {234{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd791) begin
	start_col_selector <= {{790{VhelperOnes}} , {234{VhelperZeros}}};
	input1_col_selector <= {{790{VhelperZeros}} , {VhelperOnes} , {233{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd792) begin
	start_col_selector <= {{791{VhelperOnes}} , {233{VhelperZeros}}};
	input1_col_selector <= {{791{VhelperZeros}} , {VhelperOnes} , {232{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd793) begin
	start_col_selector <= {{792{VhelperOnes}} , {232{VhelperZeros}}};
	input1_col_selector <= {{792{VhelperZeros}} , {VhelperOnes} , {231{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd794) begin
	start_col_selector <= {{793{VhelperOnes}} , {231{VhelperZeros}}};
	input1_col_selector <= {{793{VhelperZeros}} , {VhelperOnes} , {230{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd795) begin
	start_col_selector <= {{794{VhelperOnes}} , {230{VhelperZeros}}};	
	input1_col_selector <= {{794{VhelperZeros}} , {VhelperOnes} , {229{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd796) begin
	start_col_selector <= {{795{VhelperOnes}} , {229{VhelperZeros}}};
	input1_col_selector <= {{795{VhelperZeros}} , {VhelperOnes} , {228{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd797) begin
	start_col_selector <= {{796{VhelperOnes}} , {228{VhelperZeros}}};
	input1_col_selector <= {{796{VhelperZeros}} , {VhelperOnes} , {227{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd798) begin
	start_col_selector <= {{797{VhelperOnes}} , {227{VhelperZeros}}};
	input1_col_selector <= {{797{VhelperZeros}} , {VhelperOnes} , {226{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd799) begin
	start_col_selector <= {{798{VhelperOnes}} , {226{VhelperZeros}}};
	input1_col_selector <= {{798{VhelperZeros}} , {VhelperOnes} , {225{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd800) begin
	start_col_selector <= {{799{VhelperOnes}} , {225{VhelperZeros}}};
	input1_col_selector <= {{799{VhelperZeros}} , {VhelperOnes} , {224{VhelperZeros}}};	
end





else if (inst[start_of_input1:end_of_input1] == 10'd801) begin
	start_col_selector <= {{800{VhelperOnes}} , {224{VhelperZeros}}};
	input1_col_selector <= {{800{VhelperZeros}} , {VhelperOnes} , {223{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd802) begin
	start_col_selector <= {{801{VhelperOnes}} , {223{VhelperZeros}}};
	input1_col_selector <= {{801{VhelperZeros}} , {VhelperOnes} , {222{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd803) begin
	start_col_selector <= {{802{VhelperOnes}} , {222{VhelperZeros}}};
	input1_col_selector <= {{802{VhelperZeros}} , {VhelperOnes} , {221{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd804) begin
	start_col_selector <= {{803{VhelperOnes}} , {221{VhelperZeros}}};
	input1_col_selector <= {{803{VhelperZeros}} , {VhelperOnes} , {220{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd805) begin
	start_col_selector <= {{804{VhelperOnes}} , {220{VhelperZeros}}};	
	input1_col_selector <= {{804{VhelperZeros}} , {VhelperOnes} , {219{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd806) begin
	start_col_selector <= {{805{VhelperOnes}} , {219{VhelperZeros}}};
	input1_col_selector <= {{805{VhelperZeros}} , {VhelperOnes} , {218{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd807) begin
	start_col_selector <= {{806{VhelperOnes}} , {218{VhelperZeros}}};
	input1_col_selector <= {{806{VhelperZeros}} , {VhelperOnes} , {217{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd808) begin
	start_col_selector <= {{807{VhelperOnes}} , {217{VhelperZeros}}};
	input1_col_selector <= {{807{VhelperZeros}} , {VhelperOnes} , {216{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd809) begin
	start_col_selector <= {{808{VhelperOnes}} , {216{VhelperZeros}}};
	input1_col_selector <= {{808{VhelperZeros}} , {VhelperOnes} , {215{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd810) begin
	start_col_selector <= {{809{VhelperOnes}} , {215{VhelperZeros}}};
	input1_col_selector <= {{809{VhelperZeros}} , {VhelperOnes} , {214{VhelperZeros}}};	
end













else if (inst[start_of_input1:end_of_input1] == 10'd811) begin
	start_col_selector <= {{810{VhelperOnes}} , {214{VhelperZeros}}};
	input1_col_selector <= {{810{VhelperZeros}} , {VhelperOnes} , {213{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd812) begin
	start_col_selector <= {{811{VhelperOnes}} , {213{VhelperZeros}}};
	input1_col_selector <= {{811{VhelperZeros}} , {VhelperOnes} , {212{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd813) begin
	start_col_selector <= {{812{VhelperOnes}} , {212{VhelperZeros}}};
	input1_col_selector <= {{812{VhelperZeros}} , {VhelperOnes} , {211{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd814) begin
	start_col_selector <= {{813{VhelperOnes}} , {211{VhelperZeros}}};
	input1_col_selector <= {{813{VhelperZeros}} , {VhelperOnes} , {210{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd815) begin
	start_col_selector <= {{814{VhelperOnes}} , {210{VhelperZeros}}};	
	input1_col_selector <= {{814{VhelperZeros}} , {VhelperOnes} , {209{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd816) begin
	start_col_selector <= {{815{VhelperOnes}} , {209{VhelperZeros}}};
	input1_col_selector <= {{815{VhelperZeros}} , {VhelperOnes} , {208{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd817) begin
	start_col_selector <= {{816{VhelperOnes}} , {208{VhelperZeros}}};
	input1_col_selector <= {{816{VhelperZeros}} , {VhelperOnes} , {207{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd818) begin
	start_col_selector <= {{817{VhelperOnes}} , {207{VhelperZeros}}};
	input1_col_selector <= {{817{VhelperZeros}} , {VhelperOnes} , {206{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd819) begin
	start_col_selector <= {{818{VhelperOnes}} , {206{VhelperZeros}}};
	input1_col_selector <= {{818{VhelperZeros}} , {VhelperOnes} , {205{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd820) begin
	start_col_selector <= {{819{VhelperOnes}} , {205{VhelperZeros}}};
	input1_col_selector <= {{819{VhelperZeros}} , {VhelperOnes} , {204{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd821) begin
	start_col_selector <= {{820{VhelperOnes}} , {204{VhelperZeros}}};
	input1_col_selector <= {{820{VhelperZeros}} , {VhelperOnes} , {203{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd822) begin
	start_col_selector <= {{821{VhelperOnes}} , {203{VhelperZeros}}};
	input1_col_selector <= {{821{VhelperZeros}} , {VhelperOnes} , {202{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd823) begin
	start_col_selector <= {{822{VhelperOnes}} , {202{VhelperZeros}}};
	input1_col_selector <= {{822{VhelperZeros}} , {VhelperOnes} , {201{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd824) begin
	start_col_selector <= {{823{VhelperOnes}} , {201{VhelperZeros}}};
	input1_col_selector <= {{823{VhelperZeros}} , {VhelperOnes} , {200{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd825) begin
	start_col_selector <= {{824{VhelperOnes}} , {200{VhelperZeros}}};	
	input1_col_selector <= {{824{VhelperZeros}} , {VhelperOnes} , {199{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd826) begin
	start_col_selector <= {{825{VhelperOnes}} , {199{VhelperZeros}}};
	input1_col_selector <= {{825{VhelperZeros}} , {VhelperOnes} , {198{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd827) begin
	start_col_selector <= {{826{VhelperOnes}} , {198{VhelperZeros}}};
	input1_col_selector <= {{826{VhelperZeros}} , {VhelperOnes} , {197{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd828) begin
	start_col_selector <= {{827{VhelperOnes}} , {197{VhelperZeros}}};
	input1_col_selector <= {{827{VhelperZeros}} , {VhelperOnes} , {196{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd829) begin
	start_col_selector <= {{828{VhelperOnes}} , {196{VhelperZeros}}};
	input1_col_selector <= {{828{VhelperZeros}} , {VhelperOnes} , {195{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd830) begin
	start_col_selector <= {{829{VhelperOnes}} , {195{VhelperZeros}}};
	input1_col_selector <= {{829{VhelperZeros}} , {VhelperOnes} , {194{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd831) begin
	start_col_selector <= {{830{VhelperOnes}} , {194{VhelperZeros}}};
	input1_col_selector <= {{830{VhelperZeros}} , {VhelperOnes} , {193{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd832) begin
	start_col_selector <= {{831{VhelperOnes}} , {193{VhelperZeros}}};
	input1_col_selector <= {{831{VhelperZeros}} , {VhelperOnes} , {192{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd833) begin
	start_col_selector <= {{832{VhelperOnes}} , {192{VhelperZeros}}};
	input1_col_selector <= {{832{VhelperZeros}} , {VhelperOnes} , {191{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd834) begin
	start_col_selector <= {{833{VhelperOnes}} , {191{VhelperZeros}}};
	input1_col_selector <= {{833{VhelperZeros}} , {VhelperOnes} , {190{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd835) begin
	start_col_selector <= {{834{VhelperOnes}} , {190{VhelperZeros}}};	
	input1_col_selector <= {{834{VhelperZeros}} , {VhelperOnes} , {189{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd836) begin
	start_col_selector <= {{835{VhelperOnes}} , {189{VhelperZeros}}};
	input1_col_selector <= {{835{VhelperZeros}} , {VhelperOnes} , {188{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd837) begin
	start_col_selector <= {{836{VhelperOnes}} , {188{VhelperZeros}}};
	input1_col_selector <= {{836{VhelperZeros}} , {VhelperOnes} , {187{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd838) begin
	start_col_selector <= {{837{VhelperOnes}} , {187{VhelperZeros}}};
	input1_col_selector <= {{837{VhelperZeros}} , {VhelperOnes} , {186{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd839) begin
	start_col_selector <= {{838{VhelperOnes}} , {186{VhelperZeros}}};
	input1_col_selector <= {{838{VhelperZeros}} , {VhelperOnes} , {185{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd840) begin
	start_col_selector <= {{839{VhelperOnes}} , {185{VhelperZeros}}};
	input1_col_selector <= {{839{VhelperZeros}} , {VhelperOnes} , {184{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd841) begin
	start_col_selector <= {{840{VhelperOnes}} , {184{VhelperZeros}}};
	input1_col_selector <= {{840{VhelperZeros}} , {VhelperOnes} , {183{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd842) begin
	start_col_selector <= {{841{VhelperOnes}} , {183{VhelperZeros}}};
	input1_col_selector <= {{841{VhelperZeros}} , {VhelperOnes} , {182{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd843) begin
	start_col_selector <= {{842{VhelperOnes}} , {182{VhelperZeros}}};
	input1_col_selector <= {{842{VhelperZeros}} , {VhelperOnes} , {181{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd844) begin
	start_col_selector <= {{843{VhelperOnes}} , {181{VhelperZeros}}};
	input1_col_selector <= {{843{VhelperZeros}} , {VhelperOnes} , {180{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd845) begin
	start_col_selector <= {{844{VhelperOnes}} , {180{VhelperZeros}}};	
	input1_col_selector <= {{844{VhelperZeros}} , {VhelperOnes} , {179{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd846) begin
	start_col_selector <= {{845{VhelperOnes}} , {179{VhelperZeros}}};
	input1_col_selector <= {{845{VhelperZeros}} , {VhelperOnes} , {178{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd847) begin
	start_col_selector <= {{846{VhelperOnes}} , {178{VhelperZeros}}};
	input1_col_selector <= {{846{VhelperZeros}} , {VhelperOnes} , {177{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd848) begin
	start_col_selector <= {{847{VhelperOnes}} , {177{VhelperZeros}}};
	input1_col_selector <= {{847{VhelperZeros}} , {VhelperOnes} , {176{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd849) begin
	start_col_selector <= {{848{VhelperOnes}} , {176{VhelperZeros}}};
	input1_col_selector <= {{848{VhelperZeros}} , {VhelperOnes} , {175{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd850) begin
	start_col_selector <= {{849{VhelperOnes}} , {175{VhelperZeros}}};
	input1_col_selector <= {{849{VhelperZeros}} , {VhelperOnes} , {174{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd851) begin
	start_col_selector <= {{850{VhelperOnes}} , {174{VhelperZeros}}};
	input1_col_selector <= {{850{VhelperZeros}} , {VhelperOnes} , {173{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd852) begin
	start_col_selector <= {{851{VhelperOnes}} , {173{VhelperZeros}}};
	input1_col_selector <= {{851{VhelperZeros}} , {VhelperOnes} , {172{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd853) begin
	start_col_selector <= {{852{VhelperOnes}} , {172{VhelperZeros}}};
	input1_col_selector <= {{852{VhelperZeros}} , {VhelperOnes} , {171{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd854) begin
	start_col_selector <= {{853{VhelperOnes}} , {171{VhelperZeros}}};
	input1_col_selector <= {{853{VhelperZeros}} , {VhelperOnes} , {170{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd855) begin
	start_col_selector <= {{854{VhelperOnes}} , {170{VhelperZeros}}};	
	input1_col_selector <= {{854{VhelperZeros}} , {VhelperOnes} , {169{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd856) begin
	start_col_selector <= {{855{VhelperOnes}} , {169{VhelperZeros}}};
	input1_col_selector <= {{855{VhelperZeros}} , {VhelperOnes} , {168{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd857) begin
	start_col_selector <= {{856{VhelperOnes}} , {168{VhelperZeros}}};
	input1_col_selector <= {{856{VhelperZeros}} , {VhelperOnes} , {167{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd858) begin
	start_col_selector <= {{857{VhelperOnes}} , {167{VhelperZeros}}};
	input1_col_selector <= {{857{VhelperZeros}} , {VhelperOnes} , {166{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd859) begin
	start_col_selector <= {{858{VhelperOnes}} , {166{VhelperZeros}}};
	input1_col_selector <= {{858{VhelperZeros}} , {VhelperOnes} , {165{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd860) begin
	start_col_selector <= {{859{VhelperOnes}} , {165{VhelperZeros}}};
	input1_col_selector <= {{859{VhelperZeros}} , {VhelperOnes} , {164{VhelperZeros}}};	
end












else if (inst[start_of_input1:end_of_input1] == 10'd861) begin
	start_col_selector <= {{860{VhelperOnes}} , {164{VhelperZeros}}};
	input1_col_selector <= {{860{VhelperZeros}} , {VhelperOnes} , {163{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd862) begin
	start_col_selector <= {{861{VhelperOnes}} , {163{VhelperZeros}}};
	input1_col_selector <= {{861{VhelperZeros}} , {VhelperOnes} , {162{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd863) begin
	start_col_selector <= {{862{VhelperOnes}} , {162{VhelperZeros}}};
	input1_col_selector <= {{862{VhelperZeros}} , {VhelperOnes} , {161{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd864) begin
	start_col_selector <= {{863{VhelperOnes}} , {161{VhelperZeros}}};
	input1_col_selector <= {{863{VhelperZeros}} , {VhelperOnes} , {160{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd865) begin
	start_col_selector <= {{864{VhelperOnes}} , {160{VhelperZeros}}};	
	input1_col_selector <= {{864{VhelperZeros}} , {VhelperOnes} , {159{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd866) begin
	start_col_selector <= {{865{VhelperOnes}} , {159{VhelperZeros}}};
	input1_col_selector <= {{865{VhelperZeros}} , {VhelperOnes} , {158{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd867) begin
	start_col_selector <= {{866{VhelperOnes}} , {158{VhelperZeros}}};
	input1_col_selector <= {{866{VhelperZeros}} , {VhelperOnes} , {157{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd868) begin
	start_col_selector <= {{867{VhelperOnes}} , {157{VhelperZeros}}};
	input1_col_selector <= {{867{VhelperZeros}} , {VhelperOnes} , {156{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd869) begin
	start_col_selector <= {{868{VhelperOnes}} , {156{VhelperZeros}}};
	input1_col_selector <= {{868{VhelperZeros}} , {VhelperOnes} , {155{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd870) begin
	start_col_selector <= {{869{VhelperOnes}} , {155{VhelperZeros}}};
	input1_col_selector <= {{869{VhelperZeros}} , {VhelperOnes} , {154{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd871) begin
	start_col_selector <= {{870{VhelperOnes}} , {154{VhelperZeros}}};
	input1_col_selector <= {{870{VhelperZeros}} , {VhelperOnes} , {153{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd872) begin
	start_col_selector <= {{871{VhelperOnes}} , {153{VhelperZeros}}};
	input1_col_selector <= {{871{VhelperZeros}} , {VhelperOnes} , {152{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd873) begin
	start_col_selector <= {{872{VhelperOnes}} , {152{VhelperZeros}}};
	input1_col_selector <= {{872{VhelperZeros}} , {VhelperOnes} , {151{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd874) begin
	start_col_selector <= {{873{VhelperOnes}} , {151{VhelperZeros}}};
	input1_col_selector <= {{873{VhelperZeros}} , {VhelperOnes} , {150{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd875) begin
	start_col_selector <= {{874{VhelperOnes}} , {150{VhelperZeros}}};	
	input1_col_selector <= {{874{VhelperZeros}} , {VhelperOnes} , {149{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd876) begin
	start_col_selector <= {{875{VhelperOnes}} , {149{VhelperZeros}}};
	input1_col_selector <= {{875{VhelperZeros}} , {VhelperOnes} , {148{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd877) begin
	start_col_selector <= {{876{VhelperOnes}} , {148{VhelperZeros}}};
	input1_col_selector <= {{876{VhelperZeros}} , {VhelperOnes} , {147{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd878) begin
	start_col_selector <= {{877{VhelperOnes}} , {147{VhelperZeros}}};
	input1_col_selector <= {{877{VhelperZeros}} , {VhelperOnes} , {146{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd879) begin
	start_col_selector <= {{878{VhelperOnes}} , {146{VhelperZeros}}};
	input1_col_selector <= {{878{VhelperZeros}} , {VhelperOnes} , {145{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd880) begin
	start_col_selector <= {{879{VhelperOnes}} , {145{VhelperZeros}}};
	input1_col_selector <= {{879{VhelperZeros}} , {VhelperOnes} , {144{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd881) begin
	start_col_selector <= {{880{VhelperOnes}} , {144{VhelperZeros}}};
	input1_col_selector <= {{880{VhelperZeros}} , {VhelperOnes} , {143{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd882) begin
	start_col_selector <= {{881{VhelperOnes}} , {143{VhelperZeros}}};
	input1_col_selector <= {{881{VhelperZeros}} , {VhelperOnes} , {142{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd883) begin
	start_col_selector <= {{882{VhelperOnes}} , {142{VhelperZeros}}};
	input1_col_selector <= {{882{VhelperZeros}} , {VhelperOnes} , {141{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd884) begin
	start_col_selector <= {{883{VhelperOnes}} , {141{VhelperZeros}}};
	input1_col_selector <= {{883{VhelperZeros}} , {VhelperOnes} , {140{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd885) begin
	start_col_selector <= {{884{VhelperOnes}} , {140{VhelperZeros}}};	
	input1_col_selector <= {{884{VhelperZeros}} , {VhelperOnes} , {139{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd886) begin
	start_col_selector <= {{885{VhelperOnes}} , {139{VhelperZeros}}};
	input1_col_selector <= {{885{VhelperZeros}} , {VhelperOnes} , {138{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd887) begin
	start_col_selector <= {{886{VhelperOnes}} , {138{VhelperZeros}}};
	input1_col_selector <= {{886{VhelperZeros}} , {VhelperOnes} , {137{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd888) begin
	start_col_selector <= {{887{VhelperOnes}} , {137{VhelperZeros}}};
	input1_col_selector <= {{887{VhelperZeros}} , {VhelperOnes} , {136{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd889) begin
	start_col_selector <= {{888{VhelperOnes}} , {136{VhelperZeros}}};
	input1_col_selector <= {{888{VhelperZeros}} , {VhelperOnes} , {135{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd890) begin
	start_col_selector <= {{889{VhelperOnes}} , {135{VhelperZeros}}};
	input1_col_selector <= {{889{VhelperZeros}} , {VhelperOnes} , {134{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd891) begin
	start_col_selector <= {{890{VhelperOnes}} , {134{VhelperZeros}}};
	input1_col_selector <= {{890{VhelperZeros}} , {VhelperOnes} , {133{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd892) begin
	start_col_selector <= {{891{VhelperOnes}} , {133{VhelperZeros}}};
	input1_col_selector <= {{891{VhelperZeros}} , {VhelperOnes} , {132{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd893) begin
	start_col_selector <= {{892{VhelperOnes}} , {132{VhelperZeros}}};
	input1_col_selector <= {{892{VhelperZeros}} , {VhelperOnes} , {131{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd894) begin
	start_col_selector <= {{893{VhelperOnes}} , {131{VhelperZeros}}};
	input1_col_selector <= {{893{VhelperZeros}} , {VhelperOnes} , {130{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd895) begin
	start_col_selector <= {{894{VhelperOnes}} , {130{VhelperZeros}}};	
	input1_col_selector <= {{894{VhelperZeros}} , {VhelperOnes} , {129{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd896) begin
	start_col_selector <= {{895{VhelperOnes}} , {129{VhelperZeros}}};
	input1_col_selector <= {{895{VhelperZeros}} , {VhelperOnes} , {128{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd897) begin
	start_col_selector <= {{896{VhelperOnes}} , {128{VhelperZeros}}};
	input1_col_selector <= {{896{VhelperZeros}} , {VhelperOnes} , {127{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd898) begin
	start_col_selector <= {{897{VhelperOnes}} , {127{VhelperZeros}}};
	input1_col_selector <= {{897{VhelperZeros}} , {VhelperOnes} , {126{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd899) begin
	start_col_selector <= {{898{VhelperOnes}} , {126{VhelperZeros}}};
	input1_col_selector <= {{898{VhelperZeros}} , {VhelperOnes} , {125{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd900) begin
	start_col_selector <= {{899{VhelperOnes}} , {125{VhelperZeros}}};
	input1_col_selector <= {{899{VhelperZeros}} , {VhelperOnes} , {124{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd901) begin
	start_col_selector <= {{900{VhelperOnes}} , {124{VhelperZeros}}};
	input1_col_selector <= {{900{VhelperZeros}} , {VhelperOnes} , {123{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd902) begin
	start_col_selector <= {{901{VhelperOnes}} , {123{VhelperZeros}}};
	input1_col_selector <= {{901{VhelperZeros}} , {VhelperOnes} , {122{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd903) begin
	start_col_selector <= {{902{VhelperOnes}} , {122{VhelperZeros}}};
	input1_col_selector <= {{902{VhelperZeros}} , {VhelperOnes} , {121{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd904) begin
	start_col_selector <= {{903{VhelperOnes}} , {121{VhelperZeros}}};
	input1_col_selector <= {{903{VhelperZeros}} , {VhelperOnes} , {120{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd905) begin
	start_col_selector <= {{904{VhelperOnes}} , {120{VhelperZeros}}};	
	input1_col_selector <= {{904{VhelperZeros}} , {VhelperOnes} , {119{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd906) begin
	start_col_selector <= {{905{VhelperOnes}} , {119{VhelperZeros}}};
	input1_col_selector <= {{905{VhelperZeros}} , {VhelperOnes} , {118{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd907) begin
	start_col_selector <= {{906{VhelperOnes}} , {118{VhelperZeros}}};
	input1_col_selector <= {{906{VhelperZeros}} , {VhelperOnes} , {117{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd908) begin
	start_col_selector <= {{907{VhelperOnes}} , {117{VhelperZeros}}};
	input1_col_selector <= {{907{VhelperZeros}} , {VhelperOnes} , {116{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd909) begin
	start_col_selector <= {{908{VhelperOnes}} , {116{VhelperZeros}}};
	input1_col_selector <= {{908{VhelperZeros}} , {VhelperOnes} , {115{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd910) begin
	start_col_selector <= {{909{VhelperOnes}} , {115{VhelperZeros}}};
	input1_col_selector <= {{909{VhelperZeros}} , {VhelperOnes} , {114{VhelperZeros}}};	
end















else if (inst[start_of_input1:end_of_input1] == 10'd911) begin
	start_col_selector <= {{910{VhelperOnes}} , {114{VhelperZeros}}};
	input1_col_selector <= {{910{VhelperZeros}} , {VhelperOnes} , {113{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd912) begin
	start_col_selector <= {{911{VhelperOnes}} , {113{VhelperZeros}}};
	input1_col_selector <= {{911{VhelperZeros}} , {VhelperOnes} , {112{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd913) begin
	start_col_selector <= {{912{VhelperOnes}} , {112{VhelperZeros}}};
	input1_col_selector <= {{912{VhelperZeros}} , {VhelperOnes} , {111{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd914) begin
	start_col_selector <= {{913{VhelperOnes}} , {111{VhelperZeros}}};
	input1_col_selector <= {{913{VhelperZeros}} , {VhelperOnes} , {110{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd915) begin
	start_col_selector <= {{914{VhelperOnes}} , {110{VhelperZeros}}};	
	input1_col_selector <= {{914{VhelperZeros}} , {VhelperOnes} , {109{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd916) begin
	start_col_selector <= {{915{VhelperOnes}} , {109{VhelperZeros}}};
	input1_col_selector <= {{915{VhelperZeros}} , {VhelperOnes} , {108{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd917) begin
	start_col_selector <= {{916{VhelperOnes}} , {108{VhelperZeros}}};
	input1_col_selector <= {{916{VhelperZeros}} , {VhelperOnes} , {107{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd918) begin
	start_col_selector <= {{917{VhelperOnes}} , {107{VhelperZeros}}};
	input1_col_selector <= {{917{VhelperZeros}} , {VhelperOnes} , {106{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd919) begin
	start_col_selector <= {{918{VhelperOnes}} , {106{VhelperZeros}}};
	input1_col_selector <= {{918{VhelperZeros}} , {VhelperOnes} , {105{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd920) begin
	start_col_selector <= {{919{VhelperOnes}} , {105{VhelperZeros}}};
	input1_col_selector <= {{919{VhelperZeros}} , {VhelperOnes} , {104{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd921) begin
	start_col_selector <= {{920{VhelperOnes}} , {104{VhelperZeros}}};
	input1_col_selector <= {{920{VhelperZeros}} , {VhelperOnes} , {103{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd922) begin
	start_col_selector <= {{921{VhelperOnes}} , {103{VhelperZeros}}};
	input1_col_selector <= {{921{VhelperZeros}} , {VhelperOnes} , {102{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd923) begin
	start_col_selector <= {{922{VhelperOnes}} , {102{VhelperZeros}}};
	input1_col_selector <= {{922{VhelperZeros}} , {VhelperOnes} , {101{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd924) begin
	start_col_selector <= {{923{VhelperOnes}} , {101{VhelperZeros}}};
	input1_col_selector <= {{923{VhelperZeros}} , {VhelperOnes} , {100{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd925) begin
	start_col_selector <= {{924{VhelperOnes}} , {100{VhelperZeros}}};	
	input1_col_selector <= {{924{VhelperZeros}} , {VhelperOnes} , {99{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd926) begin
	start_col_selector <= {{925{VhelperOnes}} , {99{VhelperZeros}}};
	input1_col_selector <= {{925{VhelperZeros}} , {VhelperOnes} , {98{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd927) begin
	start_col_selector <= {{926{VhelperOnes}} , {98{VhelperZeros}}};
	input1_col_selector <= {{926{VhelperZeros}} , {VhelperOnes} , {97{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd928) begin
	start_col_selector <= {{927{VhelperOnes}} , {97{VhelperZeros}}};
	input1_col_selector <= {{927{VhelperZeros}} , {VhelperOnes} , {96{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd929) begin
	start_col_selector <= {{928{VhelperOnes}} , {96{VhelperZeros}}};
	input1_col_selector <= {{928{VhelperZeros}} , {VhelperOnes} , {95{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd930) begin
	start_col_selector <= {{929{VhelperOnes}} , {95{VhelperZeros}}};
	input1_col_selector <= {{929{VhelperZeros}} , {VhelperOnes} , {94{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd931) begin
	start_col_selector <= {{930{VhelperOnes}} , {94{VhelperZeros}}};
	input1_col_selector <= {{930{VhelperZeros}} , {VhelperOnes} , {93{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd932) begin
	start_col_selector <= {{931{VhelperOnes}} , {93{VhelperZeros}}};
	input1_col_selector <= {{931{VhelperZeros}} , {VhelperOnes} , {92{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd933) begin
	start_col_selector <= {{932{VhelperOnes}} , {92{VhelperZeros}}};
	input1_col_selector <= {{932{VhelperZeros}} , {VhelperOnes} , {91{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd934) begin
	start_col_selector <= {{933{VhelperOnes}} , {91{VhelperZeros}}};
	input1_col_selector <= {{933{VhelperZeros}} , {VhelperOnes} , {90{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd935) begin
	start_col_selector <= {{934{VhelperOnes}} , {90{VhelperZeros}}};	
	input1_col_selector <= {{934{VhelperZeros}} , {VhelperOnes} , {89{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd936) begin
	start_col_selector <= {{935{VhelperOnes}} , {89{VhelperZeros}}};
	input1_col_selector <= {{935{VhelperZeros}} , {VhelperOnes} , {88{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd937) begin
	start_col_selector <= {{936{VhelperOnes}} , {88{VhelperZeros}}};
	input1_col_selector <= {{936{VhelperZeros}} , {VhelperOnes} , {87{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd938) begin
	start_col_selector <= {{937{VhelperOnes}} , {87{VhelperZeros}}};
	input1_col_selector <= {{937{VhelperZeros}} , {VhelperOnes} , {86{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd939) begin
	start_col_selector <= {{938{VhelperOnes}} , {86{VhelperZeros}}};
	input1_col_selector <= {{938{VhelperZeros}} , {VhelperOnes} , {85{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd940) begin
	start_col_selector <= {{939{VhelperOnes}} , {85{VhelperZeros}}};
	input1_col_selector <= {{939{VhelperZeros}} , {VhelperOnes} , {84{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd941) begin
	start_col_selector <= {{940{VhelperOnes}} , {84{VhelperZeros}}};
	input1_col_selector <= {{940{VhelperZeros}} , {VhelperOnes} , {83{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd942) begin
	start_col_selector <= {{941{VhelperOnes}} , {83{VhelperZeros}}};
	input1_col_selector <= {{941{VhelperZeros}} , {VhelperOnes} , {82{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd943) begin
	start_col_selector <= {{942{VhelperOnes}} , {82{VhelperZeros}}};
	input1_col_selector <= {{942{VhelperZeros}} , {VhelperOnes} , {81{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd944) begin
	start_col_selector <= {{943{VhelperOnes}} , {81{VhelperZeros}}};
	input1_col_selector <= {{943{VhelperZeros}} , {VhelperOnes} , {80{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd945) begin
	start_col_selector <= {{944{VhelperOnes}} , {80{VhelperZeros}}};	
	input1_col_selector <= {{944{VhelperZeros}} , {VhelperOnes} , {79{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd946) begin
	start_col_selector <= {{945{VhelperOnes}} , {79{VhelperZeros}}};
	input1_col_selector <= {{945{VhelperZeros}} , {VhelperOnes} , {78{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd947) begin
	start_col_selector <= {{946{VhelperOnes}} , {78{VhelperZeros}}};
	input1_col_selector <= {{946{VhelperZeros}} , {VhelperOnes} , {77{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd948) begin
	start_col_selector <= {{947{VhelperOnes}} , {77{VhelperZeros}}};
	input1_col_selector <= {{947{VhelperZeros}} , {VhelperOnes} , {76{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd949) begin
	start_col_selector <= {{948{VhelperOnes}} , {76{VhelperZeros}}};
	input1_col_selector <= {{948{VhelperZeros}} , {VhelperOnes} , {75{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd950) begin
	start_col_selector <= {{949{VhelperOnes}} , {75{VhelperZeros}}};
	input1_col_selector <= {{949{VhelperZeros}} , {VhelperOnes} , {74{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd951) begin
	start_col_selector <= {{950{VhelperOnes}} , {74{VhelperZeros}}};
	input1_col_selector <= {{950{VhelperZeros}} , {VhelperOnes} , {73{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd952) begin
	start_col_selector <= {{951{VhelperOnes}} , {73{VhelperZeros}}};
	input1_col_selector <= {{951{VhelperZeros}} , {VhelperOnes} , {72{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd953) begin
	start_col_selector <= {{952{VhelperOnes}} , {72{VhelperZeros}}};
	input1_col_selector <= {{952{VhelperZeros}} , {VhelperOnes} , {71{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd954) begin
	start_col_selector <= {{953{VhelperOnes}} , {71{VhelperZeros}}};
	input1_col_selector <= {{953{VhelperZeros}} , {VhelperOnes} , {70{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd955) begin
	start_col_selector <= {{954{VhelperOnes}} , {70{VhelperZeros}}};	
	input1_col_selector <= {{954{VhelperZeros}} , {VhelperOnes} , {69{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd956) begin
	start_col_selector <= {{955{VhelperOnes}} , {69{VhelperZeros}}};
	input1_col_selector <= {{955{VhelperZeros}} , {VhelperOnes} , {68{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd957) begin
	start_col_selector <= {{956{VhelperOnes}} , {68{VhelperZeros}}};
	input1_col_selector <= {{956{VhelperZeros}} , {VhelperOnes} , {67{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd958) begin
	start_col_selector <= {{957{VhelperOnes}} , {67{VhelperZeros}}};
	input1_col_selector <= {{957{VhelperZeros}} , {VhelperOnes} , {66{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd959) begin
	start_col_selector <= {{958{VhelperOnes}} , {66{VhelperZeros}}};
	input1_col_selector <= {{958{VhelperZeros}} , {VhelperOnes} , {65{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd960) begin
	start_col_selector <= {{959{VhelperOnes}} , {65{VhelperZeros}}};
	input1_col_selector <= {{959{VhelperZeros}} , {VhelperOnes} , {64{VhelperZeros}}};	
end












else if (inst[start_of_input1:end_of_input1] == 10'd961) begin
	start_col_selector <= {{960{VhelperOnes}} , {64{VhelperZeros}}};
	input1_col_selector <= {{960{VhelperZeros}} , {VhelperOnes} , {63{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd962) begin
	start_col_selector <= {{961{VhelperOnes}} , {63{VhelperZeros}}};
	input1_col_selector <= {{961{VhelperZeros}} , {VhelperOnes} , {62{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd963) begin
	start_col_selector <= {{962{VhelperOnes}} , {62{VhelperZeros}}};
	input1_col_selector <= {{962{VhelperZeros}} , {VhelperOnes} , {61{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd964) begin
	start_col_selector <= {{963{VhelperOnes}} , {61{VhelperZeros}}};
	input1_col_selector <= {{963{VhelperZeros}} , {VhelperOnes} , {60{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd965) begin
	start_col_selector <= {{964{VhelperOnes}} , {60{VhelperZeros}}};	
	input1_col_selector <= {{964{VhelperZeros}} , {VhelperOnes} , {59{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd966) begin
	start_col_selector <= {{965{VhelperOnes}} , {59{VhelperZeros}}};
	input1_col_selector <= {{965{VhelperZeros}} , {VhelperOnes} , {58{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd967) begin
	start_col_selector <= {{966{VhelperOnes}} , {58{VhelperZeros}}};
	input1_col_selector <= {{966{VhelperZeros}} , {VhelperOnes} , {57{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd968) begin
	start_col_selector <= {{967{VhelperOnes}} , {57{VhelperZeros}}};
	input1_col_selector <= {{967{VhelperZeros}} , {VhelperOnes} , {56{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd969) begin
	start_col_selector <= {{968{VhelperOnes}} , {56{VhelperZeros}}};
	input1_col_selector <= {{968{VhelperZeros}} , {VhelperOnes} , {55{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd970) begin
	start_col_selector <= {{969{VhelperOnes}} , {55{VhelperZeros}}};
	input1_col_selector <= {{969{VhelperZeros}} , {VhelperOnes} , {54{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd971) begin
	start_col_selector <= {{970{VhelperOnes}} , {54{VhelperZeros}}};
	input1_col_selector <= {{970{VhelperZeros}} , {VhelperOnes} , {53{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd972) begin
	start_col_selector <= {{971{VhelperOnes}} , {53{VhelperZeros}}};
	input1_col_selector <= {{971{VhelperZeros}} , {VhelperOnes} , {52{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd973) begin
	start_col_selector <= {{972{VhelperOnes}} , {52{VhelperZeros}}};
	input1_col_selector <= {{972{VhelperZeros}} , {VhelperOnes} , {51{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd974) begin
	start_col_selector <= {{973{VhelperOnes}} , {51{VhelperZeros}}};
	input1_col_selector <= {{973{VhelperZeros}} , {VhelperOnes} , {50{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd975) begin
	start_col_selector <= {{974{VhelperOnes}} , {50{VhelperZeros}}};	
	input1_col_selector <= {{974{VhelperZeros}} , {VhelperOnes} , {49{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd976) begin
	start_col_selector <= {{975{VhelperOnes}} , {49{VhelperZeros}}};
	input1_col_selector <= {{975{VhelperZeros}} , {VhelperOnes} , {48{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd977) begin
	start_col_selector <= {{976{VhelperOnes}} , {48{VhelperZeros}}};
	input1_col_selector <= {{976{VhelperZeros}} , {VhelperOnes} , {47{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd978) begin
	start_col_selector <= {{977{VhelperOnes}} , {47{VhelperZeros}}};
	input1_col_selector <= {{977{VhelperZeros}} , {VhelperOnes} , {46{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd979) begin
	start_col_selector <= {{978{VhelperOnes}} , {46{VhelperZeros}}};
	input1_col_selector <= {{978{VhelperZeros}} , {VhelperOnes} , {45{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd980) begin
	start_col_selector <= {{979{VhelperOnes}} , {45{VhelperZeros}}};
	input1_col_selector <= {{979{VhelperZeros}} , {VhelperOnes} , {44{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd981) begin
	start_col_selector <= {{980{VhelperOnes}} , {44{VhelperZeros}}};
	input1_col_selector <= {{980{VhelperZeros}} , {VhelperOnes} , {43{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd982) begin
	start_col_selector <= {{981{VhelperOnes}} , {43{VhelperZeros}}};
	input1_col_selector <= {{981{VhelperZeros}} , {VhelperOnes} , {42{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd983) begin
	start_col_selector <= {{982{VhelperOnes}} , {42{VhelperZeros}}};
	input1_col_selector <= {{982{VhelperZeros}} , {VhelperOnes} , {41{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd984) begin
	start_col_selector <= {{983{VhelperOnes}} , {41{VhelperZeros}}};
	input1_col_selector <= {{983{VhelperZeros}} , {VhelperOnes} , {40{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd985) begin
	start_col_selector <= {{984{VhelperOnes}} , {40{VhelperZeros}}};	
	input1_col_selector <= {{984{VhelperZeros}} , {VhelperOnes} , {39{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd986) begin
	start_col_selector <= {{985{VhelperOnes}} , {39{VhelperZeros}}};
	input1_col_selector <= {{985{VhelperZeros}} , {VhelperOnes} , {38{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd987) begin
	start_col_selector <= {{986{VhelperOnes}} , {38{VhelperZeros}}};
	input1_col_selector <= {{986{VhelperZeros}} , {VhelperOnes} , {37{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd988) begin
	start_col_selector <= {{987{VhelperOnes}} , {37{VhelperZeros}}};
	input1_col_selector <= {{987{VhelperZeros}} , {VhelperOnes} , {36{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd989) begin
	start_col_selector <= {{988{VhelperOnes}} , {36{VhelperZeros}}};
	input1_col_selector <= {{988{VhelperZeros}} , {VhelperOnes} , {35{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd990) begin
	start_col_selector <= {{989{VhelperOnes}} , {35{VhelperZeros}}};
	input1_col_selector <= {{989{VhelperZeros}} , {VhelperOnes} , {34{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd991) begin
	start_col_selector <= {{990{VhelperOnes}} , {34{VhelperZeros}}};
	input1_col_selector <= {{990{VhelperZeros}} , {VhelperOnes} , {33{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd992) begin
	start_col_selector <= {{991{VhelperOnes}} , {33{VhelperZeros}}};
	input1_col_selector <= {{991{VhelperZeros}} , {VhelperOnes} , {32{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd993) begin
	start_col_selector <= {{992{VhelperOnes}} , {32{VhelperZeros}}};
	input1_col_selector <= {{992{VhelperZeros}} , {VhelperOnes} , {31{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd994) begin
	start_col_selector <= {{993{VhelperOnes}} , {31{VhelperZeros}}};
	input1_col_selector <= {{993{VhelperZeros}} , {VhelperOnes} , {30{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd995) begin
	start_col_selector <= {{994{VhelperOnes}} , {30{VhelperZeros}}};	
	input1_col_selector <= {{994{VhelperZeros}} , {VhelperOnes} , {29{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd996) begin
	start_col_selector <= {{995{VhelperOnes}} , {29{VhelperZeros}}};
	input1_col_selector <= {{995{VhelperZeros}} , {VhelperOnes} , {28{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd997) begin
	start_col_selector <= {{996{VhelperOnes}} , {28{VhelperZeros}}};
	input1_col_selector <= {{996{VhelperZeros}} , {VhelperOnes} , {27{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd998) begin
	start_col_selector <= {{997{VhelperOnes}} , {27{VhelperZeros}}};
	input1_col_selector <= {{997{VhelperZeros}} , {VhelperOnes} , {26{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd999) begin
	start_col_selector <= {{998{VhelperOnes}} , {26{VhelperZeros}}};
	input1_col_selector <= {{998{VhelperZeros}} , {VhelperOnes} , {25{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1000) begin
	start_col_selector <= {{999{VhelperOnes}} , {25{VhelperZeros}}};
	input1_col_selector <= {{999{VhelperZeros}} , {VhelperOnes} , {24{VhelperZeros}}};	
end



else if (inst[start_of_input1:end_of_input1] == 10'd1001) begin
	start_col_selector <= {{1000{VhelperOnes}} , {24{VhelperZeros}}};
	input1_col_selector <= {{1000{VhelperZeros}} , {VhelperOnes} , {23{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1002) begin
	start_col_selector <= {{1001{VhelperOnes}} , {23{VhelperZeros}}};
	input1_col_selector <= {{1001{VhelperZeros}} , {VhelperOnes} , {22{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1003) begin
	start_col_selector <= {{1002{VhelperOnes}} , {22{VhelperZeros}}};
	input1_col_selector <= {{1002{VhelperZeros}} , {VhelperOnes} , {21{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1004) begin
	start_col_selector <= {{1003{VhelperOnes}} , {21{VhelperZeros}}};
	input1_col_selector <= {{1003{VhelperZeros}} , {VhelperOnes} , {20{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1005) begin
	start_col_selector <= {{1004{VhelperOnes}} , {20{VhelperZeros}}};	
	input1_col_selector <= {{1004{VhelperZeros}} , {VhelperOnes} , {19{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd1006) begin
	start_col_selector <= {{1005{VhelperOnes}} , {19{VhelperZeros}}};
	input1_col_selector <= {{1005{VhelperZeros}} , {VhelperOnes} , {18{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1007) begin
	start_col_selector <= {{1006{VhelperOnes}} , {18{VhelperZeros}}};
	input1_col_selector <= {{1006{VhelperZeros}} , {VhelperOnes} , {17{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1008) begin
	start_col_selector <= {{1007{VhelperOnes}} , {17{VhelperZeros}}};
	input1_col_selector <= {{1007{VhelperZeros}} , {VhelperOnes} , {16{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1009) begin
	start_col_selector <= {{1008{VhelperOnes}} , {16{VhelperZeros}}};
	input1_col_selector <= {{1008{VhelperZeros}} , {VhelperOnes} , {15{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1010) begin
	start_col_selector <= {{1009{VhelperOnes}} , {15{VhelperZeros}}};
	input1_col_selector <= {{1009{VhelperZeros}} , {VhelperOnes} , {14{VhelperZeros}}};	
end


else if (inst[start_of_input1:end_of_input1] == 10'd1011) begin
	start_col_selector <= {{1010{VhelperOnes}} , {14{VhelperZeros}}};
	input1_col_selector <= {{1010{VhelperZeros}} , {VhelperOnes} , {13{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1012) begin
	start_col_selector <= {{1011{VhelperOnes}} , {13{VhelperZeros}}};
	input1_col_selector <= {{1011{VhelperZeros}} , {VhelperOnes} , {12{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1013) begin
	start_col_selector <= {{1012{VhelperOnes}} , {12{VhelperZeros}}};
	input1_col_selector <= {{1012{VhelperZeros}} , {VhelperOnes} , {11{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1014) begin
	start_col_selector <= {{1013{VhelperOnes}} , {11{VhelperZeros}}};
	input1_col_selector <= {{1013{VhelperZeros}} , {VhelperOnes} , {10{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1015) begin
	start_col_selector <= {{1014{VhelperOnes}} , {10{VhelperZeros}}};	
	input1_col_selector <= {{1014{VhelperZeros}} , {VhelperOnes} , {9{VhelperZeros}}};
end
else if (inst[start_of_input1:end_of_input1] == 10'd1016) begin
	start_col_selector <= {{1015{VhelperOnes}} , {9{VhelperZeros}}};
	input1_col_selector <= {{1015{VhelperZeros}} , {VhelperOnes} , {8{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1017) begin
	start_col_selector <= {{1016{VhelperOnes}} , {8{VhelperZeros}}};
	input1_col_selector <= {{1016{VhelperZeros}} , {VhelperOnes} , {7{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1018) begin
	start_col_selector <= {{1017{VhelperOnes}} , {7{VhelperZeros}}};
	input1_col_selector <= {{1017{VhelperZeros}} , {VhelperOnes} , {6{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1019) begin
	start_col_selector <= {{1018{VhelperOnes}} , {6{VhelperZeros}}};
	input1_col_selector <= {{1018{VhelperZeros}} , {VhelperOnes} , {5{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1020) begin
	start_col_selector <= {{1019{VhelperOnes}} , {5{VhelperZeros}}};
	input1_col_selector <= {{1019{VhelperZeros}} , {VhelperOnes} , {4{VhelperZeros}}};	
end

else if (inst[start_of_input1:end_of_input1] == 10'd1021) begin
	start_col_selector <= {{1020{VhelperOnes}} , {4{VhelperZeros}}};
	input1_col_selector <= {{1020{VhelperZeros}} , {VhelperOnes} , {3{VhelperZeros}}};	
end
else if (inst[start_of_input1:end_of_input1] == 10'd1022) begin
	start_col_selector <= {{1021{VhelperOnes}} , {3{VhelperZeros}}};
	input1_col_selector <= {{1021{VhelperZeros}} , {VhelperOnes} , {2{VhelperZeros}}};	
end







///////////////////////////////////////////////////////////////////// Inpu2 2 for col selector


	
			else if (inst[start_of_input2:end_of_input2] == 10'd601) begin
				input2_col_selector <= {{600{VhelperZeros}} , {VhelperOnes} , {423{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd602) begin
				input2_col_selector <= {{601{VhelperZeros}} , {VhelperOnes} , {422{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd603) begin
				input2_col_selector <= {{602{VhelperZeros}} , {VhelperOnes} , {421{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd604) begin
				input2_col_selector <= {{603{VhelperZeros}} , {VhelperOnes} , {420{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd605) begin
				input2_col_selector <= {{604{VhelperZeros}} , {VhelperOnes} , {419{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd606) begin
				input2_col_selector <= {{605{VhelperZeros}} , {VhelperOnes} , {418{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd607) begin
				input2_col_selector <= {{606{VhelperZeros}} , {VhelperOnes} , {417{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd608) begin
				input2_col_selector <= {{607{VhelperZeros}} , {VhelperOnes} , {416{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd609) begin
				input2_col_selector <= {{608{VhelperZeros}} , {VhelperOnes} , {415{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd610) begin
				input2_col_selector <= {{609{VhelperZeros}} , {VhelperOnes} , {414{VhelperZeros}}};	
			end

			else if (inst[start_of_input2:end_of_input2] == 10'd611) begin
				input2_col_selector <= {{610{VhelperZeros}} , {VhelperOnes} , {413{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd612) begin
				input2_col_selector <= {{611{VhelperZeros}} , {VhelperOnes} , {412{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd613) begin
				input2_col_selector <= {{612{VhelperZeros}} , {VhelperOnes} , {411{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd614) begin
				input2_col_selector <= {{613{VhelperZeros}} , {VhelperOnes} , {410{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd615) begin
				input2_col_selector <= {{614{VhelperZeros}} , {VhelperOnes} , {409{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd616) begin
				input2_col_selector <= {{615{VhelperZeros}} , {VhelperOnes} , {408{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd617) begin
				input2_col_selector <= {{616{VhelperZeros}} , {VhelperOnes} , {407{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd618) begin
				input2_col_selector <= {{617{VhelperZeros}} , {VhelperOnes} , {406{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd619) begin
				input2_col_selector <= {{618{VhelperZeros}} , {VhelperOnes} , {405{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd620) begin
				input2_col_selector <= {{619{VhelperZeros}} , {VhelperOnes} , {404{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd621) begin
				input2_col_selector <= {{620{VhelperZeros}} , {VhelperOnes} , {403{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd622) begin
				input2_col_selector <= {{621{VhelperZeros}} , {VhelperOnes} , {402{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd623) begin
				input2_col_selector <= {{622{VhelperZeros}} , {VhelperOnes} , {401{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd624) begin
				input2_col_selector <= {{623{VhelperZeros}} , {VhelperOnes} , {400{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd625) begin
				input2_col_selector <= {{624{VhelperZeros}} , {VhelperOnes} , {399{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd626) begin
				input2_col_selector <= {{625{VhelperZeros}} , {VhelperOnes} , {398{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd627) begin
				input2_col_selector <= {{626{VhelperZeros}} , {VhelperOnes} , {397{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd628) begin
				input2_col_selector <= {{627{VhelperZeros}} , {VhelperOnes} , {396{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd629) begin
				input2_col_selector <= {{628{VhelperZeros}} , {VhelperOnes} , {395{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd630) begin
				input2_col_selector <= {{629{VhelperZeros}} , {VhelperOnes} , {394{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd631) begin
				input2_col_selector <= {{630{VhelperZeros}} , {VhelperOnes} , {393{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd632) begin
				input2_col_selector <= {{631{VhelperZeros}} , {VhelperOnes} , {392{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd633) begin
				input2_col_selector <= {{632{VhelperZeros}} , {VhelperOnes} , {391{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd634) begin
				input2_col_selector <= {{633{VhelperZeros}} , {VhelperOnes} , {390{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd635) begin
				input2_col_selector <= {{634{VhelperZeros}} , {VhelperOnes} , {389{VhelperZeros}}};
			end
			else if (inst[start_of_input1:end_of_input2] == 20'd636) begin
				input2_col_selector <= {{635{VhelperZeros}} , {VhelperOnes} , {388{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd637) begin
				input2_col_selector <= {{636{VhelperZeros}} , {VhelperOnes} , {387{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd638) begin
				input2_col_selector <= {{637{VhelperZeros}} , {VhelperOnes} , {386{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd639) begin
				input2_col_selector <= {{638{VhelperZeros}} , {VhelperOnes} , {385{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd640) begin
				input2_col_selector <= {{639{VhelperZeros}} , {VhelperOnes} , {384{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd641) begin
				input2_col_selector <= {{640{VhelperZeros}} , {VhelperOnes} , {383{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd642) begin
				input2_col_selector <= {{641{VhelperZeros}} , {VhelperOnes} , {382{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd643) begin
				input2_col_selector <= {{642{VhelperZeros}} , {VhelperOnes} , {381{VhelperZeros}}};	
			end
			else if (inst[start_of_input1:end_of_input2] == 20'd644) begin
				input2_col_selector <= {{643{VhelperZeros}} , {VhelperOnes} , {380{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd645) begin
				input2_col_selector <= {{644{VhelperZeros}} , {VhelperOnes} , {379{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd646) begin
				input2_col_selector <= {{645{VhelperZeros}} , {VhelperOnes} , {378{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd647) begin
				input2_col_selector <= {{646{VhelperZeros}} , {VhelperOnes} , {377{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd648) begin
				input2_col_selector <= {{647{VhelperZeros}} , {VhelperOnes} , {376{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd649) begin
				input2_col_selector <= {{648{VhelperZeros}} , {VhelperOnes} , {375{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd650) begin
				input2_col_selector <= {{649{VhelperZeros}} , {VhelperOnes} , {374{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd651) begin
				input2_col_selector <= {{650{VhelperZeros}} , {VhelperOnes} , {373{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd652) begin
				input2_col_selector <= {{651{VhelperZeros}} , {VhelperOnes} , {372{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd653) begin
				input2_col_selector <= {{652{VhelperZeros}} , {VhelperOnes} , {371{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd654) begin
				input2_col_selector <= {{653{VhelperZeros}} , {VhelperOnes} , {370{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd655) begin
				input2_col_selector <= {{654{VhelperZeros}} , {VhelperOnes} , {369{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd656) begin
				input2_col_selector <= {{655{VhelperZeros}} , {VhelperOnes} , {368{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd657) begin
				input2_col_selector <= {{656{VhelperZeros}} , {VhelperOnes} , {367{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd658) begin
				input2_col_selector <= {{657{VhelperZeros}} , {VhelperOnes} , {366{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd659) begin
				input2_col_selector <= {{658{VhelperZeros}} , {VhelperOnes} , {365{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd660) begin
				input2_col_selector <= {{659{VhelperZeros}} , {VhelperOnes} , {364{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd661) begin
				input2_col_selector <= {{660{VhelperZeros}} , {VhelperOnes} , {363{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd662) begin
				input2_col_selector <= {{661{VhelperZeros}} , {VhelperOnes} , {362{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd663) begin
				input2_col_selector <= {{662{VhelperZeros}} , {VhelperOnes} , {361{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd664) begin
				input2_col_selector <= {{663{VhelperZeros}} , {VhelperOnes} , {360{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd665) begin
				input2_col_selector <= {{664{VhelperZeros}} , {VhelperOnes} , {359{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd666) begin
				input2_col_selector <= {{665{VhelperZeros}} , {VhelperOnes} , {358{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd667) begin
				input2_col_selector <= {{666{VhelperZeros}} , {VhelperOnes} , {357{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd668) begin
				input2_col_selector <= {{667{VhelperZeros}} , {VhelperOnes} , {356{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd669) begin
				input2_col_selector <= {{668{VhelperZeros}} , {VhelperOnes} , {355{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd670) begin
				input2_col_selector <= {{669{VhelperZeros}} , {VhelperOnes} , {354{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd671) begin
				input2_col_selector <= {{670{VhelperZeros}} , {VhelperOnes} , {353{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd672) begin
				input2_col_selector <= {{671{VhelperZeros}} , {VhelperOnes} , {352{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd673) begin
				input2_col_selector <= {{672{VhelperZeros}} , {VhelperOnes} , {351{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd674) begin
				input2_col_selector <= {{673{VhelperZeros}} , {VhelperOnes} , {350{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd675) begin
				input2_col_selector <= {{674{VhelperZeros}} , {VhelperOnes} , {349{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd676) begin
				input2_col_selector <= {{675{VhelperZeros}} , {VhelperOnes} , {348{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd677) begin
				input2_col_selector <= {{676{VhelperZeros}} , {VhelperOnes} , {347{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd678) begin
				input2_col_selector <= {{677{VhelperZeros}} , {VhelperOnes} , {346{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd679) begin
				input2_col_selector <= {{678{VhelperZeros}} , {VhelperOnes} , {345{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd680) begin
				input2_col_selector <= {{679{VhelperZeros}} , {VhelperOnes} , {344{VhelperZeros}}};	
			end




			else if (inst[start_of_input2:end_of_input2] == 10'd681) begin
				input2_col_selector <= {{680{VhelperZeros}} , {VhelperOnes} , {343{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd682) begin
				input2_col_selector <= {{681{VhelperZeros}} , {VhelperOnes} , {342{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd683) begin
				input2_col_selector <= {{682{VhelperZeros}} , {VhelperOnes} , {341{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd684) begin
				input2_col_selector <= {{683{VhelperZeros}} , {VhelperOnes} , {340{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd685) begin
				input2_col_selector <= {{684{VhelperZeros}} , {VhelperOnes} , {339{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd686) begin
				input2_col_selector <= {{685{VhelperZeros}} , {VhelperOnes} , {338{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd687) begin
				input2_col_selector <= {{686{VhelperZeros}} , {VhelperOnes} , {337{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd688) begin
				input2_col_selector <= {{687{VhelperZeros}} , {VhelperOnes} , {336{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd689) begin
				input2_col_selector <= {{688{VhelperZeros}} , {VhelperOnes} , {335{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd690) begin
				input2_col_selector <= {{689{VhelperZeros}} , {VhelperOnes} , {334{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd691) begin
				input2_col_selector <= {{690{VhelperZeros}} , {VhelperOnes} , {333{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd692) begin
				input2_col_selector <= {{691{VhelperZeros}} , {VhelperOnes} , {332{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd693) begin
				input2_col_selector <= {{692{VhelperZeros}} , {VhelperOnes} , {331{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd694) begin
				input2_col_selector <= {{693{VhelperZeros}} , {VhelperOnes} , {330{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd695) begin
				input2_col_selector <= {{694{VhelperZeros}} , {VhelperOnes} , {329{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd696) begin
				input2_col_selector <= {{695{VhelperZeros}} , {VhelperOnes} , {328{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd697) begin
				input2_col_selector <= {{696{VhelperZeros}} , {VhelperOnes} , {327{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd698) begin
				input2_col_selector <= {{697{VhelperZeros}} , {VhelperOnes} , {326{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd699) begin
				input2_col_selector <= {{698{VhelperZeros}} , {VhelperOnes} , {325{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd700) begin
				input2_col_selector <= {{699{VhelperZeros}} , {VhelperOnes} , {324{VhelperZeros}}};	
			end

			else if (inst[start_of_input2:end_of_input2] == 10'd701) begin
				input2_col_selector <= {{700{VhelperZeros}} , {VhelperOnes} , {323{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd702) begin
				input2_col_selector <= {{701{VhelperZeros}} , {VhelperOnes} , {322{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd703) begin
				input2_col_selector <= {{702{VhelperZeros}} , {VhelperOnes} , {321{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd704) begin
				input2_col_selector <= {{703{VhelperZeros}} , {VhelperOnes} , {320{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd705) begin
				input2_col_selector <= {{704{VhelperZeros}} , {VhelperOnes} , {319{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd706) begin
				input2_col_selector <= {{705{VhelperZeros}} , {VhelperOnes} , {318{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd707) begin
				input2_col_selector <= {{706{VhelperZeros}} , {VhelperOnes} , {317{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd708) begin
				input2_col_selector <= {{707{VhelperZeros}} , {VhelperOnes} , {316{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd709) begin
				input2_col_selector <= {{708{VhelperZeros}} , {VhelperOnes} , {315{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd710) begin
				input2_col_selector <= {{709{VhelperZeros}} , {VhelperOnes} , {314{VhelperZeros}}};	
			end





			else if (inst[start_of_input2:end_of_input2] == 10'd711) begin
				input2_col_selector <= {{710{VhelperZeros}} , {VhelperOnes} , {313{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd712) begin
				input2_col_selector <= {{711{VhelperZeros}} , {VhelperOnes} , {312{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd713) begin
				input2_col_selector <= {{712{VhelperZeros}} , {VhelperOnes} , {311{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd714) begin
				input2_col_selector <= {{713{VhelperZeros}} , {VhelperOnes} , {310{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd715) begin
				input2_col_selector <= {{714{VhelperZeros}} , {VhelperOnes} , {309{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd716) begin
				input2_col_selector <= {{715{VhelperZeros}} , {VhelperOnes} , {308{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd717) begin
				input2_col_selector <= {{716{VhelperZeros}} , {VhelperOnes} , {307{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd718) begin
				input2_col_selector <= {{717{VhelperZeros}} , {VhelperOnes} , {306{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd719) begin
				input2_col_selector <= {{718{VhelperZeros}} , {VhelperOnes} , {305{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd720) begin
				input2_col_selector <= {{719{VhelperZeros}} , {VhelperOnes} , {304{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd721) begin
				input2_col_selector <= {{720{VhelperZeros}} , {VhelperOnes} , {303{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd722) begin
				input2_col_selector <= {{721{VhelperZeros}} , {VhelperOnes} , {302{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd723) begin
				input2_col_selector <= {{722{VhelperZeros}} , {VhelperOnes} , {301{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd724) begin
				input2_col_selector <= {{723{VhelperZeros}} , {VhelperOnes} , {300{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd725) begin
				input2_col_selector <= {{724{VhelperZeros}} , {VhelperOnes} , {299{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd726) begin
				input2_col_selector <= {{725{VhelperZeros}} , {VhelperOnes} , {298{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd727) begin
				input2_col_selector <= {{726{VhelperZeros}} , {VhelperOnes} , {297{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd728) begin
				input2_col_selector <= {{727{VhelperZeros}} , {VhelperOnes} , {296{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd729) begin
				input2_col_selector <= {{728{VhelperZeros}} , {VhelperOnes} , {295{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd730) begin
				input2_col_selector <= {{729{VhelperZeros}} , {VhelperOnes} , {294{VhelperZeros}}};	
			end




			else if (inst[start_of_input2:end_of_input2] == 10'd731) begin
				input2_col_selector <= {{730{VhelperZeros}} , {VhelperOnes} , {293{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd732) begin
				input2_col_selector <= {{731{VhelperZeros}} , {VhelperOnes} , {292{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd733) begin
				input2_col_selector <= {{732{VhelperZeros}} , {VhelperOnes} , {291{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd734) begin
				input2_col_selector <= {{733{VhelperZeros}} , {VhelperOnes} , {290{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd735) begin
				input2_col_selector <= {{734{VhelperZeros}} , {VhelperOnes} , {289{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd736) begin
				input2_col_selector <= {{735{VhelperZeros}} , {VhelperOnes} , {288{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd737) begin
				input2_col_selector <= {{736{VhelperZeros}} , {VhelperOnes} , {287{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd738) begin
				input2_col_selector <= {{737{VhelperZeros}} , {VhelperOnes} , {286{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd739) begin
				input2_col_selector <= {{738{VhelperZeros}} , {VhelperOnes} , {285{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd740) begin
				input2_col_selector <= {{739{VhelperZeros}} , {VhelperOnes} , {284{VhelperZeros}}};	
			end




			else if (inst[start_of_input2:end_of_input2] == 10'd741) begin
				input2_col_selector <= {{740{VhelperZeros}} , {VhelperOnes} , {283{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd742) begin
				input2_col_selector <= {{741{VhelperZeros}} , {VhelperOnes} , {282{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd743) begin
				input2_col_selector <= {{742{VhelperZeros}} , {VhelperOnes} , {281{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd744) begin
				input2_col_selector <= {{743{VhelperZeros}} , {VhelperOnes} , {280{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd745) begin
				input2_col_selector <= {{744{VhelperZeros}} , {VhelperOnes} , {279{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd746) begin
				input2_col_selector <= {{745{VhelperZeros}} , {VhelperOnes} , {278{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd747) begin
				input2_col_selector <= {{746{VhelperZeros}} , {VhelperOnes} , {277{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd748) begin
				input2_col_selector <= {{747{VhelperZeros}} , {VhelperOnes} , {276{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd749) begin
				input2_col_selector <= {{748{VhelperZeros}} , {VhelperOnes} , {275{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd750) begin
				input2_col_selector <= {{749{VhelperZeros}} , {VhelperOnes} , {274{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd751) begin
				input2_col_selector <= {{750{VhelperZeros}} , {VhelperOnes} , {273{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd752) begin
				input2_col_selector <= {{751{VhelperZeros}} , {VhelperOnes} , {272{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd753) begin
				input2_col_selector <= {{752{VhelperZeros}} , {VhelperOnes} , {271{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd754) begin
				input2_col_selector <= {{753{VhelperZeros}} , {VhelperOnes} , {270{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd755) begin
				input2_col_selector <= {{754{VhelperZeros}} , {VhelperOnes} , {269{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd756) begin
				input2_col_selector <= {{755{VhelperZeros}} , {VhelperOnes} , {268{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd757) begin
				input2_col_selector <= {{756{VhelperZeros}} , {VhelperOnes} , {267{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd758) begin
				input2_col_selector <= {{757{VhelperZeros}} , {VhelperOnes} , {266{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd759) begin
				input2_col_selector <= {{758{VhelperZeros}} , {VhelperOnes} , {265{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd760) begin
				input2_col_selector <= {{759{VhelperZeros}} , {VhelperOnes} , {264{VhelperZeros}}};	
			end





			else if (inst[start_of_input2:end_of_input2] == 10'd761) begin
				input2_col_selector <= {{760{VhelperZeros}} , {VhelperOnes} , {263{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd762) begin
				input2_col_selector <= {{761{VhelperZeros}} , {VhelperOnes} , {262{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd763) begin
				input2_col_selector <= {{762{VhelperZeros}} , {VhelperOnes} , {261{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd764) begin
				input2_col_selector <= {{763{VhelperZeros}} , {VhelperOnes} , {260{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd765) begin
				input2_col_selector <= {{764{VhelperZeros}} , {VhelperOnes} , {259{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd766) begin
				input2_col_selector <= {{765{VhelperZeros}} , {VhelperOnes} , {258{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd767) begin
				input2_col_selector <= {{766{VhelperZeros}} , {VhelperOnes} , {257{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd768) begin
				input2_col_selector <= {{767{VhelperZeros}} , {VhelperOnes} , {256{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd769) begin
				input2_col_selector <= {{768{VhelperZeros}} , {VhelperOnes} , {255{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd770) begin
				input2_col_selector <= {{769{VhelperZeros}} , {VhelperOnes} , {254{VhelperZeros}}};	
			end




			else if (inst[start_of_input2:end_of_input2] == 10'd771) begin
				input2_col_selector <= {{770{VhelperZeros}} , {VhelperOnes} , {253{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd772) begin
				input2_col_selector <= {{771{VhelperZeros}} , {VhelperOnes} , {252{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd773) begin
				input2_col_selector <= {{772{VhelperZeros}} , {VhelperOnes} , {251{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd774) begin
				input2_col_selector <= {{773{VhelperZeros}} , {VhelperOnes} , {250{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd775) begin
				input2_col_selector <= {{774{VhelperZeros}} , {VhelperOnes} , {249{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd776) begin
				input2_col_selector <= {{775{VhelperZeros}} , {VhelperOnes} , {248{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd777) begin
				input2_col_selector <= {{776{VhelperZeros}} , {VhelperOnes} , {247{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd778) begin
				input2_col_selector <= {{777{VhelperZeros}} , {VhelperOnes} , {246{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd779) begin
				input2_col_selector <= {{778{VhelperZeros}} , {VhelperOnes} , {245{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd780) begin
				input2_col_selector <= {{779{VhelperZeros}} , {VhelperOnes} , {244{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd781) begin
				input2_col_selector <= {{780{VhelperZeros}} , {VhelperOnes} , {243{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd782) begin
				input2_col_selector <= {{781{VhelperZeros}} , {VhelperOnes} , {242{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd783) begin
				input2_col_selector <= {{782{VhelperZeros}} , {VhelperOnes} , {241{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd784) begin
				input2_col_selector <= {{783{VhelperZeros}} , {VhelperOnes} , {240{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd785) begin
				input2_col_selector <= {{784{VhelperZeros}} , {VhelperOnes} , {239{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd786) begin
				input2_col_selector <= {{785{VhelperZeros}} , {VhelperOnes} , {238{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd787) begin
				input2_col_selector <= {{786{VhelperZeros}} , {VhelperOnes} , {237{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd788) begin
				input2_col_selector <= {{787{VhelperZeros}} , {VhelperOnes} , {236{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd789) begin
				input2_col_selector <= {{788{VhelperZeros}} , {VhelperOnes} , {235{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd790) begin
				input2_col_selector <= {{789{VhelperZeros}} , {VhelperOnes} , {234{VhelperZeros}}};	
			end




			else if (inst[start_of_input2:end_of_input2] == 10'd791) begin
				input2_col_selector <= {{790{VhelperZeros}} , {VhelperOnes} , {233{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd792) begin
				input2_col_selector <= {{791{VhelperZeros}} , {VhelperOnes} , {232{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd793) begin
				input2_col_selector <= {{792{VhelperZeros}} , {VhelperOnes} , {231{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd794) begin
				input2_col_selector <= {{793{VhelperZeros}} , {VhelperOnes} , {230{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd795) begin
				input2_col_selector <= {{794{VhelperZeros}} , {VhelperOnes} , {229{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd796) begin
				input2_col_selector <= {{795{VhelperZeros}} , {VhelperOnes} , {228{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd797) begin
				input2_col_selector <= {{796{VhelperZeros}} , {VhelperOnes} , {227{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd798) begin
				input2_col_selector <= {{797{VhelperZeros}} , {VhelperOnes} , {226{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd799) begin
				input2_col_selector <= {{798{VhelperZeros}} , {VhelperOnes} , {225{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd800) begin
				input2_col_selector <= {{799{VhelperZeros}} , {VhelperOnes} , {224{VhelperZeros}}};	
			end




			else if (inst[start_of_input2:end_of_input2] == 10'd801) begin
				input2_col_selector <= {{800{VhelperZeros}} , {VhelperOnes} , {223{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd802) begin
				input2_col_selector <= {{801{VhelperZeros}} , {VhelperOnes} , {222{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd803) begin
				input2_col_selector <= {{802{VhelperZeros}} , {VhelperOnes} , {221{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd804) begin
				input2_col_selector <= {{803{VhelperZeros}} , {VhelperOnes} , {220{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd805) begin
				input2_col_selector <= {{804{VhelperZeros}} , {VhelperOnes} , {219{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd806) begin
				input2_col_selector <= {{805{VhelperZeros}} , {VhelperOnes} , {218{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd807) begin
				input2_col_selector <= {{806{VhelperZeros}} , {VhelperOnes} , {217{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd808) begin
				input2_col_selector <= {{807{VhelperZeros}} , {VhelperOnes} , {216{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd809) begin
				input2_col_selector <= {{808{VhelperZeros}} , {VhelperOnes} , {215{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd810) begin
				input2_col_selector <= {{809{VhelperZeros}} , {VhelperOnes} , {214{VhelperZeros}}};	
			end





			else if (inst[start_of_input2:end_of_input2] == 10'd811) begin
				input2_col_selector <= {{810{VhelperZeros}} , {VhelperOnes} , {213{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd812) begin
				input2_col_selector <= {{811{VhelperZeros}} , {VhelperOnes} , {212{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd813) begin
				input2_col_selector <= {{812{VhelperZeros}} , {VhelperOnes} , {211{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd814) begin
				input2_col_selector <= {{813{VhelperZeros}} , {VhelperOnes} , {210{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd815) begin
				input2_col_selector <= {{814{VhelperZeros}} , {VhelperOnes} , {209{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd816) begin
				input2_col_selector <= {{815{VhelperZeros}} , {VhelperOnes} , {208{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd817) begin
				input2_col_selector <= {{816{VhelperZeros}} , {VhelperOnes} , {207{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd818) begin
				input2_col_selector <= {{817{VhelperZeros}} , {VhelperOnes} , {206{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd819) begin
				input2_col_selector <= {{818{VhelperZeros}} , {VhelperOnes} , {205{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd820) begin
				input2_col_selector <= {{819{VhelperZeros}} , {VhelperOnes} , {204{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd821) begin
				input2_col_selector <= {{820{VhelperZeros}} , {VhelperOnes} , {203{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd822) begin
				input2_col_selector <= {{821{VhelperZeros}} , {VhelperOnes} , {202{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd823) begin
				input2_col_selector <= {{822{VhelperZeros}} , {VhelperOnes} , {201{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd824) begin
				input2_col_selector <= {{823{VhelperZeros}} , {VhelperOnes} , {200{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd825) begin
				input2_col_selector <= {{824{VhelperZeros}} , {VhelperOnes} , {199{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd826) begin
				input2_col_selector <= {{825{VhelperZeros}} , {VhelperOnes} , {198{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd827) begin
				input2_col_selector <= {{826{VhelperZeros}} , {VhelperOnes} , {197{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd828) begin
				input2_col_selector <= {{827{VhelperZeros}} , {VhelperOnes} , {196{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd829) begin
				input2_col_selector <= {{828{VhelperZeros}} , {VhelperOnes} , {195{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd830) begin
				input2_col_selector <= {{829{VhelperZeros}} , {VhelperOnes} , {194{VhelperZeros}}};	
			end

			else if (inst[start_of_input2:end_of_input2] == 10'd831) begin
				input2_col_selector <= {{830{VhelperZeros}} , {VhelperOnes} , {193{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd832) begin
				input2_col_selector <= {{831{VhelperZeros}} , {VhelperOnes} , {192{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd833) begin
				input2_col_selector <= {{832{VhelperZeros}} , {VhelperOnes} , {191{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd834) begin
				input2_col_selector <= {{833{VhelperZeros}} , {VhelperOnes} , {190{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd835) begin
				input2_col_selector <= {{834{VhelperZeros}} , {VhelperOnes} , {189{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd836) begin
				input2_col_selector <= {{835{VhelperZeros}} , {VhelperOnes} , {188{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd837) begin
				input2_col_selector <= {{836{VhelperZeros}} , {VhelperOnes} , {187{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd838) begin
				input2_col_selector <= {{837{VhelperZeros}} , {VhelperOnes} , {186{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd839) begin
				input2_col_selector <= {{838{VhelperZeros}} , {VhelperOnes} , {185{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd840) begin
				input2_col_selector <= {{839{VhelperZeros}} , {VhelperOnes} , {184{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd841) begin
				input2_col_selector <= {{840{VhelperZeros}} , {VhelperOnes} , {183{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd842) begin
				input2_col_selector <= {{841{VhelperZeros}} , {VhelperOnes} , {182{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd843) begin
				input2_col_selector <= {{842{VhelperZeros}} , {VhelperOnes} , {181{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd844) begin
				input2_col_selector <= {{843{VhelperZeros}} , {VhelperOnes} , {180{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd845) begin
				input2_col_selector <= {{844{VhelperZeros}} , {VhelperOnes} , {179{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd846) begin
				input2_col_selector <= {{845{VhelperZeros}} , {VhelperOnes} , {178{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd847) begin
				input2_col_selector <= {{846{VhelperZeros}} , {VhelperOnes} , {177{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd848) begin
				input2_col_selector <= {{847{VhelperZeros}} , {VhelperOnes} , {176{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd849) begin
				input2_col_selector <= {{848{VhelperZeros}} , {VhelperOnes} , {175{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd850) begin
				input2_col_selector <= {{849{VhelperZeros}} , {VhelperOnes} , {174{VhelperZeros}}};	
			end

			else if (inst[start_of_input2:end_of_input2] == 10'd851) begin
				input2_col_selector <= {{850{VhelperZeros}} , {VhelperOnes} , {173{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd852) begin
				input2_col_selector <= {{851{VhelperZeros}} , {VhelperOnes} , {172{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd853) begin
				input2_col_selector <= {{852{VhelperZeros}} , {VhelperOnes} , {171{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd854) begin
				input2_col_selector <= {{853{VhelperZeros}} , {VhelperOnes} , {170{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd855) begin
				input2_col_selector <= {{854{VhelperZeros}} , {VhelperOnes} , {169{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd856) begin
				input2_col_selector <= {{855{VhelperZeros}} , {VhelperOnes} , {168{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd857) begin
				input2_col_selector <= {{856{VhelperZeros}} , {VhelperOnes} , {167{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd858) begin
				input2_col_selector <= {{857{VhelperZeros}} , {VhelperOnes} , {166{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd859) begin
				input2_col_selector <= {{858{VhelperZeros}} , {VhelperOnes} , {165{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd860) begin
				input2_col_selector <= {{859{VhelperZeros}} , {VhelperOnes} , {164{VhelperZeros}}};	
			end




			else if (inst[start_of_input2:end_of_input2] == 10'd861) begin
				input2_col_selector <= {{860{VhelperZeros}} , {VhelperOnes} , {163{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd862) begin
				input2_col_selector <= {{861{VhelperZeros}} , {VhelperOnes} , {162{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd863) begin
				input2_col_selector <= {{862{VhelperZeros}} , {VhelperOnes} , {161{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd864) begin
				input2_col_selector <= {{863{VhelperZeros}} , {VhelperOnes} , {160{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd865) begin
				input2_col_selector <= {{864{VhelperZeros}} , {VhelperOnes} , {159{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd866) begin
				input2_col_selector <= {{865{VhelperZeros}} , {VhelperOnes} , {158{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd867) begin
				input2_col_selector <= {{866{VhelperZeros}} , {VhelperOnes} , {157{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd868) begin
				input2_col_selector <= {{867{VhelperZeros}} , {VhelperOnes} , {156{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd869) begin
				input2_col_selector <= {{868{VhelperZeros}} , {VhelperOnes} , {155{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd870) begin
				input2_col_selector <= {{869{VhelperZeros}} , {VhelperOnes} , {154{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd871) begin
				input2_col_selector <= {{870{VhelperZeros}} , {VhelperOnes} , {153{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd872) begin
				input2_col_selector <= {{871{VhelperZeros}} , {VhelperOnes} , {152{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd873) begin
				input2_col_selector <= {{872{VhelperZeros}} , {VhelperOnes} , {151{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd874) begin
				input2_col_selector <= {{873{VhelperZeros}} , {VhelperOnes} , {150{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd875) begin
				input2_col_selector <= {{874{VhelperZeros}} , {VhelperOnes} , {149{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd876) begin
				input2_col_selector <= {{875{VhelperZeros}} , {VhelperOnes} , {148{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd877) begin
				input2_col_selector <= {{876{VhelperZeros}} , {VhelperOnes} , {147{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd878) begin
				input2_col_selector <= {{877{VhelperZeros}} , {VhelperOnes} , {146{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd879) begin
				input2_col_selector <= {{878{VhelperZeros}} , {VhelperOnes} , {145{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd880) begin
				input2_col_selector <= {{879{VhelperZeros}} , {VhelperOnes} , {144{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd881) begin
				input2_col_selector <= {{880{VhelperZeros}} , {VhelperOnes} , {143{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd882) begin
				input2_col_selector <= {{881{VhelperZeros}} , {VhelperOnes} , {142{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd883) begin
				input2_col_selector <= {{882{VhelperZeros}} , {VhelperOnes} , {141{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd884) begin
				input2_col_selector <= {{883{VhelperZeros}} , {VhelperOnes} , {140{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd885) begin
				input2_col_selector <= {{884{VhelperZeros}} , {VhelperOnes} , {139{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd886) begin
				input2_col_selector <= {{885{VhelperZeros}} , {VhelperOnes} , {138{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd887) begin
				input2_col_selector <= {{886{VhelperZeros}} , {VhelperOnes} , {137{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd888) begin
				input2_col_selector <= {{887{VhelperZeros}} , {VhelperOnes} , {136{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd889) begin
				input2_col_selector <= {{888{VhelperZeros}} , {VhelperOnes} , {135{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd890) begin
				input2_col_selector <= {{889{VhelperZeros}} , {VhelperOnes} , {134{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd891) begin
				input2_col_selector <= {{890{VhelperZeros}} , {VhelperOnes} , {133{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd892) begin
				input2_col_selector <= {{891{VhelperZeros}} , {VhelperOnes} , {132{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd893) begin
				input2_col_selector <= {{892{VhelperZeros}} , {VhelperOnes} , {131{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd894) begin
				input2_col_selector <= {{893{VhelperZeros}} , {VhelperOnes} , {130{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd895) begin
				input2_col_selector <= {{894{VhelperZeros}} , {VhelperOnes} , {129{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd896) begin
				input2_col_selector <= {{895{VhelperZeros}} , {VhelperOnes} , {128{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd897) begin
				input2_col_selector <= {{896{VhelperZeros}} , {VhelperOnes} , {127{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd898) begin
				input2_col_selector <= {{897{VhelperZeros}} , {VhelperOnes} , {126{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd899) begin
				input2_col_selector <= {{898{VhelperZeros}} , {VhelperOnes} , {125{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd900) begin
				input2_col_selector <= {{899{VhelperZeros}} , {VhelperOnes} , {124{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd901) begin
				input2_col_selector <= {{900{VhelperZeros}} , {VhelperOnes} , {123{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd902) begin
				input2_col_selector <= {{901{VhelperZeros}} , {VhelperOnes} , {122{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd903) begin
				input2_col_selector <= {{902{VhelperZeros}} , {VhelperOnes} , {121{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd904) begin
				input2_col_selector <= {{903{VhelperZeros}} , {VhelperOnes} , {120{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd905) begin
				input2_col_selector <= {{904{VhelperZeros}} , {VhelperOnes} , {119{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd906) begin
				input2_col_selector <= {{905{VhelperZeros}} , {VhelperOnes} , {118{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd907) begin
				input2_col_selector <= {{906{VhelperZeros}} , {VhelperOnes} , {117{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd908) begin
				input2_col_selector <= {{907{VhelperZeros}} , {VhelperOnes} , {116{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd909) begin
				input2_col_selector <= {{908{VhelperZeros}} , {VhelperOnes} , {115{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd910) begin
				input2_col_selector <= {{909{VhelperZeros}} , {VhelperOnes} , {114{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd911) begin
				input2_col_selector <= {{910{VhelperZeros}} , {VhelperOnes} , {113{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd912) begin
				input2_col_selector <= {{911{VhelperZeros}} , {VhelperOnes} , {112{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd913) begin
				input2_col_selector <= {{912{VhelperZeros}} , {VhelperOnes} , {111{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd914) begin
				input2_col_selector <= {{913{VhelperZeros}} , {VhelperOnes} , {110{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd915) begin
				input2_col_selector <= {{914{VhelperZeros}} , {VhelperOnes} , {109{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd916) begin
				input2_col_selector <= {{915{VhelperZeros}} , {VhelperOnes} , {108{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd917) begin
				input2_col_selector <= {{916{VhelperZeros}} , {VhelperOnes} , {107{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd918) begin
				input2_col_selector <= {{917{VhelperZeros}} , {VhelperOnes} , {106{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd919) begin
				input2_col_selector <= {{918{VhelperZeros}} , {VhelperOnes} , {105{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd920) begin
				input2_col_selector <= {{919{VhelperZeros}} , {VhelperOnes} , {104{VhelperZeros}}};	
			end

			else if (inst[start_of_input2:end_of_input2] == 10'd921) begin
				input2_col_selector <= {{920{VhelperZeros}} , {VhelperOnes} , {103{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd922) begin
				input2_col_selector <= {{921{VhelperZeros}} , {VhelperOnes} , {102{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd923) begin
				input2_col_selector <= {{922{VhelperZeros}} , {VhelperOnes} , {101{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd924) begin
				input2_col_selector <= {{923{VhelperZeros}} , {VhelperOnes} , {100{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd925) begin
				input2_col_selector <= {{924{VhelperZeros}} , {VhelperOnes} , {99{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd926) begin
				input2_col_selector <= {{925{VhelperZeros}} , {VhelperOnes} , {98{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd927) begin
				input2_col_selector <= {{926{VhelperZeros}} , {VhelperOnes} , {97{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd928) begin
				input2_col_selector <= {{927{VhelperZeros}} , {VhelperOnes} , {96{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd929) begin
				input2_col_selector <= {{928{VhelperZeros}} , {VhelperOnes} , {95{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd930) begin
				input2_col_selector <= {{929{VhelperZeros}} , {VhelperOnes} , {94{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd931) begin
				input2_col_selector <= {{930{VhelperZeros}} , {VhelperOnes} , {93{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd932) begin
				input2_col_selector <= {{931{VhelperZeros}} , {VhelperOnes} , {92{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd933) begin
				input2_col_selector <= {{932{VhelperZeros}} , {VhelperOnes} , {91{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd934) begin
				input2_col_selector <= {{933{VhelperZeros}} , {VhelperOnes} , {90{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd935) begin
				input2_col_selector <= {{934{VhelperZeros}} , {VhelperOnes} , {89{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd936) begin
				input2_col_selector <= {{935{VhelperZeros}} , {VhelperOnes} , {88{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd937) begin
				input2_col_selector <= {{936{VhelperZeros}} , {VhelperOnes} , {87{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd938) begin
				input2_col_selector <= {{937{VhelperZeros}} , {VhelperOnes} , {86{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd939) begin
				input2_col_selector <= {{938{VhelperZeros}} , {VhelperOnes} , {85{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd940) begin
				input2_col_selector <= {{939{VhelperZeros}} , {VhelperOnes} , {84{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd941) begin
				input2_col_selector <= {{940{VhelperZeros}} , {VhelperOnes} , {83{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd942) begin
				input2_col_selector <= {{941{VhelperZeros}} , {VhelperOnes} , {82{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd943) begin
				input2_col_selector <= {{942{VhelperZeros}} , {VhelperOnes} , {81{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd944) begin
				input2_col_selector <= {{943{VhelperZeros}} , {VhelperOnes} , {80{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd945) begin
				input2_col_selector <= {{944{VhelperZeros}} , {VhelperOnes} , {79{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd946) begin
				input2_col_selector <= {{945{VhelperZeros}} , {VhelperOnes} , {78{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd947) begin
				input2_col_selector <= {{946{VhelperZeros}} , {VhelperOnes} , {77{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd948) begin
				input2_col_selector <= {{947{VhelperZeros}} , {VhelperOnes} , {76{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd949) begin
				input2_col_selector <= {{948{VhelperZeros}} , {VhelperOnes} , {75{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd950) begin
				input2_col_selector <= {{949{VhelperZeros}} , {VhelperOnes} , {74{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd951) begin
				input2_col_selector <= {{950{VhelperZeros}} , {VhelperOnes} , {73{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd952) begin
				input2_col_selector <= {{951{VhelperZeros}} , {VhelperOnes} , {72{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd953) begin
				input2_col_selector <= {{952{VhelperZeros}} , {VhelperOnes} , {71{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd954) begin
				input2_col_selector <= {{953{VhelperZeros}} , {VhelperOnes} , {70{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd955) begin
				input2_col_selector <= {{954{VhelperZeros}} , {VhelperOnes} , {69{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd956) begin
				input2_col_selector <= {{955{VhelperZeros}} , {VhelperOnes} , {68{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd957) begin
				input2_col_selector <= {{956{VhelperZeros}} , {VhelperOnes} , {67{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd958) begin
				input2_col_selector <= {{957{VhelperZeros}} , {VhelperOnes} , {66{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd959) begin
				input2_col_selector <= {{958{VhelperZeros}} , {VhelperOnes} , {65{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd960) begin
				input2_col_selector <= {{959{VhelperZeros}} , {VhelperOnes} , {64{VhelperZeros}}};	
			end



			else if (inst[start_of_input2:end_of_input2] == 10'd961) begin
				input2_col_selector <= {{960{VhelperZeros}} , {VhelperOnes} , {63{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd962) begin
				input2_col_selector <= {{961{VhelperZeros}} , {VhelperOnes} , {62{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd963) begin
				input2_col_selector <= {{962{VhelperZeros}} , {VhelperOnes} , {61{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd964) begin
				input2_col_selector <= {{963{VhelperZeros}} , {VhelperOnes} , {60{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd965) begin
				input2_col_selector <= {{964{VhelperZeros}} , {VhelperOnes} , {59{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd966) begin
				input2_col_selector <= {{965{VhelperZeros}} , {VhelperOnes} , {58{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd967) begin
				input2_col_selector <= {{966{VhelperZeros}} , {VhelperOnes} , {57{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd968) begin
				input2_col_selector <= {{967{VhelperZeros}} , {VhelperOnes} , {56{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd969) begin
				input2_col_selector <= {{968{VhelperZeros}} , {VhelperOnes} , {55{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd970) begin
				input2_col_selector <= {{969{VhelperZeros}} , {VhelperOnes} , {54{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd971) begin
				input2_col_selector <= {{970{VhelperZeros}} , {VhelperOnes} , {53{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd972) begin
				input2_col_selector <= {{971{VhelperZeros}} , {VhelperOnes} , {52{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd973) begin
				input2_col_selector <= {{972{VhelperZeros}} , {VhelperOnes} , {51{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd974) begin
				input2_col_selector <= {{973{VhelperZeros}} , {VhelperOnes} , {50{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd975) begin
				input2_col_selector <= {{974{VhelperZeros}} , {VhelperOnes} , {49{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd976) begin
				input2_col_selector <= {{975{VhelperZeros}} , {VhelperOnes} , {48{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd977) begin
				input2_col_selector <= {{976{VhelperZeros}} , {VhelperOnes} , {47{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd978) begin
				input2_col_selector <= {{977{VhelperZeros}} , {VhelperOnes} , {46{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd979) begin
				input2_col_selector <= {{978{VhelperZeros}} , {VhelperOnes} , {45{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd980) begin
				input2_col_selector <= {{979{VhelperZeros}} , {VhelperOnes} , {44{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd981) begin
				input2_col_selector <= {{980{VhelperZeros}} , {VhelperOnes} , {43{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd982) begin
				input2_col_selector <= {{981{VhelperZeros}} , {VhelperOnes} , {42{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd983) begin
				input2_col_selector <= {{982{VhelperZeros}} , {VhelperOnes} , {41{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd984) begin
				input2_col_selector <= {{983{VhelperZeros}} , {VhelperOnes} , {40{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd985) begin
				input2_col_selector <= {{984{VhelperZeros}} , {VhelperOnes} , {39{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd986) begin
				input2_col_selector <= {{985{VhelperZeros}} , {VhelperOnes} , {38{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd987) begin
				input2_col_selector <= {{986{VhelperZeros}} , {VhelperOnes} , {37{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd988) begin
				input2_col_selector <= {{987{VhelperZeros}} , {VhelperOnes} , {36{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd989) begin
				input2_col_selector <= {{988{VhelperZeros}} , {VhelperOnes} , {35{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd990) begin
				input2_col_selector <= {{989{VhelperZeros}} , {VhelperOnes} , {34{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd991) begin
				input2_col_selector <= {{990{VhelperZeros}} , {VhelperOnes} , {33{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd992) begin
				input2_col_selector <= {{991{VhelperZeros}} , {VhelperOnes} , {32{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd993) begin
				input2_col_selector <= {{992{VhelperZeros}} , {VhelperOnes} , {31{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd994) begin
				input2_col_selector <= {{993{VhelperZeros}} , {VhelperOnes} , {30{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd995) begin
				input2_col_selector <= {{994{VhelperZeros}} , {VhelperOnes} , {29{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd996) begin
				input2_col_selector <= {{995{VhelperZeros}} , {VhelperOnes} , {28{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd997) begin
				input2_col_selector <= {{996{VhelperZeros}} , {VhelperOnes} , {27{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd998) begin
				input2_col_selector <= {{997{VhelperZeros}} , {VhelperOnes} , {26{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd999) begin
				input2_col_selector <= {{998{VhelperZeros}} , {VhelperOnes} , {25{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1000) begin
				input2_col_selector <= {{999{VhelperZeros}} , {VhelperOnes} , {24{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd1001) begin
				input2_col_selector <= {{1000{VhelperZeros}} , {VhelperOnes} , {23{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1002) begin
				input2_col_selector <= {{1001{VhelperZeros}} , {VhelperOnes} , {22{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1003) begin
				input2_col_selector <= {{1002{VhelperZeros}} , {VhelperOnes} , {21{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1004) begin
				input2_col_selector <= {{1003{VhelperZeros}} , {VhelperOnes} , {20{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1005) begin
				input2_col_selector <= {{1004{VhelperZeros}} , {VhelperOnes} , {19{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1006) begin
				input2_col_selector <= {{1005{VhelperZeros}} , {VhelperOnes} , {18{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1007) begin
				input2_col_selector <= {{1006{VhelperZeros}} , {VhelperOnes} , {17{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1008) begin
				input2_col_selector <= {{1007{VhelperZeros}} , {VhelperOnes} , {16{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1009) begin
				input2_col_selector <= {{1008{VhelperZeros}} , {VhelperOnes} , {15{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1010) begin
				input2_col_selector <= {{1009{VhelperZeros}} , {VhelperOnes} , {14{VhelperZeros}}};	
			end


			else if (inst[start_of_input2:end_of_input2] == 10'd1011) begin
				input2_col_selector <= {{1010{VhelperZeros}} , {VhelperOnes} , {13{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1012) begin
				input2_col_selector <= {{1011{VhelperZeros}} , {VhelperOnes} , {12{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1013) begin
				input2_col_selector <= {{1012{VhelperZeros}} , {VhelperOnes} , {11{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1014) begin
				input2_col_selector <= {{1013{VhelperZeros}} , {VhelperOnes} , {10{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1015) begin
				input2_col_selector <= {{1014{VhelperZeros}} , {VhelperOnes} , {9{VhelperZeros}}};
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1016) begin
				input2_col_selector <= {{1015{VhelperZeros}} , {VhelperOnes} , {8{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1017) begin
				input2_col_selector <= {{1016{VhelperZeros}} , {VhelperOnes} , {7{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1018) begin
				input2_col_selector <= {{1017{VhelperZeros}} , {VhelperOnes} , {6{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1019) begin
				input2_col_selector <= {{1018{VhelperZeros}} , {VhelperOnes} , {5{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1020) begin
				input2_col_selector <= {{1019{VhelperZeros}} , {VhelperOnes} , {4{VhelperZeros}}};	
			end

			else if (inst[start_of_input2:end_of_input2] == 10'd1021) begin
				input2_col_selector <= {{1020{VhelperZeros}} , {VhelperOnes} , {3{VhelperZeros}}};	
			end
			else if (inst[start_of_input2:end_of_input2] == 10'd1022) begin
				input2_col_selector <= {{1021{VhelperZeros}} , {VhelperOnes} , {2{VhelperZeros}}};	
			end








////////////////////////////////////////////////////////  End Col Selector and Output Col Selsector


			else if (inst[start_of_output:end_of_output] == 10'd901) begin
				end_col_selector <= {{901{VhelperZeros}} , {123{VhelperOnes}}};
				output_col_selector <= {{900{VhelperZeros}} , {VhelperOnes} , {123{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd902) begin
				end_col_selector <= {{902{VhelperZeros}} , {122{VhelperOnes}}};
				output_col_selector <= {{901{VhelperZeros}} , {VhelperOnes} , {122{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd903) begin
				end_col_selector <= {{903{VhelperZeros}} , {121{VhelperOnes}}};
				output_col_selector <= {{902{VhelperZeros}} , {VhelperOnes} , {121{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd904) begin
				end_col_selector <= {{904{VhelperZeros}} , {120{VhelperOnes}}};
				output_col_selector <= {{903{VhelperZeros}} , {VhelperOnes} , {120{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd905) begin
				end_col_selector <= {{905{VhelperZeros}} , {119{VhelperOnes}}};
				output_col_selector <= {{904{VhelperZeros}} , {VhelperOnes} , {119{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd906) begin
				end_col_selector <= {{906{VhelperZeros}} , {118{VhelperOnes}}};
				output_col_selector <= {{905{VhelperZeros}} , {VhelperOnes} , {118{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd907) begin
				end_col_selector <= {{907{VhelperZeros}} , {117{VhelperOnes}}};
				output_col_selector <= {{906{VhelperZeros}} , {VhelperOnes} , {117{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd908) begin
				end_col_selector <= {{908{VhelperZeros}} , {116{VhelperOnes}}};
				output_col_selector <= {{907{VhelperZeros}} , {VhelperOnes} , {116{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd909) begin
				end_col_selector <= {{909{VhelperZeros}} , {115{VhelperOnes}}};
				output_col_selector <= {{908{VhelperZeros}} , {VhelperOnes} , {115{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd910) begin
				end_col_selector <= {{910{VhelperZeros}} , {114{VhelperOnes}}};
				output_col_selector <= {{909{VhelperZeros}} , {VhelperOnes} , {114{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd911) begin
				end_col_selector <= {{911{VhelperZeros}} , {113{VhelperOnes}}};
				output_col_selector <= {{910{VhelperZeros}} , {VhelperOnes} , {113{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd912) begin
				end_col_selector <= {{912{VhelperZeros}} , {112{VhelperOnes}}};
				output_col_selector <= {{911{VhelperZeros}} , {VhelperOnes} , {112{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd913) begin
				end_col_selector <= {{913{VhelperZeros}} , {111{VhelperOnes}}};
				output_col_selector <= {{912{VhelperZeros}} , {VhelperOnes} , {111{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd914) begin
				end_col_selector <= {{914{VhelperZeros}} , {110{VhelperOnes}}};
				output_col_selector <= {{913{VhelperZeros}} , {VhelperOnes} , {110{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd915) begin
				end_col_selector <= {{915{VhelperZeros}} , {109{VhelperOnes}}};
				output_col_selector <= {{914{VhelperZeros}} , {VhelperOnes} , {109{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd916) begin
				end_col_selector <= {{916{VhelperZeros}} , {108{VhelperOnes}}};
				output_col_selector <= {{915{VhelperZeros}} , {VhelperOnes} , {108{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd917) begin
				end_col_selector <= {{917{VhelperZeros}} , {107{VhelperOnes}}};
				output_col_selector <= {{916{VhelperZeros}} , {VhelperOnes} , {107{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd918) begin
				end_col_selector <= {{918{VhelperZeros}} , {106{VhelperOnes}}};
				output_col_selector <= {{917{VhelperZeros}} , {VhelperOnes} , {106{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd919) begin
				end_col_selector <= {{919{VhelperZeros}} , {105{VhelperOnes}}};
				output_col_selector <= {{918{VhelperZeros}} , {VhelperOnes} , {105{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd920) begin
				end_col_selector <= {{920{VhelperZeros}} , {104{VhelperOnes}}};
				output_col_selector <= {{919{VhelperZeros}} , {VhelperOnes} , {104{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd921) begin
				end_col_selector <= {{921{VhelperZeros}} , {103{VhelperOnes}}};
				output_col_selector <= {{920{VhelperZeros}} , {VhelperOnes} , {103{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd922) begin
				end_col_selector <= {{922{VhelperZeros}} , {102{VhelperOnes}}};
				output_col_selector <= {{921{VhelperZeros}} , {VhelperOnes} , {102{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd923) begin
				end_col_selector <= {{923{VhelperZeros}} , {101{VhelperOnes}}};
				output_col_selector <= {{922{VhelperZeros}} , {VhelperOnes} , {101{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd924) begin
				end_col_selector <= {{924{VhelperZeros}} , {100{VhelperOnes}}};
				output_col_selector <= {{923{VhelperZeros}} , {VhelperOnes} , {100{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd925) begin
				end_col_selector <= {{925{VhelperZeros}} , {99{VhelperOnes}}};
				output_col_selector <= {{924{VhelperZeros}} , {VhelperOnes} , {99{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd926) begin
				end_col_selector <= {{926{VhelperZeros}} , {98{VhelperOnes}}};
				output_col_selector <= {{925{VhelperZeros}} , {VhelperOnes} , {98{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd927) begin
				end_col_selector <= {{927{VhelperZeros}} , {97{VhelperOnes}}};
				output_col_selector <= {{926{VhelperZeros}} , {VhelperOnes} , {97{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd928) begin
				end_col_selector <= {{928{VhelperZeros}} , {96{VhelperOnes}}};
				output_col_selector <= {{927{VhelperZeros}} , {VhelperOnes} , {96{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd929) begin
				end_col_selector <= {{929{VhelperZeros}} , {95{VhelperOnes}}};
				output_col_selector <= {{928{VhelperZeros}} , {VhelperOnes} , {95{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd930) begin
				end_col_selector <= {{930{VhelperZeros}} , {94{VhelperOnes}}};
				output_col_selector <= {{929{VhelperZeros}} , {VhelperOnes} , {94{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd931) begin
				end_col_selector <= {{931{VhelperZeros}} , {93{VhelperOnes}}};
				output_col_selector <= {{930{VhelperZeros}} , {VhelperOnes} , {93{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd932) begin
				end_col_selector <= {{932{VhelperZeros}} , {92{VhelperOnes}}};
				output_col_selector <= {{931{VhelperZeros}} , {VhelperOnes} , {92{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd933) begin
				end_col_selector <= {{933{VhelperZeros}} , {91{VhelperOnes}}};
				output_col_selector <= {{932{VhelperZeros}} , {VhelperOnes} , {91{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd934) begin
				end_col_selector <= {{934{VhelperZeros}} , {90{VhelperOnes}}};
				output_col_selector <= {{933{VhelperZeros}} , {VhelperOnes} , {90{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd935) begin
				end_col_selector <= {{935{VhelperZeros}} , {89{VhelperOnes}}};
				output_col_selector <= {{934{VhelperZeros}} , {VhelperOnes} , {89{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd936) begin
				end_col_selector <= {{936{VhelperZeros}} , {88{VhelperOnes}}};
				output_col_selector <= {{935{VhelperZeros}} , {VhelperOnes} , {88{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd937) begin
				end_col_selector <= {{937{VhelperZeros}} , {87{VhelperOnes}}};
				output_col_selector <= {{936{VhelperZeros}} , {VhelperOnes} , {87{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd938) begin
				end_col_selector <= {{938{VhelperZeros}} , {86{VhelperOnes}}};
				output_col_selector <= {{937{VhelperZeros}} , {VhelperOnes} , {86{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd939) begin
				end_col_selector <= {{939{VhelperZeros}} , {85{VhelperOnes}}};
				output_col_selector <= {{938{VhelperZeros}} , {VhelperOnes} , {85{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd940) begin
				end_col_selector <= {{940{VhelperZeros}} , {84{VhelperOnes}}};
				output_col_selector <= {{939{VhelperZeros}} , {VhelperOnes} , {84{VhelperZeros}}};	
			end


			else if (inst[start_of_output:end_of_output] == 10'd941) begin
				end_col_selector <= {{941{VhelperZeros}} , {83{VhelperOnes}}};
				output_col_selector <= {{940{VhelperZeros}} , {VhelperOnes} , {83{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd942) begin
				end_col_selector <= {{942{VhelperZeros}} , {82{VhelperOnes}}};
				output_col_selector <= {{941{VhelperZeros}} , {VhelperOnes} , {82{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd943) begin
				end_col_selector <= {{943{VhelperZeros}} , {81{VhelperOnes}}};
				output_col_selector <= {{942{VhelperZeros}} , {VhelperOnes} , {81{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd944) begin
				end_col_selector <= {{944{VhelperZeros}} , {80{VhelperOnes}}};
				output_col_selector <= {{943{VhelperZeros}} , {VhelperOnes} , {80{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd945) begin
				end_col_selector <= {{945{VhelperZeros}} , {79{VhelperOnes}}};
				output_col_selector <= {{944{VhelperZeros}} , {VhelperOnes} , {79{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd946) begin
				end_col_selector <= {{946{VhelperZeros}} , {78{VhelperOnes}}};
				output_col_selector <= {{945{VhelperZeros}} , {VhelperOnes} , {78{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd947) begin
				end_col_selector <= {{947{VhelperZeros}} , {77{VhelperOnes}}};
				output_col_selector <= {{946{VhelperZeros}} , {VhelperOnes} , {77{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd948) begin
				end_col_selector <= {{948{VhelperZeros}} , {76{VhelperOnes}}};
				output_col_selector <= {{947{VhelperZeros}} , {VhelperOnes} , {76{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd949) begin
				end_col_selector <= {{949{VhelperZeros}} , {75{VhelperOnes}}};
				output_col_selector <= {{948{VhelperZeros}} , {VhelperOnes} , {75{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd950) begin
				end_col_selector <= {{950{VhelperZeros}} , {74{VhelperOnes}}};
				output_col_selector <= {{949{VhelperZeros}} , {VhelperOnes} , {74{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd951) begin
				end_col_selector <= {{951{VhelperZeros}} , {73{VhelperOnes}}};
				output_col_selector <= {{950{VhelperZeros}} , {VhelperOnes} , {73{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd952) begin
				end_col_selector <= {{952{VhelperZeros}} , {72{VhelperOnes}}};
				output_col_selector <= {{951{VhelperZeros}} , {VhelperOnes} , {72{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd953) begin
				end_col_selector <= {{953{VhelperZeros}} , {71{VhelperOnes}}};
				output_col_selector <= {{952{VhelperZeros}} , {VhelperOnes} , {71{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd954) begin
				end_col_selector <= {{954{VhelperZeros}} , {70{VhelperOnes}}};
				output_col_selector <= {{953{VhelperZeros}} , {VhelperOnes} , {70{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd955) begin
				end_col_selector <= {{955{VhelperZeros}} , {69{VhelperOnes}}};
				output_col_selector <= {{954{VhelperZeros}} , {VhelperOnes} , {69{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd956) begin
				end_col_selector <= {{956{VhelperZeros}} , {68{VhelperOnes}}};
				output_col_selector <= {{955{VhelperZeros}} , {VhelperOnes} , {68{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd957) begin
				end_col_selector <= {{957{VhelperZeros}} , {67{VhelperOnes}}};
				output_col_selector <= {{956{VhelperZeros}} , {VhelperOnes} , {67{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd958) begin
				end_col_selector <= {{958{VhelperZeros}} , {66{VhelperOnes}}};
				output_col_selector <= {{957{VhelperZeros}} , {VhelperOnes} , {66{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd959) begin
				end_col_selector <= {{959{VhelperZeros}} , {65{VhelperOnes}}};
				output_col_selector <= {{958{VhelperZeros}} , {VhelperOnes} , {65{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd960) begin
				end_col_selector <= {{960{VhelperZeros}} , {64{VhelperOnes}}};
				output_col_selector <= {{959{VhelperZeros}} , {VhelperOnes} , {64{VhelperZeros}}};	
			end       




			else if (inst[start_of_output:end_of_output] == 10'd961) begin
				end_col_selector <= {{961{VhelperZeros}} , {63{VhelperOnes}}};
				output_col_selector <= {{960{VhelperZeros}} , {VhelperOnes} , {63{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd962) begin
				end_col_selector <= {{962{VhelperZeros}} , {62{VhelperOnes}}};
				output_col_selector <= {{961{VhelperZeros}} , {VhelperOnes} , {62{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd963) begin
				end_col_selector <= {{963{VhelperZeros}} , {61{VhelperOnes}}};
				output_col_selector <= {{962{VhelperZeros}} , {VhelperOnes} , {61{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd964) begin
				end_col_selector <= {{964{VhelperZeros}} , {60{VhelperOnes}}};
				output_col_selector <= {{963{VhelperZeros}} , {VhelperOnes} , {60{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd965) begin
				end_col_selector <= {{965{VhelperZeros}} , {59{VhelperOnes}}};
				output_col_selector <= {{964{VhelperZeros}} , {VhelperOnes} , {59{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd966) begin
				end_col_selector <= {{966{VhelperZeros}} , {58{VhelperOnes}}};
				output_col_selector <= {{965{VhelperZeros}} , {VhelperOnes} , {58{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd967) begin
				end_col_selector <= {{967{VhelperZeros}} , {57{VhelperOnes}}};
				output_col_selector <= {{966{VhelperZeros}} , {VhelperOnes} , {57{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd968) begin
				end_col_selector <= {{968{VhelperZeros}} , {56{VhelperOnes}}};
				output_col_selector <= {{967{VhelperZeros}} , {VhelperOnes} , {56{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd969) begin
				end_col_selector <= {{969{VhelperZeros}} , {55{VhelperOnes}}};
				output_col_selector <= {{968{VhelperZeros}} , {VhelperOnes} , {55{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd970) begin
				end_col_selector <= {{970{VhelperZeros}} , {54{VhelperOnes}}};
				output_col_selector <= {{969{VhelperZeros}} , {VhelperOnes} , {54{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd971) begin
				end_col_selector <= {{971{VhelperZeros}} , {53{VhelperOnes}}};
				output_col_selector <= {{970{VhelperZeros}} , {VhelperOnes} , {53{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd972) begin
				end_col_selector <= {{972{VhelperZeros}} , {52{VhelperOnes}}};
				output_col_selector <= {{971{VhelperZeros}} , {VhelperOnes} , {52{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd973) begin
				end_col_selector <= {{973{VhelperZeros}} , {51{VhelperOnes}}};
				output_col_selector <= {{972{VhelperZeros}} , {VhelperOnes} , {51{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd974) begin
				end_col_selector <= {{974{VhelperZeros}} , {50{VhelperOnes}}};
				output_col_selector <= {{973{VhelperZeros}} , {VhelperOnes} , {50{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd975) begin
				end_col_selector <= {{975{VhelperZeros}} , {49{VhelperOnes}}};
				output_col_selector <= {{974{VhelperZeros}} , {VhelperOnes} , {49{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd976) begin
				end_col_selector <= {{976{VhelperZeros}} , {48{VhelperOnes}}};
				output_col_selector <= {{975{VhelperZeros}} , {VhelperOnes} , {48{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd977) begin
				end_col_selector <= {{977{VhelperZeros}} , {47{VhelperOnes}}};
				output_col_selector <= {{976{VhelperZeros}} , {VhelperOnes} , {47{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd978) begin
				end_col_selector <= {{978{VhelperZeros}} , {46{VhelperOnes}}};
				output_col_selector <= {{977{VhelperZeros}} , {VhelperOnes} , {46{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd979) begin
				end_col_selector <= {{979{VhelperZeros}} , {45{VhelperOnes}}};
				output_col_selector <= {{978{VhelperZeros}} , {VhelperOnes} , {45{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd980) begin
				end_col_selector <= {{980{VhelperZeros}} , {44{VhelperOnes}}};
				output_col_selector <= {{979{VhelperZeros}} , {VhelperOnes} , {44{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd981) begin
				end_col_selector <= {{981{VhelperZeros}} , {43{VhelperOnes}}};
				output_col_selector <= {{980{VhelperZeros}} , {VhelperOnes} , {43{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd982) begin
				end_col_selector <= {{982{VhelperZeros}} , {42{VhelperOnes}}};
				output_col_selector <= {{981{VhelperZeros}} , {VhelperOnes} , {42{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd983) begin
				end_col_selector <= {{983{VhelperZeros}} , {41{VhelperOnes}}};
				output_col_selector <= {{982{VhelperZeros}} , {VhelperOnes} , {41{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd984) begin
				end_col_selector <= {{984{VhelperZeros}} , {40{VhelperOnes}}};
				output_col_selector <= {{983{VhelperZeros}} , {VhelperOnes} , {40{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd985) begin
				end_col_selector <= {{985{VhelperZeros}} , {39{VhelperOnes}}};
				output_col_selector <= {{984{VhelperZeros}} , {VhelperOnes} , {39{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd986) begin
				end_col_selector <= {{986{VhelperZeros}} , {38{VhelperOnes}}};
				output_col_selector <= {{985{VhelperZeros}} , {VhelperOnes} , {38{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd987) begin
				end_col_selector <= {{987{VhelperZeros}} , {37{VhelperOnes}}};
				output_col_selector <= {{986{VhelperZeros}} , {VhelperOnes} , {37{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd988) begin
				end_col_selector <= {{988{VhelperZeros}} , {36{VhelperOnes}}};
				output_col_selector <= {{987{VhelperZeros}} , {VhelperOnes} , {36{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd989) begin
				end_col_selector <= {{989{VhelperZeros}} , {35{VhelperOnes}}};
				output_col_selector <= {{988{VhelperZeros}} , {VhelperOnes} , {35{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd990) begin
				end_col_selector <= {{990{VhelperZeros}} , {34{VhelperOnes}}};
				output_col_selector <= {{989{VhelperZeros}} , {VhelperOnes} , {34{VhelperZeros}}};	
			end




			else if (inst[start_of_output:end_of_output] == 10'd991) begin
				end_col_selector <= {{991{VhelperZeros}} , {33{VhelperOnes}}};
				output_col_selector <= {{990{VhelperZeros}} , {VhelperOnes} , {33{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd992) begin
				end_col_selector <= {{992{VhelperZeros}} , {32{VhelperOnes}}};
				output_col_selector <= {{991{VhelperZeros}} , {VhelperOnes} , {32{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd993) begin
				end_col_selector <= {{993{VhelperZeros}} , {31{VhelperOnes}}};
				output_col_selector <= {{992{VhelperZeros}} , {VhelperOnes} , {31{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd994) begin
				end_col_selector <= {{994{VhelperZeros}} , {30{VhelperOnes}}};
				output_col_selector <= {{993{VhelperZeros}} , {VhelperOnes} , {30{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd995) begin
				end_col_selector <= {{995{VhelperZeros}} , {29{VhelperOnes}}};
				output_col_selector <= {{994{VhelperZeros}} , {VhelperOnes} , {29{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd996) begin
				end_col_selector <= {{996{VhelperZeros}} , {28{VhelperOnes}}};
				output_col_selector <= {{995{VhelperZeros}} , {VhelperOnes} , {28{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd997) begin
				end_col_selector <= {{997{VhelperZeros}} , {27{VhelperOnes}}};
				output_col_selector <= {{996{VhelperZeros}} , {VhelperOnes} , {27{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd998) begin
				end_col_selector <= {{998{VhelperZeros}} , {26{VhelperOnes}}};
				output_col_selector <= {{997{VhelperZeros}} , {VhelperOnes} , {26{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd999) begin
				end_col_selector <= {{999{VhelperZeros}} , {25{VhelperOnes}}};
				output_col_selector <= {{998{VhelperZeros}} , {VhelperOnes} , {25{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1000) begin
				end_col_selector <= {{1000{VhelperZeros}} , {24{VhelperOnes}}};
				output_col_selector <= {{999{VhelperZeros}} , {VhelperOnes} , {24{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd1001) begin
				end_col_selector <= {{1001{VhelperZeros}} , {23{VhelperOnes}}};
				output_col_selector <= {{1000{VhelperZeros}} , {VhelperOnes} , {23{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1002) begin
				end_col_selector <= {{1002{VhelperZeros}} , {22{VhelperOnes}}};
				output_col_selector <= {{1001{VhelperZeros}} , {VhelperOnes} , {22{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1003) begin
				end_col_selector <= {{1003{VhelperZeros}} , {21{VhelperOnes}}};
				output_col_selector <= {{1002{VhelperZeros}} , {VhelperOnes} , {21{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1004) begin
				end_col_selector <= {{1004{VhelperZeros}} , {20{VhelperOnes}}};
				output_col_selector <= {{1003{VhelperZeros}} , {VhelperOnes} , {20{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1005) begin
				end_col_selector <= {{1005{VhelperZeros}} , {19{VhelperOnes}}};
				output_col_selector <= {{1004{VhelperZeros}} , {VhelperOnes} , {19{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1006) begin
				end_col_selector <= {{1006{VhelperZeros}} , {18{VhelperOnes}}};
				output_col_selector <= {{1005{VhelperZeros}} , {VhelperOnes} , {18{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1007) begin
				end_col_selector <= {{1007{VhelperZeros}} , {17{VhelperOnes}}};
				output_col_selector <= {{1006{VhelperZeros}} , {VhelperOnes} , {17{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1008) begin
				end_col_selector <= {{1008{VhelperZeros}} , {16{VhelperOnes}}};
				output_col_selector <= {{1007{VhelperZeros}} , {VhelperOnes} , {16{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1009) begin
				end_col_selector <= {{1009{VhelperZeros}} , {15{VhelperOnes}}};
				output_col_selector <= {{1008{VhelperZeros}} , {VhelperOnes} , {15{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1010) begin
				end_col_selector <= {{1010{VhelperZeros}} , {14{VhelperOnes}}};
				output_col_selector <= {{1009{VhelperZeros}} , {VhelperOnes} , {14{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd1011) begin
				end_col_selector <= {{1011{VhelperZeros}} , {13{VhelperOnes}}};
				output_col_selector <= {{1010{VhelperZeros}} , {VhelperOnes} , {13{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1012) begin
				end_col_selector <= {{1012{VhelperZeros}} , {12{VhelperOnes}}};
				output_col_selector <= {{1011{VhelperZeros}} , {VhelperOnes} , {12{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1013) begin
				end_col_selector <= {{1013{VhelperZeros}} , {11{VhelperOnes}}};
				output_col_selector <= {{1012{VhelperZeros}} , {VhelperOnes} , {11{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1014) begin
				end_col_selector <= {{1014{VhelperZeros}} , {10{VhelperOnes}}};
				output_col_selector <= {{1013{VhelperZeros}} , {VhelperOnes} , {10{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1015) begin
				end_col_selector <= {{1015{VhelperZeros}} , {9{VhelperOnes}}};
				output_col_selector <= {{1014{VhelperZeros}} , {VhelperOnes} , {9{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1016) begin
				end_col_selector <= {{1016{VhelperZeros}} , {8{VhelperOnes}}};
				output_col_selector <= {{1015{VhelperZeros}} , {VhelperOnes} , {8{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1017) begin
				end_col_selector <= {{1017{VhelperZeros}} , {7{VhelperOnes}}};
				output_col_selector <= {{1016{VhelperZeros}} , {VhelperOnes} , {7{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1018) begin
				end_col_selector <= {{1018{VhelperZeros}} , {6{VhelperOnes}}};
				output_col_selector <= {{1017{VhelperZeros}} , {VhelperOnes} , {6{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1019) begin
				end_col_selector <= {{1019{VhelperZeros}} , {5{VhelperOnes}}};
				output_col_selector <= {{1018{VhelperZeros}} , {VhelperOnes} , {5{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1020) begin
				end_col_selector <= {{1020{VhelperZeros}} , {4{VhelperOnes}}};
				output_col_selector <= {{1019{VhelperZeros}} , {VhelperOnes} , {4{VhelperZeros}}};	
			end



			else if (inst[start_of_output:end_of_output] == 10'd1021) begin
				end_col_selector <= {{1021{VhelperZeros}} , {3{VhelperOnes}}};
				output_col_selector <= {{1020{VhelperZeros}} , {VhelperOnes} , {3{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1022) begin
				end_col_selector <= {{1022{VhelperZeros}} , {2{VhelperOnes}}};
				output_col_selector <= {{1021{VhelperZeros}} , {VhelperOnes} , {2{VhelperZeros}}};	
			end
			else if (inst[start_of_output:end_of_output] == 10'd1023) begin
				end_col_selector <= {{1023{VhelperZeros}} , {VhelperOnes}};
				output_col_selector <= {{1022{VhelperZeros}} , {VhelperOnes} , {1{VhelperZeros}}};	
			end
			//else if (inst[start_of_output:end_of_output] == 10'd1024) begin
				//end_col_selector <= {1024{VhelperZeros}};
				//output_col_selector <= {{1023{VhelperZeros}} , {VhelperOnes}};	
			//end
			


/////////////////////////////////////////////////////////////////////







/////////////////////////// Start Row Selector

			if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd1) begin
				start_row_selector <= {64{VhelperZeros}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd2) begin
				start_row_selector <= {{1{VhelperOnes}} , {63{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd3) begin
				start_row_selector <= {{2{VhelperOnes}} , {62{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd4) begin
				start_row_selector <= {{3{VhelperOnes}} , {61{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd5) begin
				start_row_selector <= {{4{VhelperOnes}} , {60{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd6) begin
				start_row_selector <= {{5{VhelperOnes}} , {59{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd7) begin
				start_row_selector <= {{6{VhelperOnes}} , {58{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd8) begin
				start_row_selector <= {{7{VhelperOnes}} , {57{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd9) begin //  num_of_rows_in_crossbar - (num_of_rows_in_crossbar - start_row)
				start_row_selector <= {{8{VhelperOnes}} , {56{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd10) begin 
				start_row_selector <= {{9{VhelperOnes}} , {55{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd11) begin
				start_row_selector <= {{10{VhelperOnes}} , {54{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd12) begin
				start_row_selector <= {{11{VhelperOnes}} , {53{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd13) begin
				start_row_selector <= {{12{VhelperOnes}} , {52{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd14) begin
				start_row_selector <= {{13{VhelperOnes}} , {51{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd15) begin
				start_row_selector <= {{14{VhelperOnes}} , {50{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd16) begin
				start_row_selector <= {{15{VhelperOnes}} , {49{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd17) begin
				start_row_selector <= {{16{VhelperOnes}} , {48{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd18) begin
				start_row_selector <= {{17{VhelperOnes}} , {47{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd19) begin 
				start_row_selector <= {{18{VhelperOnes}} , {46{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd20) begin 
				start_row_selector <= {{19{VhelperOnes}} , {45{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd21) begin
				start_row_selector <= {{20{VhelperOnes}} , {44{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd22) begin
				start_row_selector <= {{21{VhelperOnes}} , {43{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd23) begin
				start_row_selector <= {{22{VhelperOnes}} , {42{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd24) begin
				start_row_selector <= {{23{VhelperOnes}} , {41{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd25) begin
				start_row_selector <= {{24{VhelperOnes}} , {40{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd26) begin
				start_row_selector <= {{25{VhelperOnes}} , {39{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd27) begin
				start_row_selector <= {{26{VhelperOnes}} , {38{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd28) begin
				start_row_selector <= {{27{VhelperOnes}} , {37{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd29) begin 
				start_row_selector <= {{28{VhelperOnes}} , {36{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd30) begin 
				start_row_selector <= {{29{VhelperOnes}} , {35{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd31) begin
				start_row_selector <= {{30{VhelperOnes}} , {34{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd32) begin
				start_row_selector <= {{31{VhelperOnes}} , {33{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd33) begin
				start_row_selector <= {{32{VhelperOnes}} , {32{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd34) begin
				start_row_selector <= {{33{VhelperOnes}} , {31{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd35) begin
				start_row_selector <= {{34{VhelperOnes}} , {30{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd36) begin
				start_row_selector <= {{35{VhelperOnes}} , {29{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd37) begin
				start_row_selector <= {{36{VhelperOnes}} , {28{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd38) begin
				start_row_selector <= {{37{VhelperOnes}} , {27{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd39) begin 
				start_row_selector <= {{38{VhelperOnes}} , {26{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd40) begin 
				start_row_selector <= {{39{VhelperOnes}} , {25{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd41) begin
				start_row_selector <= {{40{VhelperOnes}} , {24{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd42) begin
				start_row_selector <= {{41{VhelperOnes}} , {23{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd43) begin
				start_row_selector <= {{42{VhelperOnes}} , {22{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd44) begin
				start_row_selector <= {{43{VhelperOnes}} , {21{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd45) begin
				start_row_selector <= {{44{VhelperOnes}} , {20{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd46) begin
				start_row_selector <= {{45{VhelperOnes}} , {19{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd47) begin
				start_row_selector <= {{46{VhelperOnes}} , {18{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd48) begin
				start_row_selector <= {{47{VhelperOnes}} , {17{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd49) begin 
				start_row_selector <= {{48{VhelperOnes}} , {16{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd50) begin 
				start_row_selector <= {{49{VhelperOnes}} , {15{VhelperZeros}}};
			end	
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd51) begin
				start_row_selector <= {{50{VhelperOnes}} , {14{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd52) begin
				start_row_selector <= {{51{VhelperOnes}} , {13{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd53) begin
				start_row_selector <= {{52{VhelperOnes}} , {12{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd54) begin
				start_row_selector <= {{53{VhelperOnes}} , {11{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd55) begin
				start_row_selector <= {{54{VhelperOnes}} , {10{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd56) begin
				start_row_selector <= {{55{VhelperOnes}} , {9{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd57) begin
				start_row_selector <= {{56{VhelperOnes}} , {8{VhelperZeros}}};	
			end
			else if (inst[start_of_Start_Row:end_of_Start_Row] == 10'd58) begin
				start_row_selector <= {{57{VhelperOnes}} , {7{VhelperZeros}}};	
			end






///////////////////////////////////// End Row Selector




if (inst[start_of_End_Row:end_of_End_Row] == 10'd2) begin
	end_row_selector <= {{2{VhelperZeros}} , {62{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd3) begin
	end_row_selector <= {{3{VhelperZeros}} , {61{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd4) begin 
	end_row_selector <= {{4{VhelperZeros}} , {60{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd5) begin
	end_row_selector <= {{5{VhelperZeros}} , {59{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd6) begin
	end_row_selector <= {{6{VhelperZeros}} , {58{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd7) begin 
	end_row_selector <= {{7{VhelperZeros}} , {57{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd8) begin
	end_row_selector <= {{8{VhelperZeros}} , {56{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd9) begin
	end_row_selector <= {{9{VhelperZeros}} , {55{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd10) begin 
	end_row_selector <= {{10{VhelperZeros}} , {54{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd11) begin
	end_row_selector <= {{11{VhelperZeros}} , {53{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd12) begin
	end_row_selector <= {{12{VhelperZeros}} , {52{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd13) begin
	end_row_selector <= {{13{VhelperZeros}} , {51{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd14) begin 
	end_row_selector <= {{14{VhelperZeros}} , {50{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd15) begin
	end_row_selector <= {{15{VhelperZeros}} , {49{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd16) begin
	end_row_selector <= {{16{VhelperZeros}} , {48{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd17) begin 
	end_row_selector <= {{17{VhelperZeros}} , {47{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd18) begin
	end_row_selector <= {{18{VhelperZeros}} , {46{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd19) begin
	end_row_selector <= {{19{VhelperZeros}} , {45{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd20) begin 
	end_row_selector <= {{20{VhelperZeros}} , {44{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd21) begin
	end_row_selector <= {{21{VhelperZeros}} , {43{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd22) begin
	end_row_selector <= {{22{VhelperZeros}} , {42{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd23) begin
	end_row_selector <= {{23{VhelperZeros}} , {41{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd24) begin 
	end_row_selector <= {{24{VhelperZeros}} , {40{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd25) begin
	end_row_selector <= {{25{VhelperZeros}} , {39{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd26) begin
	end_row_selector <= {{26{VhelperZeros}} , {38{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd27) begin 
	end_row_selector <= {{27{VhelperZeros}} , {37{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd28) begin
	end_row_selector <= {{28{VhelperZeros}} , {36{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd29) begin
	end_row_selector <= {{29{VhelperZeros}} , {35{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd30) begin 
	end_row_selector <= {{30{VhelperZeros}} , {34{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd31) begin
	end_row_selector <= {{31{VhelperZeros}} , {33{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd32) begin
	end_row_selector <= {{32{VhelperZeros}} , {32{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd33) begin
	end_row_selector <= {{33{VhelperZeros}} , {31{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd34) begin 
	end_row_selector <= {{34{VhelperZeros}} , {30{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd35) begin
	end_row_selector <= {{35{VhelperZeros}} , {29{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd36) begin
	end_row_selector <= {{36{VhelperZeros}} , {28{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd37) begin 
	end_row_selector <= {{37{VhelperZeros}} , {27{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd38) begin
	end_row_selector <= {{38{VhelperZeros}} , {26{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd39) begin
	end_row_selector <= {{39{VhelperZeros}} , {25{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd40) begin 
	end_row_selector <= {{40{VhelperZeros}} , {24{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd41) begin
	end_row_selector <= {{41{VhelperZeros}} , {23{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd42) begin
	end_row_selector <= {{42{VhelperZeros}} , {22{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd43) begin
	end_row_selector <= {{43{VhelperZeros}} , {21{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd44) begin 
	end_row_selector <= {{44{VhelperZeros}} , {20{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd45) begin
	end_row_selector <= {{45{VhelperZeros}} , {19{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd46) begin
	end_row_selector <= {{46{VhelperZeros}} , {18{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd47) begin 
	end_row_selector <= {{47{VhelperZeros}} , {17{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd48) begin
	end_row_selector <= {{48{VhelperZeros}} , {16{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd49) begin
	end_row_selector <= {{49{VhelperZeros}} , {15{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd50) begin 
	end_row_selector <= {{50{VhelperZeros}} , {14{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd51) begin
	end_row_selector <= {{51{VhelperZeros}} , {13{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd52) begin
	end_row_selector <= {{52{VhelperZeros}} , {12{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd53) begin
	end_row_selector <= {{53{VhelperZeros}} , {11{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd54) begin 
	end_row_selector <= {{54{VhelperZeros}} , {10{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd55) begin
	end_row_selector <= {{55{VhelperZeros}} , {9{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd56) begin
	end_row_selector <= {{56{VhelperZeros}} , {8{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd57) begin 
	end_row_selector <= {{57{VhelperZeros}} , {7{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd58) begin
	end_row_selector <= {{58{VhelperZeros}} , {6{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd59) begin
	end_row_selector <= {{59{VhelperZeros}} , {5{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd60) begin //  num_of_rows_in_crossbar - (num_of_rows_in_crossbar - end_row)
	end_row_selector <= {{60{VhelperZeros}} , {4{VhelperOnes}}};
end	
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd61) begin
	end_row_selector <= {{61{VhelperZeros}} , {3{VhelperOnes}}};	
end
else if (inst[start_of_End_Row:end_of_End_Row] == 10'd62) begin
	end_row_selector <= {{62{VhelperZeros}} , {2{VhelperOnes}}};	
end






////////////////////////////////
			row_selector <= { { start_row_selector & {64{Visolate}} } | { {~{{start_row_selector} | {end_row_selector}}} & {64{Vfloating}} } | { end_row_selector & {64{Visolate}} } };


			col_selector <= { { start_col_selector & {1024{Visolate}} } | {  input1_col_selector & {1024{Vmagic}} } | { { {~{input2_col_selector}} & { {{start_col_selector} | {input1_col_selector}} | {{end_col_selector} | {output_col_selector}} } } & {1024{Visolate}} } | {{input2_col_selector} & {1024{Vmagic}}} | {{output_col_selector} & {1024{Vground}}} | {{end_col_selector} & {1024{Visolate}}} };

			// row_selector <= {{(num_of_rows_in_crossbar - end_row){Visolate}}, {(end_row - start_row + 1){Vfloating}}, {end_row{Visolate}}};
			// col_selector <= {{(num_of_cols_in_crossbar - input1_loc){Visolate}}, Vmagic, {(input1_loc - input2_loc - 1){Visolate}}, Vmagic, {(input2_loc - output_loc - 1){Visolate}}, Vground, {output_loc{Visolate}}};

			// input1 = inst[509:500] , input2 = inst[499:490] , output = inst[489:480]
			// end_row > start_row (in its value not in its location) , start_row = inst[479:470] , end_row = inst[469:460] , 
			// num_of_duplications_of_Visolate_before_start = 64 - end_row , num_of_duplications_of_Vfloating_in_gap_between_startRow_and_endRow = end_row - start_row + 1 , num_of_duplications_of_Visolate_after_endRow = end_row
			// col_selector <= {{num_of_duplications_of_Visolate_before_first_input{Visolate}}, Vmagic, {num_of_duplications_of_Visolate_in_gap_between_two_inputs{Visolate}}, Vmagic, {num_of_duplications_of_Visolate_between_input2_and_output{Visolate}}, Vground, {(output){Visolate}}};
			// row_selector <= {{num_of_duplications_of_Visolate_before_start{Visolate}}, {num_of_duplications_of_Vfloating_in_gap_between_startRow_and_endRow{Vfloating}}, {num_of_duplications_of_Visolate_after_endRow{Visolate}}};
		end

		else if (inst[511:510] == 2'b01) begin // Reading a read from FIFO and writing it to all its lines before calculation \\ inst[size_of_instruction-9'b000000001:size_of_instruction - num_of_bits_type_of_inst] = inst[512 - 1:512 - 2] = inst[511:510]
			flag_read_from_FIFO <= 1'b1;               
///////////////////////// We must know exactly how many lines are in the FIFO in order to use this method
			
			//row_selector <= {{(num_of_rows_in_crossbar - counter_row_calc){Vfloating}}, Vresistor, {counter_row_calc{Vfloating}}};

			if (counter_row_calc == 3'b001) begin
				row_selector <= {{59{Vfloating}}, Vresistor, {4{Vfloating}}};
			end
			else if (counter_row_calc == 3'b010) begin
				row_selector <= {{60{Vfloating}}, Vresistor, {3{Vfloating}}};
			end
			else if (counter_row_calc == 3'b011) begin
				row_selector <= {{61{Vfloating}}, Vresistor, {2{Vfloating}}};
			end
			else if (counter_row_calc == 3'b100) begin
				row_selector <= {{62{Vfloating}}, Vresistor, Vfloating};
			end
			else if (counter_row_calc == 3'b101) begin
				row_selector <= {{63{Vfloating}}, Vresistor};
			end



/////////////////////////

			if (counter_col_calc == 2'b01) begin
				col_selector <= {{12{Vfloating}},{300{Vr}}, {712{Vfloating}}};
				//col_selector <= {{(num_of_bits_of_index_read){Vfloating}},{(num_of_bits_in_read - num_of_bits_of_index_read){Vr}}, {(num_of_cols_in_crossbar - num_of_bits_in_read){Vfloating}}};

			end
			else if (counter_col_calc == 2'b10) begin
				col_selector <= {{324{Vfloating}}, {300{Vr}}, {400{Vfloating}}};
				//col_selector <= {{(num_of_bits_in_read + num_of_bits_of_index_read){Vfloating}}, {(num_of_bits_in_read - num_of_bits_of_index_read){Vr}}, {(num_of_cols_in_crossbar - num_of_bits_in_read - num_of_bits_in_read){Vfloating}}};

			end
			else if (counter_col_calc == 2'b11) begin
				col_selector <= {{636{Vfloating}}, {300{Vr}}, {88{Vfloating}}};                  
				//col_selector <= {{(num_of_bits_in_read + num_of_bits_in_read + num_of_bits_of_index_read){Vfloating}}, {(num_of_bits_in_read - num_of_bits_of_index_read){Vr}}, {(num_of_cols_in_crossbar - num_of_bits_in_read - num_of_bits_in_read - num_of_bits_in_read){Vfloating}}};                  
			end

/// Full FIFO check
			if ((counter_row_calc == counter_row_storage) && (counter_col_storage == (counter_col_calc - 2'b01))) begin
				flag_full_FIFO <= 1'b1;
			end
			else if ((counter_row_calc == (counter_row_storage - 3'b001)) && (counter_col_calc == 2'b01) && (counter_col_storage == 2'b11)) begin
				flag_full_FIFO <= 1'b1;
			end
			else begin 
				flag_full_FIFO <= 1'b0;
			end
			
			counter_row_calc <= counter_row_calc + 3'b001;
			counter_col_calc <= counter_col_calc + 2'b01;
		end





if (flag_read_from_FIFO == 1'b1) begin
	
	ones_positions <= {
			{{3{read_fromFIFO[299]}} & Vw1},{{3{read_fromFIFO[298]}} & Vw1},{{3{read_fromFIFO[297]}} & Vw1},{{3{read_fromFIFO[296]}} & Vw1},{{3{read_fromFIFO[295]}} & Vw1},{{3{read_fromFIFO[294]}} & Vw1},{{3{read_fromFIFO[293]}} & Vw1},{{3{read_fromFIFO[292]}} & Vw1},{{3{read_fromFIFO[291]}} & Vw1},{{3{read_fromFIFO[290]}} & Vw1}
			,{{3{read_fromFIFO[289]}} & Vw1},{{3{read_fromFIFO[288]}} & Vw1},{{3{read_fromFIFO[287]}} & Vw1},{{3{read_fromFIFO[286]}} & Vw1},{{3{read_fromFIFO[285]}} & Vw1},{{3{read_fromFIFO[284]}} & Vw1},{{3{read_fromFIFO[283]}} & Vw1},{{3{read_fromFIFO[282]}} & Vw1},{{3{read_fromFIFO[281]}} & Vw1},{{3{read_fromFIFO[280]}} & Vw1}
			,{{3{read_fromFIFO[279]}} & Vw1},{{3{read_fromFIFO[278]}} & Vw1},{{3{read_fromFIFO[277]}} & Vw1},{{3{read_fromFIFO[276]}} & Vw1},{{3{read_fromFIFO[275]}} & Vw1},{{3{read_fromFIFO[274]}} & Vw1},{{3{read_fromFIFO[273]}} & Vw1},{{3{read_fromFIFO[272]}} & Vw1},{{3{read_fromFIFO[271]}} & Vw1},{{3{read_fromFIFO[270]}} & Vw1}
			,{{3{read_fromFIFO[269]}} & Vw1},{{3{read_fromFIFO[268]}} & Vw1},{{3{read_fromFIFO[267]}} & Vw1},{{3{read_fromFIFO[266]}} & Vw1},{{3{read_fromFIFO[265]}} & Vw1},{{3{read_fromFIFO[264]}} & Vw1},{{3{read_fromFIFO[263]}} & Vw1},{{3{read_fromFIFO[262]}} & Vw1},{{3{read_fromFIFO[261]}} & Vw1},{{3{read_fromFIFO[260]}} & Vw1}
			,{{3{read_fromFIFO[259]}} & Vw1},{{3{read_fromFIFO[258]}} & Vw1},{{3{read_fromFIFO[257]}} & Vw1},{{3{read_fromFIFO[256]}} & Vw1},{{3{read_fromFIFO[255]}} & Vw1},{{3{read_fromFIFO[254]}} & Vw1},{{3{read_fromFIFO[253]}} & Vw1},{{3{read_fromFIFO[252]}} & Vw1},{{3{read_fromFIFO[251]}} & Vw1},{{3{read_fromFIFO[250]}} & Vw1}
			,{{3{read_fromFIFO[249]}} & Vw1},{{3{read_fromFIFO[248]}} & Vw1},{{3{read_fromFIFO[247]}} & Vw1},{{3{read_fromFIFO[246]}} & Vw1},{{3{read_fromFIFO[245]}} & Vw1},{{3{read_fromFIFO[244]}} & Vw1},{{3{read_fromFIFO[243]}} & Vw1},{{3{read_fromFIFO[242]}} & Vw1},{{3{read_fromFIFO[241]}} & Vw1},{{3{read_fromFIFO[240]}} & Vw1}
			,{{3{read_fromFIFO[239]}} & Vw1},{{3{read_fromFIFO[238]}} & Vw1},{{3{read_fromFIFO[237]}} & Vw1},{{3{read_fromFIFO[236]}} & Vw1},{{3{read_fromFIFO[235]}} & Vw1},{{3{read_fromFIFO[234]}} & Vw1},{{3{read_fromFIFO[233]}} & Vw1},{{3{read_fromFIFO[232]}} & Vw1},{{3{read_fromFIFO[231]}} & Vw1},{{3{read_fromFIFO[230]}} & Vw1}
			,{{3{read_fromFIFO[229]}} & Vw1},{{3{read_fromFIFO[228]}} & Vw1},{{3{read_fromFIFO[227]}} & Vw1},{{3{read_fromFIFO[226]}} & Vw1},{{3{read_fromFIFO[225]}} & Vw1},{{3{read_fromFIFO[224]}} & Vw1},{{3{read_fromFIFO[223]}} & Vw1},{{3{read_fromFIFO[222]}} & Vw1},{{3{read_fromFIFO[221]}} & Vw1},{{3{read_fromFIFO[220]}} & Vw1}
			,{{3{read_fromFIFO[219]}} & Vw1},{{3{read_fromFIFO[218]}} & Vw1},{{3{read_fromFIFO[217]}} & Vw1},{{3{read_fromFIFO[216]}} & Vw1},{{3{read_fromFIFO[215]}} & Vw1},{{3{read_fromFIFO[214]}} & Vw1},{{3{read_fromFIFO[213]}} & Vw1},{{3{read_fromFIFO[212]}} & Vw1},{{3{read_fromFIFO[211]}} & Vw1},{{3{read_fromFIFO[210]}} & Vw1}
			,{{3{read_fromFIFO[209]}} & Vw1},{{3{read_fromFIFO[208]}} & Vw1},{{3{read_fromFIFO[207]}} & Vw1},{{3{read_fromFIFO[206]}} & Vw1},{{3{read_fromFIFO[205]}} & Vw1},{{3{read_fromFIFO[204]}} & Vw1},{{3{read_fromFIFO[203]}} & Vw1},{{3{read_fromFIFO[202]}} & Vw1},{{3{read_fromFIFO[201]}} & Vw1},{{3{read_fromFIFO[200]}} & Vw1}
			,{{3{read_fromFIFO[199]}} & Vw1},{{3{read_fromFIFO[198]}} & Vw1},{{3{read_fromFIFO[197]}} & Vw1},{{3{read_fromFIFO[196]}} & Vw1},{{3{read_fromFIFO[195]}} & Vw1},{{3{read_fromFIFO[194]}} & Vw1},{{3{read_fromFIFO[193]}} & Vw1},{{3{read_fromFIFO[192]}} & Vw1},{{3{read_fromFIFO[191]}} & Vw1},{{3{read_fromFIFO[190]}} & Vw1}
			,{{3{read_fromFIFO[189]}} & Vw1},{{3{read_fromFIFO[188]}} & Vw1},{{3{read_fromFIFO[187]}} & Vw1},{{3{read_fromFIFO[186]}} & Vw1},{{3{read_fromFIFO[185]}} & Vw1},{{3{read_fromFIFO[184]}} & Vw1},{{3{read_fromFIFO[183]}} & Vw1},{{3{read_fromFIFO[182]}} & Vw1},{{3{read_fromFIFO[181]}} & Vw1},{{3{read_fromFIFO[180]}} & Vw1}
			,{{3{read_fromFIFO[179]}} & Vw1},{{3{read_fromFIFO[178]}} & Vw1},{{3{read_fromFIFO[177]}} & Vw1},{{3{read_fromFIFO[176]}} & Vw1},{{3{read_fromFIFO[175]}} & Vw1},{{3{read_fromFIFO[174]}} & Vw1},{{3{read_fromFIFO[173]}} & Vw1},{{3{read_fromFIFO[172]}} & Vw1},{{3{read_fromFIFO[171]}} & Vw1},{{3{read_fromFIFO[170]}} & Vw1}
			,{{3{read_fromFIFO[169]}} & Vw1},{{3{read_fromFIFO[168]}} & Vw1},{{3{read_fromFIFO[167]}} & Vw1},{{3{read_fromFIFO[166]}} & Vw1},{{3{read_fromFIFO[165]}} & Vw1},{{3{read_fromFIFO[164]}} & Vw1},{{3{read_fromFIFO[163]}} & Vw1},{{3{read_fromFIFO[162]}} & Vw1},{{3{read_fromFIFO[161]}} & Vw1},{{3{read_fromFIFO[160]}} & Vw1}
			,{{3{read_fromFIFO[159]}} & Vw1},{{3{read_fromFIFO[158]}} & Vw1},{{3{read_fromFIFO[157]}} & Vw1},{{3{read_fromFIFO[156]}} & Vw1},{{3{read_fromFIFO[155]}} & Vw1},{{3{read_fromFIFO[154]}} & Vw1},{{3{read_fromFIFO[153]}} & Vw1},{{3{read_fromFIFO[152]}} & Vw1},{{3{read_fromFIFO[151]}} & Vw1},{{3{read_fromFIFO[150]}} & Vw1}
			,{{3{read_fromFIFO[149]}} & Vw1},{{3{read_fromFIFO[148]}} & Vw1},{{3{read_fromFIFO[147]}} & Vw1},{{3{read_fromFIFO[146]}} & Vw1},{{3{read_fromFIFO[145]}} & Vw1},{{3{read_fromFIFO[144]}} & Vw1},{{3{read_fromFIFO[143]}} & Vw1},{{3{read_fromFIFO[142]}} & Vw1},{{3{read_fromFIFO[141]}} & Vw1},{{3{read_fromFIFO[140]}} & Vw1}
			,{{3{read_fromFIFO[139]}} & Vw1},{{3{read_fromFIFO[138]}} & Vw1},{{3{read_fromFIFO[137]}} & Vw1},{{3{read_fromFIFO[136]}} & Vw1},{{3{read_fromFIFO[135]}} & Vw1},{{3{read_fromFIFO[134]}} & Vw1},{{3{read_fromFIFO[133]}} & Vw1},{{3{read_fromFIFO[132]}} & Vw1},{{3{read_fromFIFO[131]}} & Vw1},{{3{read_fromFIFO[130]}} & Vw1}
			,{{3{read_fromFIFO[129]}} & Vw1},{{3{read_fromFIFO[128]}} & Vw1},{{3{read_fromFIFO[127]}} & Vw1},{{3{read_fromFIFO[126]}} & Vw1},{{3{read_fromFIFO[125]}} & Vw1},{{3{read_fromFIFO[124]}} & Vw1},{{3{read_fromFIFO[123]}} & Vw1},{{3{read_fromFIFO[122]}} & Vw1},{{3{read_fromFIFO[121]}} & Vw1},{{3{read_fromFIFO[120]}} & Vw1}
			,{{3{read_fromFIFO[119]}} & Vw1},{{3{read_fromFIFO[118]}} & Vw1},{{3{read_fromFIFO[117]}} & Vw1},{{3{read_fromFIFO[116]}} & Vw1},{{3{read_fromFIFO[115]}} & Vw1},{{3{read_fromFIFO[114]}} & Vw1},{{3{read_fromFIFO[113]}} & Vw1},{{3{read_fromFIFO[112]}} & Vw1},{{3{read_fromFIFO[111]}} & Vw1},{{3{read_fromFIFO[110]}} & Vw1}
			,{{3{read_fromFIFO[109]}} & Vw1},{{3{read_fromFIFO[108]}} & Vw1},{{3{read_fromFIFO[107]}} & Vw1},{{3{read_fromFIFO[106]}} & Vw1},{{3{read_fromFIFO[105]}} & Vw1},{{3{read_fromFIFO[104]}} & Vw1},{{3{read_fromFIFO[103]}} & Vw1},{{3{read_fromFIFO[102]}} & Vw1},{{3{read_fromFIFO[101]}} & Vw1},{{3{read_fromFIFO[100]}} & Vw1}
			,{{3{read_fromFIFO[99]}} & Vw1},{{3{read_fromFIFO[98]}} & Vw1},{{3{read_fromFIFO[97]}} & Vw1},{{3{read_fromFIFO[96]}} & Vw1},{{3{read_fromFIFO[95]}} & Vw1},{{3{read_fromFIFO[94]}} & Vw1},{{3{read_fromFIFO[93]}} & Vw1},{{3{read_fromFIFO[92]}} & Vw1},{{3{read_fromFIFO[91]}} & Vw1},{{3{read_fromFIFO[90]}} & Vw1}               
			,{{3{read_fromFIFO[89]}} & Vw1},{{3{read_fromFIFO[88]}} & Vw1},{{3{read_fromFIFO[87]}} & Vw1},{{3{read_fromFIFO[86]}} & Vw1},{{3{read_fromFIFO[85]}} & Vw1},{{3{read_fromFIFO[84]}} & Vw1},{{3{read_fromFIFO[83]}} & Vw1},{{3{read_fromFIFO[82]}} & Vw1},{{3{read_fromFIFO[81]}} & Vw1},{{3{read_fromFIFO[80]}} & Vw1}
			,{{3{read_fromFIFO[79]}} & Vw1},{{3{read_fromFIFO[78]}} & Vw1},{{3{read_fromFIFO[77]}} & Vw1},{{3{read_fromFIFO[76]}} & Vw1},{{3{read_fromFIFO[75]}} & Vw1},{{3{read_fromFIFO[74]}} & Vw1},{{3{read_fromFIFO[73]}} & Vw1},{{3{read_fromFIFO[72]}} & Vw1},{{3{read_fromFIFO[71]}} & Vw1},{{3{read_fromFIFO[70]}} & Vw1}
			,{{3{read_fromFIFO[69]}} & Vw1},{{3{read_fromFIFO[68]}} & Vw1},{{3{read_fromFIFO[67]}} & Vw1},{{3{read_fromFIFO[66]}} & Vw1},{{3{read_fromFIFO[65]}} & Vw1},{{3{read_fromFIFO[64]}} & Vw1},{{3{read_fromFIFO[63]}} & Vw1},{{3{read_fromFIFO[62]}} & Vw1},{{3{read_fromFIFO[61]}} & Vw1},{{3{read_fromFIFO[60]}} & Vw1}
			,{{3{read_fromFIFO[59]}} & Vw1},{{3{read_fromFIFO[58]}} & Vw1},{{3{read_fromFIFO[57]}} & Vw1},{{3{read_fromFIFO[56]}} & Vw1},{{3{read_fromFIFO[55]}} & Vw1},{{3{read_fromFIFO[54]}} & Vw1},{{3{read_fromFIFO[53]}} & Vw1},{{3{read_fromFIFO[52]}} & Vw1},{{3{read_fromFIFO[51]}} & Vw1},{{3{read_fromFIFO[50]}} & Vw1}
			,{{3{read_fromFIFO[49]}} & Vw1},{{3{read_fromFIFO[48]}} & Vw1},{{3{read_fromFIFO[47]}} & Vw1},{{3{read_fromFIFO[46]}} & Vw1},{{3{read_fromFIFO[45]}} & Vw1},{{3{read_fromFIFO[44]}} & Vw1},{{3{read_fromFIFO[43]}} & Vw1},{{3{read_fromFIFO[42]}} & Vw1},{{3{read_fromFIFO[41]}} & Vw1},{{3{read_fromFIFO[40]}} & Vw1}
			,{{3{read_fromFIFO[39]}} & Vw1},{{3{read_fromFIFO[38]}} & Vw1},{{3{read_fromFIFO[37]}} & Vw1},{{3{read_fromFIFO[36]}} & Vw1},{{3{read_fromFIFO[35]}} & Vw1},{{3{read_fromFIFO[34]}} & Vw1},{{3{read_fromFIFO[33]}} & Vw1},{{3{read_fromFIFO[32]}} & Vw1},{{3{read_fromFIFO[31]}} & Vw1},{{3{read_fromFIFO[30]}} & Vw1}
			,{{3{read_fromFIFO[29]}} & Vw1},{{3{read_fromFIFO[28]}} & Vw1},{{3{read_fromFIFO[27]}} & Vw1},{{3{read_fromFIFO[26]}} & Vw1},{{3{read_fromFIFO[25]}} & Vw1},{{3{read_fromFIFO[24]}} & Vw1},{{3{read_fromFIFO[23]}} & Vw1},{{3{read_fromFIFO[22]}} & Vw1},{{3{read_fromFIFO[21]}} & Vw1},{{3{read_fromFIFO[20]}} & Vw1}
			,{{3{read_fromFIFO[19]}} & Vw1},{{3{read_fromFIFO[18]}} & Vw1},{{3{read_fromFIFO[17]}} & Vw1},{{3{read_fromFIFO[16]}} & Vw1},{{3{read_fromFIFO[15]}} & Vw1},{{3{read_fromFIFO[14]}} & Vw1},{{3{read_fromFIFO[13]}} & Vw1},{{3{read_fromFIFO[12]}} & Vw1},{{3{read_fromFIFO[11]}} & Vw1},{{3{read_fromFIFO[10]}} & Vw1}
			,{{3{read_fromFIFO[9]}} & Vw1},{{3{read_fromFIFO[8]}} & Vw1},{{3{read_fromFIFO[7]}} & Vw1},{{3{read_fromFIFO[6]}} & Vw1},{{3{read_fromFIFO[5]}} & Vw1},{{3{read_fromFIFO[4]}} & Vw1},{{3{read_fromFIFO[3]}} & Vw1},{{3{read_fromFIFO[2]}} & Vw1},{{3{read_fromFIFO[1]}} & Vw1},{{3{read_fromFIFO[0]}} & Vw1}
			,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0};

	zeros_positions <= {
			{{3{~read_fromFIFO[299]}} & Vw0},{{3{~read_fromFIFO[298]}} & Vw0},{{3{~read_fromFIFO[297]}} & Vw0},{{3{~read_fromFIFO[296]}} & Vw0},{{3{~read_fromFIFO[295]}} & Vw0},{{3{~read_fromFIFO[294]}} & Vw0},{{3{~read_fromFIFO[293]}} & Vw0},{{3{~read_fromFIFO[292]}} & Vw0},{{3{~read_fromFIFO[291]}} & Vw0},{{3{~read_fromFIFO[290]}} & Vw0}
			,{{3{~read_fromFIFO[289]}} & Vw0},{{3{~read_fromFIFO[288]}} & Vw0},{{3{~read_fromFIFO[287]}} & Vw0},{{3{~read_fromFIFO[286]}} & Vw0},{{3{~read_fromFIFO[285]}} & Vw0},{{3{~read_fromFIFO[284]}} & Vw0},{{3{~read_fromFIFO[283]}} & Vw0},{{3{~read_fromFIFO[282]}} & Vw0},{{3{~read_fromFIFO[281]}} & Vw0},{{3{~read_fromFIFO[280]}} & Vw0}
			,{{3{~read_fromFIFO[279]}} & Vw0},{{3{~read_fromFIFO[278]}} & Vw0},{{3{~read_fromFIFO[277]}} & Vw0},{{3{~read_fromFIFO[276]}} & Vw0},{{3{~read_fromFIFO[275]}} & Vw0},{{3{~read_fromFIFO[274]}} & Vw0},{{3{~read_fromFIFO[273]}} & Vw0},{{3{~read_fromFIFO[272]}} & Vw0},{{3{~read_fromFIFO[271]}} & Vw0},{{3{~read_fromFIFO[270]}} & Vw0}
			,{{3{~read_fromFIFO[269]}} & Vw0},{{3{~read_fromFIFO[268]}} & Vw0},{{3{~read_fromFIFO[267]}} & Vw0},{{3{~read_fromFIFO[266]}} & Vw0},{{3{~read_fromFIFO[265]}} & Vw0},{{3{~read_fromFIFO[264]}} & Vw0},{{3{~read_fromFIFO[263]}} & Vw0},{{3{~read_fromFIFO[262]}} & Vw0},{{3{~read_fromFIFO[261]}} & Vw0},{{3{~read_fromFIFO[260]}} & Vw0}
			,{{3{~read_fromFIFO[259]}} & Vw0},{{3{~read_fromFIFO[258]}} & Vw0},{{3{~read_fromFIFO[257]}} & Vw0},{{3{~read_fromFIFO[256]}} & Vw0},{{3{~read_fromFIFO[255]}} & Vw0},{{3{~read_fromFIFO[254]}} & Vw0},{{3{~read_fromFIFO[253]}} & Vw0},{{3{~read_fromFIFO[252]}} & Vw0},{{3{~read_fromFIFO[251]}} & Vw0},{{3{~read_fromFIFO[250]}} & Vw0}                
			,{{3{~read_fromFIFO[249]}} & Vw0},{{3{~read_fromFIFO[248]}} & Vw0},{{3{~read_fromFIFO[247]}} & Vw0},{{3{~read_fromFIFO[246]}} & Vw0},{{3{~read_fromFIFO[245]}} & Vw0},{{3{~read_fromFIFO[244]}} & Vw0},{{3{~read_fromFIFO[243]}} & Vw0},{{3{~read_fromFIFO[242]}} & Vw0},{{3{~read_fromFIFO[241]}} & Vw0},{{3{~read_fromFIFO[240]}} & Vw0}
			,{{3{~read_fromFIFO[239]}} & Vw0},{{3{~read_fromFIFO[238]}} & Vw0},{{3{~read_fromFIFO[237]}} & Vw0},{{3{~read_fromFIFO[236]}} & Vw0},{{3{~read_fromFIFO[235]}} & Vw0},{{3{~read_fromFIFO[234]}} & Vw0},{{3{~read_fromFIFO[233]}} & Vw0},{{3{~read_fromFIFO[232]}} & Vw0},{{3{~read_fromFIFO[231]}} & Vw0},{{3{~read_fromFIFO[230]}} & Vw0}
			,{{3{~read_fromFIFO[229]}} & Vw0},{{3{~read_fromFIFO[228]}} & Vw0},{{3{~read_fromFIFO[227]}} & Vw0},{{3{~read_fromFIFO[226]}} & Vw0},{{3{~read_fromFIFO[225]}} & Vw0},{{3{~read_fromFIFO[224]}} & Vw0},{{3{~read_fromFIFO[223]}} & Vw0},{{3{~read_fromFIFO[222]}} & Vw0},{{3{~read_fromFIFO[221]}} & Vw0},{{3{~read_fromFIFO[220]}} & Vw0}
			,{{3{~read_fromFIFO[219]}} & Vw0},{{3{~read_fromFIFO[218]}} & Vw0},{{3{~read_fromFIFO[217]}} & Vw0},{{3{~read_fromFIFO[216]}} & Vw0},{{3{~read_fromFIFO[215]}} & Vw0},{{3{~read_fromFIFO[214]}} & Vw0},{{3{~read_fromFIFO[213]}} & Vw0},{{3{~read_fromFIFO[212]}} & Vw0},{{3{~read_fromFIFO[211]}} & Vw0},{{3{~read_fromFIFO[210]}} & Vw0}
			,{{3{~read_fromFIFO[209]}} & Vw0},{{3{~read_fromFIFO[208]}} & Vw0},{{3{~read_fromFIFO[207]}} & Vw0},{{3{~read_fromFIFO[206]}} & Vw0},{{3{~read_fromFIFO[205]}} & Vw0},{{3{~read_fromFIFO[204]}} & Vw0},{{3{~read_fromFIFO[203]}} & Vw0},{{3{~read_fromFIFO[202]}} & Vw0},{{3{~read_fromFIFO[201]}} & Vw0},{{3{~read_fromFIFO[200]}} & Vw0}
			,{{3{~read_fromFIFO[199]}} & Vw0},{{3{~read_fromFIFO[198]}} & Vw0},{{3{~read_fromFIFO[197]}} & Vw0},{{3{~read_fromFIFO[196]}} & Vw0},{{3{~read_fromFIFO[195]}} & Vw0},{{3{~read_fromFIFO[194]}} & Vw0},{{3{~read_fromFIFO[193]}} & Vw0},{{3{~read_fromFIFO[192]}} & Vw0},{{3{~read_fromFIFO[191]}} & Vw0},{{3{~read_fromFIFO[190]}} & Vw0}
			,{{3{~read_fromFIFO[189]}} & Vw0},{{3{~read_fromFIFO[188]}} & Vw0},{{3{~read_fromFIFO[187]}} & Vw0},{{3{~read_fromFIFO[186]}} & Vw0},{{3{~read_fromFIFO[185]}} & Vw0},{{3{~read_fromFIFO[184]}} & Vw0},{{3{~read_fromFIFO[183]}} & Vw0},{{3{~read_fromFIFO[182]}} & Vw0},{{3{~read_fromFIFO[181]}} & Vw0},{{3{~read_fromFIFO[180]}} & Vw0}
			,{{3{~read_fromFIFO[179]}} & Vw0},{{3{~read_fromFIFO[178]}} & Vw0},{{3{~read_fromFIFO[177]}} & Vw0},{{3{~read_fromFIFO[176]}} & Vw0},{{3{~read_fromFIFO[175]}} & Vw0},{{3{~read_fromFIFO[174]}} & Vw0},{{3{~read_fromFIFO[173]}} & Vw0},{{3{~read_fromFIFO[172]}} & Vw0},{{3{~read_fromFIFO[171]}} & Vw0},{{3{~read_fromFIFO[170]}} & Vw0}                 
			,{{3{~read_fromFIFO[169]}} & Vw0},{{3{~read_fromFIFO[168]}} & Vw0},{{3{~read_fromFIFO[167]}} & Vw0},{{3{~read_fromFIFO[166]}} & Vw0},{{3{~read_fromFIFO[165]}} & Vw0},{{3{~read_fromFIFO[164]}} & Vw0},{{3{~read_fromFIFO[163]}} & Vw0},{{3{~read_fromFIFO[162]}} & Vw0},{{3{~read_fromFIFO[161]}} & Vw0},{{3{~read_fromFIFO[160]}} & Vw0}
			,{{3{~read_fromFIFO[159]}} & Vw0},{{3{~read_fromFIFO[158]}} & Vw0},{{3{~read_fromFIFO[157]}} & Vw0},{{3{~read_fromFIFO[156]}} & Vw0},{{3{~read_fromFIFO[155]}} & Vw0},{{3{~read_fromFIFO[154]}} & Vw0},{{3{~read_fromFIFO[153]}} & Vw0},{{3{~read_fromFIFO[152]}} & Vw0},{{3{~read_fromFIFO[151]}} & Vw0},{{3{~read_fromFIFO[150]}} & Vw0}
			,{{3{~read_fromFIFO[149]}} & Vw0},{{3{~read_fromFIFO[148]}} & Vw0},{{3{~read_fromFIFO[147]}} & Vw0},{{3{~read_fromFIFO[146]}} & Vw0},{{3{~read_fromFIFO[145]}} & Vw0},{{3{~read_fromFIFO[144]}} & Vw0},{{3{~read_fromFIFO[143]}} & Vw0},{{3{~read_fromFIFO[142]}} & Vw0},{{3{~read_fromFIFO[141]}} & Vw0},{{3{~read_fromFIFO[140]}} & Vw0}
			,{{3{~read_fromFIFO[139]}} & Vw0},{{3{~read_fromFIFO[138]}} & Vw0},{{3{~read_fromFIFO[137]}} & Vw0},{{3{~read_fromFIFO[136]}} & Vw0},{{3{~read_fromFIFO[135]}} & Vw0},{{3{~read_fromFIFO[134]}} & Vw0},{{3{~read_fromFIFO[133]}} & Vw0},{{3{~read_fromFIFO[132]}} & Vw0},{{3{~read_fromFIFO[131]}} & Vw0},{{3{~read_fromFIFO[130]}} & Vw0}
			,{{3{~read_fromFIFO[129]}} & Vw0},{{3{~read_fromFIFO[128]}} & Vw0},{{3{~read_fromFIFO[127]}} & Vw0},{{3{~read_fromFIFO[126]}} & Vw0},{{3{~read_fromFIFO[125]}} & Vw0},{{3{~read_fromFIFO[124]}} & Vw0},{{3{~read_fromFIFO[123]}} & Vw0},{{3{~read_fromFIFO[122]}} & Vw0},{{3{~read_fromFIFO[121]}} & Vw0},{{3{~read_fromFIFO[120]}} & Vw0}
			,{{3{~read_fromFIFO[119]}} & Vw0},{{3{~read_fromFIFO[118]}} & Vw0},{{3{~read_fromFIFO[117]}} & Vw0},{{3{~read_fromFIFO[116]}} & Vw0},{{3{~read_fromFIFO[115]}} & Vw0},{{3{~read_fromFIFO[114]}} & Vw0},{{3{~read_fromFIFO[113]}} & Vw0},{{3{~read_fromFIFO[112]}} & Vw0},{{3{~read_fromFIFO[111]}} & Vw0},{{3{~read_fromFIFO[110]}} & Vw0}
			,{{3{~read_fromFIFO[109]}} & Vw0},{{3{~read_fromFIFO[108]}} & Vw0},{{3{~read_fromFIFO[107]}} & Vw0},{{3{~read_fromFIFO[106]}} & Vw0},{{3{~read_fromFIFO[105]}} & Vw0},{{3{~read_fromFIFO[104]}} & Vw0},{{3{~read_fromFIFO[103]}} & Vw0},{{3{~read_fromFIFO[102]}} & Vw0},{{3{~read_fromFIFO[101]}} & Vw0},{{3{~read_fromFIFO[100]}} & Vw0}
			,{{3{~read_fromFIFO[99]}} & Vw0},{{3{~read_fromFIFO[98]}} & Vw0},{{3{~read_fromFIFO[97]}} & Vw0},{{3{~read_fromFIFO[96]}} & Vw0},{{3{~read_fromFIFO[95]}} & Vw0},{{3{~read_fromFIFO[94]}} & Vw0},{{3{~read_fromFIFO[93]}} & Vw0},{{3{~read_fromFIFO[92]}} & Vw0},{{3{~read_fromFIFO[91]}} & Vw0},{{3{~read_fromFIFO[90]}} & Vw0}
			,{{3{~read_fromFIFO[89]}} & Vw0},{{3{~read_fromFIFO[88]}} & Vw0},{{3{~read_fromFIFO[87]}} & Vw0},{{3{~read_fromFIFO[86]}} & Vw0},{{3{~read_fromFIFO[85]}} & Vw0},{{3{~read_fromFIFO[84]}} & Vw0},{{3{~read_fromFIFO[83]}} & Vw0},{{3{~read_fromFIFO[82]}} & Vw0},{{3{~read_fromFIFO[81]}} & Vw0},{{3{~read_fromFIFO[80]}} & Vw0}
			,{{3{~read_fromFIFO[79]}} & Vw0},{{3{~read_fromFIFO[78]}} & Vw0},{{3{~read_fromFIFO[77]}} & Vw0},{{3{~read_fromFIFO[76]}} & Vw0},{{3{~read_fromFIFO[75]}} & Vw0},{{3{~read_fromFIFO[74]}} & Vw0},{{3{~read_fromFIFO[73]}} & Vw0},{{3{~read_fromFIFO[72]}} & Vw0},{{3{~read_fromFIFO[71]}} & Vw0},{{3{~read_fromFIFO[70]}} & Vw0}
			,{{3{~read_fromFIFO[69]}} & Vw0},{{3{~read_fromFIFO[68]}} & Vw0},{{3{~read_fromFIFO[67]}} & Vw0},{{3{~read_fromFIFO[66]}} & Vw0},{{3{~read_fromFIFO[65]}} & Vw0},{{3{~read_fromFIFO[64]}} & Vw0},{{3{~read_fromFIFO[63]}} & Vw0},{{3{~read_fromFIFO[62]}} & Vw0},{{3{~read_fromFIFO[61]}} & Vw0},{{3{~read_fromFIFO[60]}} & Vw0}
			,{{3{~read_fromFIFO[59]}} & Vw0},{{3{~read_fromFIFO[58]}} & Vw0},{{3{~read_fromFIFO[57]}} & Vw0},{{3{~read_fromFIFO[56]}} & Vw0},{{3{~read_fromFIFO[55]}} & Vw0},{{3{~read_fromFIFO[54]}} & Vw0},{{3{~read_fromFIFO[53]}} & Vw0},{{3{~read_fromFIFO[52]}} & Vw0},{{3{~read_fromFIFO[51]}} & Vw0},{{3{~read_fromFIFO[50]}} & Vw0}
			,{{3{~read_fromFIFO[49]}} & Vw0},{{3{~read_fromFIFO[48]}} & Vw0},{{3{~read_fromFIFO[47]}} & Vw0},{{3{~read_fromFIFO[46]}} & Vw0},{{3{~read_fromFIFO[45]}} & Vw0},{{3{~read_fromFIFO[44]}} & Vw0},{{3{~read_fromFIFO[43]}} & Vw0},{{3{~read_fromFIFO[42]}} & Vw0},{{3{~read_fromFIFO[41]}} & Vw0},{{3{~read_fromFIFO[40]}} & Vw0}
			,{{3{~read_fromFIFO[39]}} & Vw0},{{3{~read_fromFIFO[38]}} & Vw0},{{3{~read_fromFIFO[37]}} & Vw0},{{3{~read_fromFIFO[36]}} & Vw0},{{3{~read_fromFIFO[35]}} & Vw0},{{3{~read_fromFIFO[34]}} & Vw0},{{3{~read_fromFIFO[33]}} & Vw0},{{3{~read_fromFIFO[32]}} & Vw0},{{3{~read_fromFIFO[31]}} & Vw0},{{3{~read_fromFIFO[30]}} & Vw0}
			,{{3{~read_fromFIFO[29]}} & Vw0},{{3{~read_fromFIFO[28]}} & Vw0},{{3{~read_fromFIFO[27]}} & Vw0},{{3{~read_fromFIFO[26]}} & Vw0},{{3{~read_fromFIFO[25]}} & Vw0},{{3{~read_fromFIFO[24]}} & Vw0},{{3{~read_fromFIFO[23]}} & Vw0},{{3{~read_fromFIFO[22]}} & Vw0},{{3{~read_fromFIFO[21]}} & Vw0},{{3{~read_fromFIFO[20]}} & Vw0}
			,{{3{~read_fromFIFO[19]}} & Vw0},{{3{~read_fromFIFO[18]}} & Vw0},{{3{~read_fromFIFO[17]}} & Vw0},{{3{~read_fromFIFO[16]}} & Vw0},{{3{~read_fromFIFO[15]}} & Vw0},{{3{~read_fromFIFO[14]}} & Vw0},{{3{~read_fromFIFO[13]}} & Vw0},{{3{~read_fromFIFO[12]}} & Vw0},{{3{~read_fromFIFO[11]}} & Vw0},{{3{~read_fromFIFO[10]}} & Vw0}
			,{{3{~read_fromFIFO[9]}} & Vw0},{{3{~read_fromFIFO[8]}} & Vw0},{{3{~read_fromFIFO[7]}} & Vw0},{{3{~read_fromFIFO[6]}} & Vw0},{{3{~read_fromFIFO[5]}} & Vw0},{{3{~read_fromFIFO[4]}} & Vw0},{{3{~read_fromFIFO[3]}} & Vw0},{{3{~read_fromFIFO[2]}} & Vw0},{{3{~read_fromFIFO[1]}} & Vw0},{{3{~read_fromFIFO[0]}} & Vw0}
			,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0 };

	row_selector <= {{59{Vground}}, {5{Vfloating}}}; 
	//row_selector <= {{(num_of_rows_in_crossbar - (end_row_FIFO - start_row_FIFO)){Vground}}, {(end_row_FIFO - start_row_FIFO){Vfloating}}}; 

	col_selector <= {{600{Vfloating}}, (ones_positions[935:36] | zeros_positions[935:36]), {124{Vfloating}}}; // 10'b1110000100 = 900
	//col_selector <= {{(num_of_bits_in_ref){Vfloating}}, (ones_positions[935:36] | zeros_positions[935:36]), {(num_of_cols_in_crossbar - num_of_bits_in_ref - num_of_bits_in_read + num_of_bits_of_index_read){Vfloating}}}; // 10'b1110000100 = 900

end	







if (flag_relevent_read == 1'b1) begin // accepting reads and writing to FIFO
	flag_done <= 1'b1;
	ones_positions <= {
		{{3{current_read[311]}} & Vw1},{{3{current_read[310]}} & Vw1},{{3{current_read[309]}} & Vw1},{{3{current_read[308]}} & Vw1},{{3{current_read[307]}} & Vw1},{{3{current_read[306]}} & Vw1},{{3{current_read[305]}} & Vw1},{{3{current_read[304]}} & Vw1},{{3{current_read[303]}} & Vw1},{{3{current_read[302]}} & Vw1},{{3{current_read[301]}} & Vw1},{{3{current_read[300]}} & Vw1}
		,{{3{current_read[299]}} & Vw1},{{3{current_read[298]}} & Vw1},{{3{current_read[297]}} & Vw1},{{3{current_read[296]}} & Vw1},{{3{current_read[295]}} & Vw1},{{3{current_read[294]}} & Vw1},{{3{current_read[293]}} & Vw1},{{3{current_read[292]}} & Vw1},{{3{current_read[291]}} & Vw1},{{3{current_read[290]}} & Vw1}
		,{{3{current_read[289]}} & Vw1},{{3{current_read[288]}} & Vw1},{{3{current_read[287]}} & Vw1},{{3{current_read[286]}} & Vw1},{{3{current_read[285]}} & Vw1},{{3{current_read[284]}} & Vw1},{{3{current_read[283]}} & Vw1},{{3{current_read[282]}} & Vw1},{{3{current_read[281]}} & Vw1},{{3{current_read[280]}} & Vw1}
		,{{3{current_read[279]}} & Vw1},{{3{current_read[278]}} & Vw1},{{3{current_read[277]}} & Vw1},{{3{current_read[276]}} & Vw1},{{3{current_read[275]}} & Vw1},{{3{current_read[274]}} & Vw1},{{3{current_read[273]}} & Vw1},{{3{current_read[272]}} & Vw1},{{3{current_read[271]}} & Vw1},{{3{current_read[270]}} & Vw1}
		,{{3{current_read[269]}} & Vw1},{{3{current_read[268]}} & Vw1},{{3{current_read[267]}} & Vw1},{{3{current_read[266]}} & Vw1},{{3{current_read[265]}} & Vw1},{{3{current_read[264]}} & Vw1},{{3{current_read[263]}} & Vw1},{{3{current_read[262]}} & Vw1},{{3{current_read[261]}} & Vw1},{{3{current_read[260]}} & Vw1}
		,{{3{current_read[259]}} & Vw1},{{3{current_read[258]}} & Vw1},{{3{current_read[257]}} & Vw1},{{3{current_read[256]}} & Vw1},{{3{current_read[255]}} & Vw1},{{3{current_read[254]}} & Vw1},{{3{current_read[253]}} & Vw1},{{3{current_read[252]}} & Vw1},{{3{current_read[251]}} & Vw1},{{3{current_read[250]}} & Vw1}
		,{{3{current_read[249]}} & Vw1},{{3{current_read[248]}} & Vw1},{{3{current_read[247]}} & Vw1},{{3{current_read[246]}} & Vw1},{{3{current_read[245]}} & Vw1},{{3{current_read[244]}} & Vw1},{{3{current_read[243]}} & Vw1},{{3{current_read[242]}} & Vw1},{{3{current_read[241]}} & Vw1},{{3{current_read[240]}} & Vw1}
		,{{3{current_read[239]}} & Vw1},{{3{current_read[238]}} & Vw1},{{3{current_read[237]}} & Vw1},{{3{current_read[236]}} & Vw1},{{3{current_read[235]}} & Vw1},{{3{current_read[234]}} & Vw1},{{3{current_read[233]}} & Vw1},{{3{current_read[232]}} & Vw1},{{3{current_read[231]}} & Vw1},{{3{current_read[230]}} & Vw1}
		,{{3{current_read[229]}} & Vw1},{{3{current_read[228]}} & Vw1},{{3{current_read[227]}} & Vw1},{{3{current_read[226]}} & Vw1},{{3{current_read[225]}} & Vw1},{{3{current_read[224]}} & Vw1},{{3{current_read[223]}} & Vw1},{{3{current_read[222]}} & Vw1},{{3{current_read[221]}} & Vw1},{{3{current_read[220]}} & Vw1}
		,{{3{current_read[219]}} & Vw1},{{3{current_read[218]}} & Vw1},{{3{current_read[217]}} & Vw1},{{3{current_read[216]}} & Vw1},{{3{current_read[215]}} & Vw1},{{3{current_read[214]}} & Vw1},{{3{current_read[213]}} & Vw1},{{3{current_read[212]}} & Vw1},{{3{current_read[211]}} & Vw1},{{3{current_read[210]}} & Vw1}
		,{{3{current_read[209]}} & Vw1},{{3{current_read[208]}} & Vw1},{{3{current_read[207]}} & Vw1},{{3{current_read[206]}} & Vw1},{{3{current_read[205]}} & Vw1},{{3{current_read[204]}} & Vw1},{{3{current_read[203]}} & Vw1},{{3{current_read[202]}} & Vw1},{{3{current_read[201]}} & Vw1},{{3{current_read[200]}} & Vw1}
		,{{3{current_read[199]}} & Vw1},{{3{current_read[198]}} & Vw1},{{3{current_read[197]}} & Vw1},{{3{current_read[196]}} & Vw1},{{3{current_read[195]}} & Vw1},{{3{current_read[194]}} & Vw1},{{3{current_read[193]}} & Vw1},{{3{current_read[192]}} & Vw1},{{3{current_read[191]}} & Vw1},{{3{current_read[190]}} & Vw1}
		,{{3{current_read[189]}} & Vw1},{{3{current_read[188]}} & Vw1},{{3{current_read[187]}} & Vw1},{{3{current_read[186]}} & Vw1},{{3{current_read[185]}} & Vw1},{{3{current_read[184]}} & Vw1},{{3{current_read[183]}} & Vw1},{{3{current_read[182]}} & Vw1},{{3{current_read[181]}} & Vw1},{{3{current_read[180]}} & Vw1}
		,{{3{current_read[179]}} & Vw1},{{3{current_read[178]}} & Vw1},{{3{current_read[177]}} & Vw1},{{3{current_read[176]}} & Vw1},{{3{current_read[175]}} & Vw1},{{3{current_read[174]}} & Vw1},{{3{current_read[173]}} & Vw1},{{3{current_read[172]}} & Vw1},{{3{current_read[171]}} & Vw1},{{3{current_read[170]}} & Vw1}
		,{{3{current_read[169]}} & Vw1},{{3{current_read[168]}} & Vw1},{{3{current_read[167]}} & Vw1},{{3{current_read[166]}} & Vw1},{{3{current_read[165]}} & Vw1},{{3{current_read[164]}} & Vw1},{{3{current_read[163]}} & Vw1},{{3{current_read[162]}} & Vw1},{{3{current_read[161]}} & Vw1},{{3{current_read[160]}} & Vw1}
		,{{3{current_read[159]}} & Vw1},{{3{current_read[158]}} & Vw1},{{3{current_read[157]}} & Vw1},{{3{current_read[156]}} & Vw1},{{3{current_read[155]}} & Vw1},{{3{current_read[154]}} & Vw1},{{3{current_read[153]}} & Vw1},{{3{current_read[152]}} & Vw1},{{3{current_read[151]}} & Vw1},{{3{current_read[150]}} & Vw1}
		,{{3{current_read[149]}} & Vw1},{{3{current_read[148]}} & Vw1},{{3{current_read[147]}} & Vw1},{{3{current_read[146]}} & Vw1},{{3{current_read[145]}} & Vw1},{{3{current_read[144]}} & Vw1},{{3{current_read[143]}} & Vw1},{{3{current_read[142]}} & Vw1},{{3{current_read[141]}} & Vw1},{{3{current_read[140]}} & Vw1}
		,{{3{current_read[139]}} & Vw1},{{3{current_read[138]}} & Vw1},{{3{current_read[137]}} & Vw1},{{3{current_read[136]}} & Vw1},{{3{current_read[135]}} & Vw1},{{3{current_read[134]}} & Vw1},{{3{current_read[133]}} & Vw1},{{3{current_read[132]}} & Vw1},{{3{current_read[131]}} & Vw1},{{3{current_read[130]}} & Vw1}
		,{{3{current_read[129]}} & Vw1},{{3{current_read[128]}} & Vw1},{{3{current_read[127]}} & Vw1},{{3{current_read[126]}} & Vw1},{{3{current_read[125]}} & Vw1},{{3{current_read[124]}} & Vw1},{{3{current_read[123]}} & Vw1},{{3{current_read[122]}} & Vw1},{{3{current_read[121]}} & Vw1},{{3{current_read[120]}} & Vw1}
		,{{3{current_read[119]}} & Vw1},{{3{current_read[118]}} & Vw1},{{3{current_read[117]}} & Vw1},{{3{current_read[116]}} & Vw1},{{3{current_read[115]}} & Vw1},{{3{current_read[114]}} & Vw1},{{3{current_read[113]}} & Vw1},{{3{current_read[112]}} & Vw1},{{3{current_read[111]}} & Vw1},{{3{current_read[110]}} & Vw1}
		,{{3{current_read[109]}} & Vw1},{{3{current_read[108]}} & Vw1},{{3{current_read[107]}} & Vw1},{{3{current_read[106]}} & Vw1},{{3{current_read[105]}} & Vw1},{{3{current_read[104]}} & Vw1},{{3{current_read[103]}} & Vw1},{{3{current_read[102]}} & Vw1},{{3{current_read[101]}} & Vw1},{{3{current_read[100]}} & Vw1}
		,{{3{current_read[99]}} & Vw1},{{3{current_read[98]}} & Vw1},{{3{current_read[97]}} & Vw1},{{3{current_read[96]}} & Vw1},{{3{current_read[95]}} & Vw1},{{3{current_read[94]}} & Vw1},{{3{current_read[93]}} & Vw1},{{3{current_read[92]}} & Vw1},{{3{current_read[91]}} & Vw1},{{3{current_read[90]}} & Vw1}               
		,{{3{current_read[89]}} & Vw1},{{3{current_read[88]}} & Vw1},{{3{current_read[87]}} & Vw1},{{3{current_read[86]}} & Vw1},{{3{current_read[85]}} & Vw1},{{3{current_read[84]}} & Vw1},{{3{current_read[83]}} & Vw1},{{3{current_read[82]}} & Vw1},{{3{current_read[81]}} & Vw1},{{3{current_read[80]}} & Vw1}
		,{{3{current_read[79]}} & Vw1},{{3{current_read[78]}} & Vw1},{{3{current_read[77]}} & Vw1},{{3{current_read[76]}} & Vw1},{{3{current_read[75]}} & Vw1},{{3{current_read[74]}} & Vw1},{{3{current_read[73]}} & Vw1},{{3{current_read[72]}} & Vw1},{{3{current_read[71]}} & Vw1},{{3{current_read[70]}} & Vw1}
		,{{3{current_read[69]}} & Vw1},{{3{current_read[68]}} & Vw1},{{3{current_read[67]}} & Vw1},{{3{current_read[66]}} & Vw1},{{3{current_read[65]}} & Vw1},{{3{current_read[64]}} & Vw1},{{3{current_read[63]}} & Vw1},{{3{current_read[62]}} & Vw1},{{3{current_read[61]}} & Vw1},{{3{current_read[60]}} & Vw1}
		,{{3{current_read[59]}} & Vw1},{{3{current_read[58]}} & Vw1},{{3{current_read[57]}} & Vw1},{{3{current_read[56]}} & Vw1},{{3{current_read[55]}} & Vw1},{{3{current_read[54]}} & Vw1},{{3{current_read[53]}} & Vw1},{{3{current_read[52]}} & Vw1},{{3{current_read[51]}} & Vw1},{{3{current_read[50]}} & Vw1}
		,{{3{current_read[49]}} & Vw1},{{3{current_read[48]}} & Vw1},{{3{current_read[47]}} & Vw1},{{3{current_read[46]}} & Vw1},{{3{current_read[45]}} & Vw1},{{3{current_read[44]}} & Vw1},{{3{current_read[43]}} & Vw1},{{3{current_read[42]}} & Vw1},{{3{current_read[41]}} & Vw1},{{3{current_read[40]}} & Vw1}
		,{{3{current_read[39]}} & Vw1},{{3{current_read[38]}} & Vw1},{{3{current_read[37]}} & Vw1},{{3{current_read[36]}} & Vw1},{{3{current_read[35]}} & Vw1},{{3{current_read[34]}} & Vw1},{{3{current_read[33]}} & Vw1},{{3{current_read[32]}} & Vw1},{{3{current_read[31]}} & Vw1},{{3{current_read[30]}} & Vw1}
		,{{3{current_read[29]}} & Vw1},{{3{current_read[28]}} & Vw1},{{3{current_read[27]}} & Vw1},{{3{current_read[26]}} & Vw1},{{3{current_read[25]}} & Vw1},{{3{current_read[24]}} & Vw1},{{3{current_read[23]}} & Vw1},{{3{current_read[22]}} & Vw1},{{3{current_read[21]}} & Vw1},{{3{current_read[20]}} & Vw1}
		,{{3{current_read[19]}} & Vw1},{{3{current_read[18]}} & Vw1},{{3{current_read[17]}} & Vw1},{{3{current_read[16]}} & Vw1},{{3{current_read[15]}} & Vw1},{{3{current_read[14]}} & Vw1},{{3{current_read[13]}} & Vw1},{{3{current_read[12]}} & Vw1},{{3{current_read[11]}} & Vw1},{{3{current_read[10]}} & Vw1}
		,{{3{current_read[9]}} & Vw1},{{3{current_read[8]}} & Vw1},{{3{current_read[7]}} & Vw1},{{3{current_read[6]}} & Vw1},{{3{current_read[5]}} & Vw1},{{3{current_read[4]}} & Vw1},{{3{current_read[3]}} & Vw1},{{3{current_read[2]}} & Vw1},{{3{current_read[1]}} & Vw1},{{3{current_read[0]}} & Vw1} };
	

	zeros_positions <= {
			 {{3{~current_read[311]}} & Vw0},{{3{~current_read[310]}} & Vw0},{{3{~current_read[309]}} & Vw0},{{3{~current_read[308]}} & Vw0},{{3{~current_read[307]}} & Vw0},{{3{~current_read[306]}} & Vw0},{{3{~current_read[305]}} & Vw0},{{3{~current_read[304]}} & Vw0},{{3{~current_read[303]}} & Vw0},{{3{~current_read[302]}} & Vw0},{{3{~current_read[301]}} & Vw0},{{3{~current_read[300]}} & Vw0}
			,{{3{~current_read[299]}} & Vw0},{{3{~current_read[298]}} & Vw0},{{3{~current_read[297]}} & Vw0},{{3{~current_read[296]}} & Vw0},{{3{~current_read[295]}} & Vw0},{{3{~current_read[294]}} & Vw0},{{3{~current_read[293]}} & Vw0},{{3{~current_read[292]}} & Vw0},{{3{~current_read[291]}} & Vw0},{{3{~current_read[290]}} & Vw0}
			,{{3{~current_read[289]}} & Vw0},{{3{~current_read[288]}} & Vw0},{{3{~current_read[287]}} & Vw0},{{3{~current_read[286]}} & Vw0},{{3{~current_read[285]}} & Vw0},{{3{~current_read[284]}} & Vw0},{{3{~current_read[283]}} & Vw0},{{3{~current_read[282]}} & Vw0},{{3{~current_read[281]}} & Vw0},{{3{~current_read[280]}} & Vw0}
			,{{3{~current_read[279]}} & Vw0},{{3{~current_read[278]}} & Vw0},{{3{~current_read[277]}} & Vw0},{{3{~current_read[276]}} & Vw0},{{3{~current_read[275]}} & Vw0},{{3{~current_read[274]}} & Vw0},{{3{~current_read[273]}} & Vw0},{{3{~current_read[272]}} & Vw0},{{3{~current_read[271]}} & Vw0},{{3{~current_read[270]}} & Vw0}
			,{{3{~current_read[269]}} & Vw0},{{3{~current_read[268]}} & Vw0},{{3{~current_read[267]}} & Vw0},{{3{~current_read[266]}} & Vw0},{{3{~current_read[265]}} & Vw0},{{3{~current_read[264]}} & Vw0},{{3{~current_read[263]}} & Vw0},{{3{~current_read[262]}} & Vw0},{{3{~current_read[261]}} & Vw0},{{3{~current_read[260]}} & Vw0}
			,{{3{~current_read[259]}} & Vw0},{{3{~current_read[258]}} & Vw0},{{3{~current_read[257]}} & Vw0},{{3{~current_read[256]}} & Vw0},{{3{~current_read[255]}} & Vw0},{{3{~current_read[254]}} & Vw0},{{3{~current_read[253]}} & Vw0},{{3{~current_read[252]}} & Vw0},{{3{~current_read[251]}} & Vw0},{{3{~current_read[250]}} & Vw0}                
			,{{3{~current_read[249]}} & Vw0},{{3{~current_read[248]}} & Vw0},{{3{~current_read[247]}} & Vw0},{{3{~current_read[246]}} & Vw0},{{3{~current_read[245]}} & Vw0},{{3{~current_read[244]}} & Vw0},{{3{~current_read[243]}} & Vw0},{{3{~current_read[242]}} & Vw0},{{3{~current_read[241]}} & Vw0},{{3{~current_read[240]}} & Vw0}
			,{{3{~current_read[239]}} & Vw0},{{3{~current_read[238]}} & Vw0},{{3{~current_read[237]}} & Vw0},{{3{~current_read[236]}} & Vw0},{{3{~current_read[235]}} & Vw0},{{3{~current_read[234]}} & Vw0},{{3{~current_read[233]}} & Vw0},{{3{~current_read[232]}} & Vw0},{{3{~current_read[231]}} & Vw0},{{3{~current_read[230]}} & Vw0}
			,{{3{~current_read[229]}} & Vw0},{{3{~current_read[228]}} & Vw0},{{3{~current_read[227]}} & Vw0},{{3{~current_read[226]}} & Vw0},{{3{~current_read[225]}} & Vw0},{{3{~current_read[224]}} & Vw0},{{3{~current_read[223]}} & Vw0},{{3{~current_read[222]}} & Vw0},{{3{~current_read[221]}} & Vw0},{{3{~current_read[220]}} & Vw0}
			,{{3{~current_read[219]}} & Vw0},{{3{~current_read[218]}} & Vw0},{{3{~current_read[217]}} & Vw0},{{3{~current_read[216]}} & Vw0},{{3{~current_read[215]}} & Vw0},{{3{~current_read[214]}} & Vw0},{{3{~current_read[213]}} & Vw0},{{3{~current_read[212]}} & Vw0},{{3{~current_read[211]}} & Vw0},{{3{~current_read[210]}} & Vw0}
			,{{3{~current_read[209]}} & Vw0},{{3{~current_read[208]}} & Vw0},{{3{~current_read[207]}} & Vw0},{{3{~current_read[206]}} & Vw0},{{3{~current_read[205]}} & Vw0},{{3{~current_read[204]}} & Vw0},{{3{~current_read[203]}} & Vw0},{{3{~current_read[202]}} & Vw0},{{3{~current_read[201]}} & Vw0},{{3{~current_read[200]}} & Vw0}
			,{{3{~current_read[199]}} & Vw0},{{3{~current_read[198]}} & Vw0},{{3{~current_read[197]}} & Vw0},{{3{~current_read[196]}} & Vw0},{{3{~current_read[195]}} & Vw0},{{3{~current_read[194]}} & Vw0},{{3{~current_read[193]}} & Vw0},{{3{~current_read[192]}} & Vw0},{{3{~current_read[191]}} & Vw0},{{3{~current_read[190]}} & Vw0}
			,{{3{~current_read[189]}} & Vw0},{{3{~current_read[188]}} & Vw0},{{3{~current_read[187]}} & Vw0},{{3{~current_read[186]}} & Vw0},{{3{~current_read[185]}} & Vw0},{{3{~current_read[184]}} & Vw0},{{3{~current_read[183]}} & Vw0},{{3{~current_read[182]}} & Vw0},{{3{~current_read[181]}} & Vw0},{{3{~current_read[180]}} & Vw0}
			,{{3{~current_read[179]}} & Vw0},{{3{~current_read[178]}} & Vw0},{{3{~current_read[177]}} & Vw0},{{3{~current_read[176]}} & Vw0},{{3{~current_read[175]}} & Vw0},{{3{~current_read[174]}} & Vw0},{{3{~current_read[173]}} & Vw0},{{3{~current_read[172]}} & Vw0},{{3{~current_read[171]}} & Vw0},{{3{~current_read[170]}} & Vw0}                 
			,{{3{~current_read[169]}} & Vw0},{{3{~current_read[168]}} & Vw0},{{3{~current_read[167]}} & Vw0},{{3{~current_read[166]}} & Vw0},{{3{~current_read[165]}} & Vw0},{{3{~current_read[164]}} & Vw0},{{3{~current_read[163]}} & Vw0},{{3{~current_read[162]}} & Vw0},{{3{~current_read[161]}} & Vw0},{{3{~current_read[160]}} & Vw0}
			,{{3{~current_read[159]}} & Vw0},{{3{~current_read[158]}} & Vw0},{{3{~current_read[157]}} & Vw0},{{3{~current_read[156]}} & Vw0},{{3{~current_read[155]}} & Vw0},{{3{~current_read[154]}} & Vw0},{{3{~current_read[153]}} & Vw0},{{3{~current_read[152]}} & Vw0},{{3{~current_read[151]}} & Vw0},{{3{~current_read[150]}} & Vw0}
			,{{3{~current_read[149]}} & Vw0},{{3{~current_read[148]}} & Vw0},{{3{~current_read[147]}} & Vw0},{{3{~current_read[146]}} & Vw0},{{3{~current_read[145]}} & Vw0},{{3{~current_read[144]}} & Vw0},{{3{~current_read[143]}} & Vw0},{{3{~current_read[142]}} & Vw0},{{3{~current_read[141]}} & Vw0},{{3{~current_read[140]}} & Vw0}
			,{{3{~current_read[139]}} & Vw0},{{3{~current_read[138]}} & Vw0},{{3{~current_read[137]}} & Vw0},{{3{~current_read[136]}} & Vw0},{{3{~current_read[135]}} & Vw0},{{3{~current_read[134]}} & Vw0},{{3{~current_read[133]}} & Vw0},{{3{~current_read[132]}} & Vw0},{{3{~current_read[131]}} & Vw0},{{3{~current_read[130]}} & Vw0}
			,{{3{~current_read[129]}} & Vw0},{{3{~current_read[128]}} & Vw0},{{3{~current_read[127]}} & Vw0},{{3{~current_read[126]}} & Vw0},{{3{~current_read[125]}} & Vw0},{{3{~current_read[124]}} & Vw0},{{3{~current_read[123]}} & Vw0},{{3{~current_read[122]}} & Vw0},{{3{~current_read[121]}} & Vw0},{{3{~current_read[120]}} & Vw0}
			,{{3{~current_read[119]}} & Vw0},{{3{~current_read[118]}} & Vw0},{{3{~current_read[117]}} & Vw0},{{3{~current_read[116]}} & Vw0},{{3{~current_read[115]}} & Vw0},{{3{~current_read[114]}} & Vw0},{{3{~current_read[113]}} & Vw0},{{3{~current_read[112]}} & Vw0},{{3{~current_read[111]}} & Vw0},{{3{~current_read[110]}} & Vw0}
			,{{3{~current_read[109]}} & Vw0},{{3{~current_read[108]}} & Vw0},{{3{~current_read[107]}} & Vw0},{{3{~current_read[106]}} & Vw0},{{3{~current_read[105]}} & Vw0},{{3{~current_read[104]}} & Vw0},{{3{~current_read[103]}} & Vw0},{{3{~current_read[102]}} & Vw0},{{3{~current_read[101]}} & Vw0},{{3{~current_read[100]}} & Vw0}
			,{{3{~current_read[99]}} & Vw0},{{3{~current_read[98]}} & Vw0},{{3{~current_read[97]}} & Vw0},{{3{~current_read[96]}} & Vw0},{{3{~current_read[95]}} & Vw0},{{3{~current_read[94]}} & Vw0},{{3{~current_read[93]}} & Vw0},{{3{~current_read[92]}} & Vw0},{{3{~current_read[91]}} & Vw0},{{3{~current_read[90]}} & Vw0}
			,{{3{~current_read[89]}} & Vw0},{{3{~current_read[88]}} & Vw0},{{3{~current_read[87]}} & Vw0},{{3{~current_read[86]}} & Vw0},{{3{~current_read[85]}} & Vw0},{{3{~current_read[84]}} & Vw0},{{3{~current_read[83]}} & Vw0},{{3{~current_read[82]}} & Vw0},{{3{~current_read[81]}} & Vw0},{{3{~current_read[80]}} & Vw0}
			,{{3{~current_read[79]}} & Vw0},{{3{~current_read[78]}} & Vw0},{{3{~current_read[77]}} & Vw0},{{3{~current_read[76]}} & Vw0},{{3{~current_read[75]}} & Vw0},{{3{~current_read[74]}} & Vw0},{{3{~current_read[73]}} & Vw0},{{3{~current_read[72]}} & Vw0},{{3{~current_read[71]}} & Vw0},{{3{~current_read[70]}} & Vw0}
			,{{3{~current_read[69]}} & Vw0},{{3{~current_read[68]}} & Vw0},{{3{~current_read[67]}} & Vw0},{{3{~current_read[66]}} & Vw0},{{3{~current_read[65]}} & Vw0},{{3{~current_read[64]}} & Vw0},{{3{~current_read[63]}} & Vw0},{{3{~current_read[62]}} & Vw0},{{3{~current_read[61]}} & Vw0},{{3{~current_read[60]}} & Vw0}
			,{{3{~current_read[59]}} & Vw0},{{3{~current_read[58]}} & Vw0},{{3{~current_read[57]}} & Vw0},{{3{~current_read[56]}} & Vw0},{{3{~current_read[55]}} & Vw0},{{3{~current_read[54]}} & Vw0},{{3{~current_read[53]}} & Vw0},{{3{~current_read[52]}} & Vw0},{{3{~current_read[51]}} & Vw0},{{3{~current_read[50]}} & Vw0}
			,{{3{~current_read[49]}} & Vw0},{{3{~current_read[48]}} & Vw0},{{3{~current_read[47]}} & Vw0},{{3{~current_read[46]}} & Vw0},{{3{~current_read[45]}} & Vw0},{{3{~current_read[44]}} & Vw0},{{3{~current_read[43]}} & Vw0},{{3{~current_read[42]}} & Vw0},{{3{~current_read[41]}} & Vw0},{{3{~current_read[40]}} & Vw0}
			,{{3{~current_read[39]}} & Vw0},{{3{~current_read[38]}} & Vw0},{{3{~current_read[37]}} & Vw0},{{3{~current_read[36]}} & Vw0},{{3{~current_read[35]}} & Vw0},{{3{~current_read[34]}} & Vw0},{{3{~current_read[33]}} & Vw0},{{3{~current_read[32]}} & Vw0},{{3{~current_read[31]}} & Vw0},{{3{~current_read[30]}} & Vw0}
			,{{3{~current_read[29]}} & Vw0},{{3{~current_read[28]}} & Vw0},{{3{~current_read[27]}} & Vw0},{{3{~current_read[26]}} & Vw0},{{3{~current_read[25]}} & Vw0},{{3{~current_read[24]}} & Vw0},{{3{~current_read[23]}} & Vw0},{{3{~current_read[22]}} & Vw0},{{3{~current_read[21]}} & Vw0},{{3{~current_read[20]}} & Vw0}
			,{{3{~current_read[19]}} & Vw0},{{3{~current_read[18]}} & Vw0},{{3{~current_read[17]}} & Vw0},{{3{~current_read[16]}} & Vw0},{{3{~current_read[15]}} & Vw0},{{3{~current_read[14]}} & Vw0},{{3{~current_read[13]}} & Vw0},{{3{~current_read[12]}} & Vw0},{{3{~current_read[11]}} & Vw0},{{3{~current_read[10]}} & Vw0}
			,{{3{~current_read[9]}} & Vw0},{{3{~current_read[8]}} & Vw0},{{3{~current_read[7]}} & Vw0},{{3{~current_read[6]}} & Vw0},{{3{~current_read[5]}} & Vw0},{{3{~current_read[4]}} & Vw0},{{3{~current_read[3]}} & Vw0},{{3{~current_read[2]}} & Vw0},{{3{~current_read[1]}} & Vw0},{{3{~current_read[0]}} & Vw0} };
	

////////////////////////////////////////////

	//row_selector <= {{(num_of_rows_in_crossbar - counter_row_storage){Vfloating}}, Vresistor, {counter_row_storage{Vfloating}}}; 

	if (counter_row_storage == 3'b001) begin
		row_selector <= {{59{Vfloating}}, Vresistor, {4{Vfloating}}};
	end
	else if (counter_row_storage == 3'b010) begin
		row_selector <= {{60{Vfloating}}, Vresistor, {3{Vfloating}}};
	end
	else if (counter_row_storage == 3'b011) begin
		row_selector <= {{61{Vfloating}}, Vresistor, {2{Vfloating}}};
	end
	else if (counter_row_storage == 3'b100) begin
		row_selector <= {{62{Vfloating}}, Vresistor, Vfloating};
	end
	else if (counter_row_storage == 3'b101) begin
		row_selector <= {{63{Vfloating}}, Vresistor};
	end
//////////////////////////////////////////////
	//flag_relevent_read <= 1'b0;
	

	
	if (counter_col_storage == 2'b01) begin
		col_selector <= { {(ones_positions | zeros_positions)}, {712{Vfloating}}};
		//col_selector <= {{(ones_positions | zeros_positions)}, {(num_of_cols_in_crossbar - num_of_bits_in_read){Vfloating}}};

	end
	else if (counter_col_storage == 2'b10) begin
		col_selector <= { {(num_of_bits_in_read){Vfloating}}, {ones_positions | zeros_positions}, {400{Vfloating}} };
		//col_selector <= {{(num_of_bits_in_read){Vfloating}}, (ones_positions | zeros_positions), {(num_of_cols_in_crossbar - num_of_bits_in_read - num_of_bits_in_read){Vfloating}}};

	end
	else if (counter_col_storage == 2'b11) begin
		col_selector <= {{624{Vfloating}}, {(ones_positions | zeros_positions)}, {88{Vfloating}}};                  
		//col_selector <= {{(num_of_bits_in_read + num_of_bits_in_read){Vfloating}}, {(ones_positions | zeros_positions)}, {(num_of_cols_in_crossbar - num_of_bits_in_read - num_of_bits_in_read - num_of_bits_in_read){Vfloating}}};                  

	end
	
/// Increasing row_storage
	if (counter_row_storage == end_row_FIFO) begin
		counter_row_storage <= start_row_FIFO;
	end
	else if (counter_col_storage == 2'b11) begin
		counter_row_storage <= counter_row_storage + 3'b001;
	end

/// Increasing col_storage
	if (counter_col_storage == 2'b11) begin
		counter_col_storage <= 2'b01;
	end
	else begin
		counter_col_storage <= counter_col_storage + 2'b01;
	end


//end	



end

else begin
	flag_done <= 1'b0;
end

end		
end



always_comb begin
	

	if(flag_done == 1'b1) begin
		flag_relevent_read = 1'b0;
		current_read = 312'b0;
		
	end
	else begin
		flag_relevent_read = 1'b1;
		current_read = 312'b0;
	end
	

	if(inst[511:510] == 2'b00) begin
		if (counter_accepting_reads == 1'b0) begin
			flag_relevent_read = 1'b0;
			current_read = inst[453 : 142];
			counter_accepting_reads = 1'b1;
			
			if (inst[509 : 490] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[489:482];
				flag_relevent_read = 1'b1;
			end
			else if (inst[481 : 462] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[461:454];
				flag_relevent_read = 1'b1;
			end
			else if (inst[453 : 434] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[433:426];
				flag_relevent_read = 1'b1;
			end
			else if (inst[425 : 406] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[405:398];
				flag_relevent_read = 1'b1;
			end
			else if (inst[397 : 378] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[377:370];
				flag_relevent_read = 1'b1;
			end
			else if (inst[369 : 350] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[349:342];
				flag_relevent_read = 1'b1;
			end
			else if (inst[341 : 322] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[321:314];
				flag_relevent_read = 1'b1;
			end
			else if (inst[313 : 294] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[293:286];
				flag_relevent_read = 1'b1;
			end
			else if (inst[285 : 266] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[265:258];
				flag_relevent_read = 1'b1;
			end
			else if (inst[257 : 238] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[237:230];
				flag_relevent_read = 1'b1;
			end
			else if (inst[229 : 210] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[209:202];
				flag_relevent_read = 1'b1;
			end
			else if (inst[201 : 182] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[181:174];
				flag_relevent_read = 1'b1;
			end
			else if (inst[173 : 154] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[153:146];
				flag_relevent_read = 1'b1;
			end
			else if (inst[145 : 126] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[125:118];
				flag_relevent_read = 1'b1;
			end
			else if (inst[117 : 98] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[97:90];
				flag_relevent_read = 1'b1;
			end
			else if (inst[89 : 70] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[69:62];
				flag_relevent_read = 1'b1;
			end
			else if (inst[61 : 42] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[41:34];
				flag_relevent_read = 1'b1;
			end
			else if (inst[33 : 14] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[13:6];
				flag_relevent_read = 1'b1;
			end
			else begin
				location_of_minimizer = inst[7:0];
				flag_relevent_read = 1'b0;				
			end

		end
		else begin
			
			current_read = inst[453 : 142];
			counter_accepting_reads = 1'b0;			
			
			if (inst[509 : 490] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[489:482];
				flag_relevent_read = 1'b1;
			end
			else if (inst[481 : 462] == minimizer_of_crossbar) begin
				location_of_minimizer = inst[461:454];
				flag_relevent_read = 1'b1;
			end
			else begin
				counter_accepting_reads = 1'b0;			
			end
			
		
		end


	end
	
	else begin
		counter_accepting_reads = 1'b0;
	end
	
end


endmodule


