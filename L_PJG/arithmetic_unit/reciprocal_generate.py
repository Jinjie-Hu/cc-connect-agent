import numpy as np

# setting
input_quantization_config = (0, 9, 0)
output_quantization_config = (0, 0, 12)

# auxiliary function
def int2float(x, quantized_config):
	bit_width = quantized_config[0] + quantized_config[1] + quantized_config[2]
	int_fp_w = quantized_config[1] + quantized_config[2]

	if (quantized_config[0] and x & (1<<int_fp_w)):	#negative
		x_neg = ~x + 1
		assert x_neg < 0, f"x_neg = {x_neg}, x = {x}"
		x = x_neg

	x /= (1<<quantized_config[2])
	return x

def quantization(x, quantized_config):
    sign_bit, int_bit, decimal_bit = quantized_config
    x *= 1 << decimal_bit
    x = np.floor(x) # rounding

    # out = x / (1 << (decimal_bit + int_bit))
    # if (out.max() > 1):
    #     raise ValueError(f"{x.max()} is out of the domain of quantization")

    x -= np.trunc(x / (1 << (decimal_bit + int_bit))) * (1 << (decimal_bit + int_bit))
    x /= (1 << decimal_bit)
    
    if (sign_bit == False):
        x = np.abs(x)
    return x

# logic
input_bit_width = input_quantization_config[0] + input_quantization_config[1] + input_quantization_config[2]
output_bit_width = output_quantization_config[0] + output_quantization_config[1] + output_quantization_config[2]

input_bit_range = range(1<<input_bit_width)

# note print
note  = f"// Input : {input_quantization_config}\n"
note += f"// Output: {output_quantization_config}\n"

# module print
module  = "module reciprocal_lut (\n"
module += f"\tinput  [{input_bit_width}-1:0] InputA,\n"
module += f"\toutput reg [{output_bit_width}-1:0] OutputB\n"
module += ");\n"
module += "\talways @(InputA) begin\n"

# look-up table
module += "\t\tcase(InputA)\n"
for input_int in input_bit_range:
	if (input_int == 0):
		module += f"\t\t\t{input_bit_width}'h0000: OutputB <= {output_bit_width}'h0000; // 0.0->0.0\n"
	else:
		#input_fp = int2float(input_int, input_quantization_config)
		input_fp = int2float(input_int, input_quantization_config)
		output_fp = 1 / input_fp
		output_fp = quantization(output_fp, output_quantization_config)
		output_int = np.array(output_fp * (1<<output_quantization_config[2]), dtype=np.uint16)
		module += f"\t\t\t{input_bit_width}'h{input_int:04x}: OutputB <= {output_bit_width}'h{output_int:04x}; // {input_fp}->{output_fp}\n"
	pass

module += f"\t\t\tdefault: OutputB <= {output_bit_width}'h0000;\n"
module += "\t\tendcase\n"
module += "\tend\n"
module += "endmodule\n"

# write verilog file
with open("reciprocal_lut.v", "w+") as fp:
    fp.write(note+module)