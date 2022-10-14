#define _DEFAULT_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdint.h>
#include <err.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

struct instruct {
	uint8_t opcode;
	uint64_t op1;
	uint64_t op2;
	uint64_t op3;
}__attribute__((packed));

int main(const int argc, const char* argv[]) {
	if (argc != 2) {
		errx(1, "Wrong num of arguments!");
	}

	int fd;
	fd = open(argv[1], O_RDONLY);

	if (fd == -1) {
		err(2, "%s", argv[1]);
	}
	char orc[3];
	ssize_t read_size;
	if ((read_size = read(fd, &orc, sizeof(orc))) < 0) {
		errx(3, "Error while reading ORC!");
	}

	if (orc[0] != 'O' || orc[1] != 'R' || orc[2] != 'C') {
		err(4, "File does not begin with ORC");
	}

	uint32_t ram_size;
	
	if((read_size = read(fd, &ram_size, sizeof(ram_size))) < 0) {
		errx(5, "Error while reading size of file!");
	}

	uint64_t* memory=calloc(ram_size, 8);
	if(memory == NULL) {
		err(6, "Error with memory: calloc");
	}

	struct instruct inst;
	while( (read_size = read(fd, &inst, sizeof(inst))) ) {
		switch(inst.opcode){
			case 0x00:
				break;
			case 0x95:
				if(inst.op1 >= ram_size) {
					errx(9, "Invalid address in instruction with opcode 0x95");
				}
				memory[inst.op1] = inst.op2;
				break;
			case 0x5d:
				if(inst.op1 >= ram_size || inst.op2 >= ram_size || memory[inst.op2] >= ram_size) {
					errx(10, "Invalid address in instruction with opcode 0x5d");
				}
				memory[inst.op1] = memory[memory[inst.op2]];
				break;
			case 0x63:
				if(inst.op1 >= ram_size || inst.op2 >= ram_size || memory[inst.op1] >= ram_size){
					errx(11, "Invalid address in instruction with opcode 0x63");
				}
				memory[memory[inst.op1]] = memory[inst.op2];
				break;
			case 0x91:
				if(inst.op1 >= ram_size) {
					errx(12, "Invalid address in instruction with opcode 0x91");
				}
				if((lseek(fd, 7+25*memory[inst.op1], SEEK_SET)) < 0) {
					err(13, "Error with lseek in instruction with opcose 0x91");
				}
				break;
			case 0x25:
				if(inst.op1 >= ram_size) {
					errx(14, "Invalid address in instruction with opcode 0x25");
				}
				if(memory[inst.op1]>0) {
					if( (lseek(fd, 25, SEEK_CUR)) < 0) {
						err(15, "Error with lseek in instruction with opcode 0x25");
					}
				}
				break;
			case 0xad:
				if(inst.op1 >= ram_size || inst.op2 >= ram_size || inst.op3 >= ram_size) {
					errx(16, "Invalid address in instruction with opcode 0xad");
				}
				memory[inst.op1] = memory[inst.op2] + memory[inst.op3];
				break;
			case 0x33:
				if(inst.op1 >=ram_size || inst.op2 >= ram_size || inst.op3 >= ram_size) {
					errx(17, "Invalid address in instruction with opcode 0x33");
				}
				memory[inst.op1] = memory[inst.op2] * memory[inst.op3];
				break;
			case 0x04:
				if(inst.op1 >= ram_size || inst.op2 >= ram_size || inst.op3 >= ram_size) {
					errx(18, "Invalid address in instruction with opcode 0x04");
				}
				if(memory[inst.op3] == 0) {
					err(19, "Division by 0 in instruction with opcode 0x04");
				}
				memory[inst.op1] = memory[inst.op2] / memory[inst.op3];
				break;
			case 0xb5:
				if(inst.op1 >= ram_size || inst.op2 >= ram_size || inst.op3 >= ram_size) {
					errx(20, "Invalid address in instrudtion with opcode 0xb5");
				}
				if(memory[inst.op3] == 0) {
					err(21, "Division by 0 in instruction with opcode 0xb5");
				}
				memory[inst.op1] = memory[inst.op2] % memory[inst.op3];
				break;
			case 0xc1:
				if(inst.op1 >= ram_size) {
					errx(22, "Invalid address in instruction with opcode 0xc1");
				}
				if(memory[inst.op1] > 127) {
					err(23, "Invalid ascii code in instrudtion with opcode 0xc1");
				}
				fprintf(stdout, "%c", (char)memory[inst.op1]);
				break;
			case 0xbf:
				if(inst.op1 >= ram_size) {
					errx(24, "Invalid address in instruction with opcode 0xbf");
				}
				if(usleep(memory[inst.op1]*1000) < 0) {
					err(26, "Error with usleep command in instruction with opcode 0xbf");
				}
				break;
			case 0x0a:
				break;
			default:
				errx(8, "Invalid instruction!");
		}
	}

	if(read_size == -1) {
		err(7, "Error while reading file!");
	}

	free(memory);
	close(fd);
	exit(0);
}
