/*------------------------------------------------------------------------------
 * File          : Bank_Controller.sv
 * Project       : RTL
 * Author        : eplgda
 * Creation date : Mar 21, 2024
 * Description   :
 *------------------------------------------------------------------------------*/


module Bank_Controller #(parameter WIDTH_LSB = 10, parameter WIDTH_MSB = 12, parameter WIDTH_LSB_1 = 11) (
input logic clk,
input logic rst,

input logic [511:0] inst,
output logic [WIDTH_LSB:0] minimizer_out,
output logic [311:0] relevent_read
);


/// localparam size_of_instruction = 9'b100000000; // = 512;
//localparam num_of_bits_in_read  = 9'b100111000; // = 312 ; //  150 bp + 12bits for read's index

localparam [WIDTH_MSB:0] minimizer_of_bank = {{1'b1}, 6'b000000, 6'b111111} ; 

//{(24 - (WIDTH + 2)){{1'b1}, 5'b00000, 5'b11111}}

logic flag_relevent_read;
logic counter;

//logic [311:0] current_read; //storing temporary read, num_of_bits_in_read - 1 = 312 - 1 = 311


always_ff @(posedge clk or posedge rst) begin
if (rst == 1'b1) begin
	//flag_relevent_read <= 1'b0;
	relevent_read <= 312'b0;
	counter <= 1'b0;

end
else begin
	counter <= 1'b1;
	if ((flag_relevent_read == 1'b1) && (counter == 1'b1)) begin
		relevent_read <= inst[511:200];
		counter <= 1'b0;
	end
	
end

end

always_comb begin
flag_relevent_read = 1'b0;
	
	if (inst[509 : 497] == minimizer_of_bank) begin
		minimizer_out = inst[496:486];
		flag_relevent_read = 1'b1;
	end
	else if (inst[485 : 473] == minimizer_of_bank) begin
		minimizer_out = inst[472:462];
		flag_relevent_read = 1'b1;
	end
	else if (inst[461 : 449] == minimizer_of_bank) begin
		minimizer_out = inst[448:438];
		flag_relevent_read = 1'b1;
	end
	else if (inst[437 : 425] == minimizer_of_bank) begin
		minimizer_out = inst[424:414];
		flag_relevent_read = 1'b1;
	end
	else if (inst[413 : 401] == minimizer_of_bank) begin
		minimizer_out = inst[400:390];
		flag_relevent_read = 1'b1;
	end
	else if (inst[389 : 377] == minimizer_of_bank) begin
		minimizer_out = inst[376:366];
		flag_relevent_read = 1'b1;
	end
	else if (inst[365 : 353] == minimizer_of_bank) begin
		minimizer_out = inst[352:342];
		flag_relevent_read = 1'b1;
	end
	else if (inst[341 : 329] == minimizer_of_bank) begin
		minimizer_out = inst[328:318];
		flag_relevent_read = 1'b1;
	end
	else if (inst[317 : 305] == minimizer_of_bank) begin
		minimizer_out = inst[304:294];
		flag_relevent_read = 1'b1;
	end
	else if (inst[293 : 281] == minimizer_of_bank) begin
		minimizer_out = inst[280:270];
		flag_relevent_read = 1'b1;
	end
	else if (inst[269 : 257] == minimizer_of_bank) begin
		minimizer_out = inst[256:246];
		flag_relevent_read = 1'b1;
	end
	else if (inst[245 : 233] == minimizer_of_bank) begin
		minimizer_out = inst[232:222];
		flag_relevent_read = 1'b1;
	end
	else if (inst[221 : 209] == minimizer_of_bank) begin
		minimizer_out = inst[208:198];
		flag_relevent_read = 1'b1;
	end
	else if (inst[197 : 185] == minimizer_of_bank) begin
		minimizer_out = inst[184:174];
		flag_relevent_read = 1'b1;
	end
	else if (inst[173 : 161] == minimizer_of_bank) begin
		minimizer_out = inst[160:150];
		flag_relevent_read = 1'b1;
	end
	else if (inst[149 : 137] == minimizer_of_bank) begin
		minimizer_out = inst[136:126];
		flag_relevent_read = 1'b1;
	end
	else if (inst[125 : 113] == minimizer_of_bank) begin
		minimizer_out = inst[112:102];
		flag_relevent_read = 1'b1;
	end
	else if (inst[101 : 89] == minimizer_of_bank) begin
		minimizer_out = inst[88:78];
		flag_relevent_read = 1'b1;
	end
	else if (inst[77 : 65] == minimizer_of_bank) begin
		minimizer_out = inst[64:54];
		flag_relevent_read = 1'b1;
	end
	else if (inst[53 : 41] == minimizer_of_bank) begin
		minimizer_out = inst[40:30];
		flag_relevent_read = 1'b1;
	end
	else begin
		minimizer_out = {WIDTH_LSB_1{1'b0}};
		flag_relevent_read = 1'b0;
	end

	
end


endmodule
