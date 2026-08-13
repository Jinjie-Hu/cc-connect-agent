module SP_Ram
(
wData,
rData,
wEn,
En,
Addr,
clk
);

parameter DEPTH = 8; 
parameter BIT_WIDTH = 16;  //16*8*3
parameter ADDR_WIDTH = 3; //0-2^16-1

output reg [BIT_WIDTH-1:0] rData;

input clk;
input wEn, En;
input [ADDR_WIDTH-1:0] Addr;
input [BIT_WIDTH-1:0] wData;

reg [BIT_WIDTH-1:0] memreg [0:DEPTH-1];

always @ (posedge clk)
begin
  if (En && wEn) begin
      memreg[Addr] <= wData;
  end
end

always @ (posedge clk)
begin
  if (En && !wEn) begin
      rData <= memreg[Addr];
  end
end

endmodule