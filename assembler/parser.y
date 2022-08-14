%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>

#include "opcode.h"
#include "preprocessor.h"

#define YYDEBUG 1

#include "parser.tab.h"

//#include "lexer.yy.h"

extern int yylex(void);
extern int yyparse(void);
extern FILE* yyin;

void yyerror(const char* s, ...);

//right now these "vectors" have a limited size of 255/6 meaning that they arent very big
//this means that programs can use at most 255/6 labels/define constants before error
//in future refactor this to include better modularity and heap allocation


typedef struct
{
	uint8_t bytes[USHRT_MAX + 1];
	uint16_t addr;
} Code;
	
typedef struct
{
	char* name;
	uint16_t addr;
} Label;
	
typedef struct
{
	Label list[UCHAR_MAX + 1];
	uint8_t addr;
} Labels;
	
typedef struct
{
	char* name;
	uint16_t value;
} Definition;
	
typedef struct
{
	Definition list[UCHAR_MAX + 1];
	uint8_t addr;
} Definitions;
	
Code code;
Labels defined_labels, referenced_labels;
Definitions definitions;



	
void emit8(uint8_t num)
{
	code.bytes[code.addr] = num;
	++code.addr;
}
	
void emit16(uint16_t num)
{
	emit8((num & 0x00FF) >> 0);
	emit8((num & 0xFF00) >> 8);
}
	
#define emitJump(n, m)                  \
Label label;                            \
label.name = m;                         \
label.addr = code.addr;                 \
appendLabel(&referenced_labels, label); \
emit8(n);                               \
emit16(0xCCCC);                         \
	
#define log(s, ...) fprintf(stderr, s, __VA_ARGS__)
    
void appendLabel(Labels* labels, Label label)
{
	labels->list[labels->addr] = label;
	++labels->addr;
}

void appendDefinition(Definitions* definitions, Definition definition)
{
	definitions->list[definitions->addr] = definition;
	++definitions->addr;
}

%}

%locations

%union
{
	int ival;
	char* cval;
}

%token<ival> T_DEC T_HEX T_BIN
%token<cval> T_COMMENT T_LABEL T_STRING T_JUMP T_BLOCK T_TEXT

%token T_NEWLINE T_PLUS T_MINUS T_MULTIPLY T_DIVIDE T_BSHL T_BSHR T_BAND T_BNOT T_BLOR T_BXOR T_LEFT T_RIGHT T_COMMA T_POUND T_PERCENT T_AMPERSAND T_EQUALS T_CARAT T_COLON

%token T_DORG T_DDEFINE T_DBYTE T_DWORD T_DASCII T_DBEGIN

%token T_A T_B T_C T_D T_AB T_CD T_F T_IP

%token T_NOP T_BRK T_ADC T_SBB T_AND T_LOR T_NOT T_ROL T_ROR T_LDB T_STB T_MVB T_JEZ T_JGZ T_JCS T_PUSH T_POP T_DREF T_IN T_OUT


%type<ival> imm mem number expression


%left T_BLOR
%left T_BXOR
%left T_BAND
%left T_PLUS T_MINUS
%left T_BSHL T_BSHR
%left T_MULTIPLY T_DIVIDE
%left T_BNOT

%start program

%%
	
    program: lines;
	
lines:
	 | lines line;
	 
line: label_opt instruction comment_opt T_NEWLINE
	| directive comment_opt T_NEWLINE
	| label comment_opt T_NEWLINE
	| comment T_NEWLINE
	| T_NEWLINE;
		 
label: T_LABEL
{
	Label label;
	label.name = $1;
	label.addr = code.addr;
	
	bool found = false;
	for (int i = 0; i < defined_labels.addr; ++i)
	{
		if (strcmp(label.name, defined_labels.list[i].name) == 0)
		{
			found = true;
			break;
		}
	}
	
	if (found)
	{
        yyerror("Label %s is multiply defined", label.name);
	}
	
	appendLabel(&defined_labels, label);
}

label_opt:
         | label;

comment: T_COMMENT;
		 
comment_opt:
		   | comment;

directive: T_DORG expression { code.addr = $2; }
         | T_DBEGIN { code.addr = 0x8000; }
		 | T_DBYTE expression { emit8($2); }
		 | T_DWORD expression { emit16($2); }
         | T_DDEFINE T_TEXT T_EQUALS expression
		 {
			 Definition definition;
			 definition.name = $2;
			 definition.value = $4;
			 
			 bool found = false;
			 for (int i = 0; i < definitions.addr; ++i)
			 {
				 if (strcmp(definition.name, definitions.list[i].name) == 0)
				 {
					 found = true;
					 break;
				 }
			 }
			 
			 if (found)
			 {
                 yyerror("Identifier %s is multiply defined", definition.name);
			 }
			 
			 appendDefinition(&definitions, definition);
		 }
         | T_DASCII T_STRING
		 {
			 for (unsigned i = 0; i < strlen($2); ++i)
				emit8($2[i]);
		 };
		 
instruction: mnemonic;

mnemonic: nop_instruction
        | brk_instruction
        | adc_instruction
        | sbb_instruction
        | and_instruction
        | or_instruction
        | not_instruction
        | rol_instruction
        | ror_instruction
        | ldb_instruction
        | stb_instruction
        | mvb_instruction
        | jez_instruction
        | jgz_instruction
        | jcs_instruction
        | push_instruction
        | pop_instruction
		| dref_instruction
        | error;

nop_instruction: T_NOP { emit8(NOP); };
brk_instruction: T_BRK { emit8(BRK); };
		
adc_instruction: T_ADC T_A T_COMMA T_B { emit8(ADC_A_B); }
               | T_ADC T_A T_COMMA T_C { emit8(ADC_A_C); }
               | T_ADC T_A T_COMMA T_D { emit8(ADC_A_D); }
               | T_ADC T_A T_COMMA imm { emit8(ADC_A_IMM); emit8($4); }
               | T_ADC T_A T_COMMA mem { emit8(ADC_A_MEM); emit16($4); }
               | T_ADC T_A T_COMMA error
               
               | T_ADC T_B T_COMMA T_A { emit8(ADC_B_A); }
               | T_ADC T_B T_COMMA T_C { emit8(ADC_B_C); }
               | T_ADC T_B T_COMMA T_D { emit8(ADC_B_D); }
               | T_ADC T_B T_COMMA imm { emit8(ADC_B_IMM); emit8($4); }
               | T_ADC T_B T_COMMA mem { emit8(ADC_B_MEM); emit16($4); }
               | T_ADC T_B T_COMMA error
               
               | T_ADC T_C T_COMMA T_A { emit8(ADC_C_A); }
               | T_ADC T_C T_COMMA T_B { emit8(ADC_C_B); }
               | T_ADC T_C T_COMMA T_D { emit8(ADC_C_D); }
               | T_ADC T_C T_COMMA imm { emit8(ADC_C_IMM); emit8($4); }
               | T_ADC T_C T_COMMA mem { emit8(ADC_C_MEM); emit16($4); }
               | T_ADC T_C T_COMMA error
               
               | T_ADC T_D T_COMMA T_A { emit8(ADC_D_A); }
               | T_ADC T_D T_COMMA T_B { emit8(ADC_D_B); }
               | T_ADC T_D T_COMMA T_C { emit8(ADC_D_C); }
               | T_ADC T_D T_COMMA imm { emit8(ADC_D_IMM); emit8($4); }
               | T_ADC T_D T_COMMA mem { emit8(ADC_D_MEM); emit16($4); }
               | T_ADC T_D T_COMMA error
			   
               | T_ADC error T_COMMA T_A
               | T_ADC error T_COMMA T_B
               | T_ADC error T_COMMA T_C
               | T_ADC error T_COMMA T_D
               | T_ADC error T_COMMA imm
               | T_ADC error T_COMMA mem
               | T_ADC error T_COMMA error;
               
sbb_instruction: T_SBB T_A T_COMMA T_B { emit8(SBB_A_B); }
               | T_SBB T_A T_COMMA T_C { emit8(SBB_A_C); }
               | T_SBB T_A T_COMMA T_D { emit8(SBB_A_D); }
               | T_SBB T_A T_COMMA imm { emit8(SBB_A_IMM); emit8($4); }
               | T_SBB T_A T_COMMA mem { emit8(SBB_A_MEM); emit16($4); }
               | T_SBB T_A T_COMMA error
               
               | T_SBB T_B T_COMMA T_A { emit8(SBB_B_A); }
               | T_SBB T_B T_COMMA T_C { emit8(SBB_B_C); }
               | T_SBB T_B T_COMMA T_D { emit8(SBB_B_D); }
               | T_SBB T_B T_COMMA imm { emit8(SBB_B_IMM); emit8($4); }
               | T_SBB T_B T_COMMA mem { emit8(SBB_B_MEM); emit16($4); }
               | T_SBB T_B T_COMMA error
               
               | T_SBB T_C T_COMMA T_A { emit8(SBB_C_A); }
               | T_SBB T_C T_COMMA T_B { emit8(SBB_C_B); }
               | T_SBB T_C T_COMMA T_D { emit8(SBB_C_D); }
               | T_SBB T_C T_COMMA imm { emit8(SBB_C_IMM); emit8($4); }
               | T_SBB T_C T_COMMA mem { emit8(SBB_C_MEM); emit16($4); }
               | T_SBB T_C T_COMMA error
               
               | T_SBB T_D T_COMMA T_A { emit8(SBB_D_A); }
               | T_SBB T_D T_COMMA T_B { emit8(SBB_D_B); }
               | T_SBB T_D T_COMMA T_C { emit8(SBB_D_C); }
               | T_SBB T_D T_COMMA imm { emit8(SBB_D_IMM); emit8($4); }
			   | T_SBB T_D T_COMMA mem { emit8(SBB_D_MEM); emit16($4); }
               | T_SBB T_D T_COMMA error
			   
               | T_SBB error T_COMMA T_A
               | T_SBB error T_COMMA T_B
               | T_SBB error T_COMMA T_C
               | T_SBB error T_COMMA T_D
               | T_SBB error T_COMMA imm
               | T_SBB error T_COMMA mem
               | T_SBB error T_COMMA error;
               

and_instruction: T_AND T_A T_COMMA T_B { emit8(AND_A_B); }
               | T_AND T_A T_COMMA T_C { emit8(AND_A_C); }
               | T_AND T_A T_COMMA T_D { emit8(AND_A_D); }
               | T_AND T_A T_COMMA imm { emit8(AND_A_IMM); emit8($4); }
               | T_AND T_A T_COMMA mem { emit8(AND_A_MEM); emit16($4); }
               | T_AND T_A T_COMMA error
               
               | T_AND T_B T_COMMA T_A { emit8(AND_B_A); }
               | T_AND T_B T_COMMA T_C { emit8(AND_B_C); }
               | T_AND T_B T_COMMA T_D { emit8(AND_B_D); }
               | T_AND T_B T_COMMA imm { emit8(AND_B_IMM); emit8($4); }
               | T_AND T_B T_COMMA mem { emit8(AND_B_MEM); emit16($4); }
               | T_AND T_B T_COMMA error
               
               | T_AND T_C T_COMMA T_A { emit8(AND_C_A); }
               | T_AND T_C T_COMMA T_B { emit8(AND_C_B); }
               | T_AND T_C T_COMMA T_D { emit8(AND_C_D); }
               | T_AND T_C T_COMMA imm { emit8(AND_C_IMM); emit8($4); }
               | T_AND T_C T_COMMA mem { emit8(AND_C_MEM); emit16($4); }
               | T_AND T_C T_COMMA error
               
               | T_AND T_D T_COMMA T_A { emit8(AND_D_A); }
               | T_AND T_D T_COMMA T_B { emit8(AND_D_B); }
               | T_AND T_D T_COMMA T_C { emit8(AND_D_C); }
               | T_AND T_D T_COMMA imm { emit8(AND_D_IMM); emit8($4); }
               | T_AND T_D T_COMMA mem { emit8(AND_D_MEM); emit16($4); }
               | T_AND T_D T_COMMA error
               
               | T_AND error T_COMMA T_A
               | T_AND error T_COMMA T_B
               | T_AND error T_COMMA T_C
               | T_AND error T_COMMA T_D
               | T_AND error T_COMMA imm
               | T_AND error T_COMMA mem
               | T_AND error T_COMMA error;
			   
			   
or_instruction:  T_LOR  T_A T_COMMA T_B { emit8(LOR_A_B); }
			  |  T_LOR  T_A T_COMMA T_C { emit8(LOR_A_C); }
			  |  T_LOR  T_A T_COMMA T_D { emit8(LOR_A_D); }
			  |  T_LOR  T_A T_COMMA imm { emit8(LOR_A_IMM); emit8($4); }
			  |  T_LOR  T_A T_COMMA mem { emit8(LOR_A_MEM); emit16($4); }
              |  T_LOR  T_A T_COMMA error
 
              |  T_LOR  T_B T_COMMA T_A { emit8(LOR_B_A); }
              |  T_LOR  T_B T_COMMA T_C { emit8(LOR_B_C); }
              |  T_LOR  T_B T_COMMA T_D { emit8(LOR_B_D); }
              |  T_LOR  T_B T_COMMA imm { emit8(LOR_B_IMM); emit8($4); }
              |  T_LOR  T_B T_COMMA mem { emit8(LOR_B_MEM); emit16($4); }
              |  T_LOR  T_B T_COMMA error
              
              |  T_LOR  T_C T_COMMA T_A { emit8(LOR_C_A); }
              |  T_LOR  T_C T_COMMA T_B { emit8(LOR_C_B); }
              |  T_LOR  T_C T_COMMA T_D { emit8(LOR_C_D); }
              |  T_LOR  T_C T_COMMA imm { emit8(LOR_C_IMM); emit8($4); }
              |  T_LOR  T_C T_COMMA mem { emit8(LOR_C_MEM); emit16($4); }
              |  T_LOR  T_C T_COMMA error
              
              |  T_LOR  T_D T_COMMA T_A { emit8(LOR_D_A); }
              |  T_LOR  T_D T_COMMA T_B { emit8(LOR_D_B); }
              |  T_LOR  T_D T_COMMA T_C { emit8(LOR_D_C); }
              |  T_LOR  T_D T_COMMA imm { emit8(LOR_D_IMM); emit8($4); }
              |  T_LOR  T_D T_COMMA mem { emit8(LOR_D_MEM); emit16($4); }
              |  T_LOR  T_D T_COMMA error
              
              |  T_LOR error T_COMMA T_A
              |  T_LOR error T_COMMA T_B
              |  T_LOR error T_COMMA T_C
              |  T_LOR error T_COMMA T_D
              |  T_LOR error T_COMMA imm
              |  T_LOR error T_COMMA mem
              |  T_LOR error T_COMMA error;
			   
not_instruction: T_NOT T_A { emit8(NOT_A); }
			   | T_NOT T_B { emit8(NOT_B); }
			   | T_NOT T_C { emit8(NOT_C); }
			   | T_NOT T_D { emit8(NOT_D); }
               
               | T_NOT error
               | error T_NOT;
			
            
rol_instruction: T_ROL T_A T_COMMA imm { emit8(ROL_A_IMM); emit8($4); }
			   | T_ROL T_B T_COMMA imm { emit8(ROL_B_IMM); emit8($4); }
			   | T_ROL T_C T_COMMA imm { emit8(ROL_C_IMM); emit8($4); }
			   | T_ROL T_D T_COMMA imm { emit8(ROL_D_IMM); emit8($4); }
               
               | T_ROL T_A T_COMMA error
               | T_ROL T_B T_COMMA error
               | T_ROL T_C T_COMMA error
               | T_ROL T_D T_COMMA error
               
               | T_ROL error T_COMMA T_A
               | T_ROL error T_COMMA T_B
               | T_ROL error T_COMMA T_C
               | T_ROL error T_COMMA T_D
               
               | T_ROL error T_COMMA error;
			   
               
ror_instruction: T_ROR T_A T_COMMA imm { emit8(ROR_A_IMM); emit8($4); }
			   | T_ROR T_B T_COMMA imm { emit8(ROR_B_IMM); emit8($4); }
			   | T_ROR T_C T_COMMA imm { emit8(ROR_C_IMM); emit8($4); }
			   | T_ROR T_D T_COMMA imm { emit8(ROR_D_IMM); emit8($4); }
               
               | T_ROR T_A T_COMMA error
               | T_ROR T_B T_COMMA error
               | T_ROR T_C T_COMMA error
               | T_ROR T_D T_COMMA error
               
               | T_ROR error T_COMMA T_A
               | T_ROR error T_COMMA T_B
               | T_ROR error T_COMMA T_C
               | T_ROR error T_COMMA T_D
               
               | T_ROR error T_COMMA error;
			   
               
ldb_instruction: T_LDB T_A T_COMMA imm { emit8(LDB_A_IMM); emit8($4); }
			   | T_LDB T_A T_COMMA mem { emit8(LDB_A_MEM); emit16($4); }
			   | T_LDB T_B T_COMMA imm { emit8(LDB_B_IMM); emit8($4); }
			   | T_LDB T_B T_COMMA mem { emit8(LDB_B_MEM); emit16($4); }
			   | T_LDB T_C T_COMMA imm { emit8(LDB_C_IMM); emit8($4); }
			   | T_LDB T_C T_COMMA mem { emit8(LDB_C_MEM); emit16($4); }
			   | T_LDB T_D T_COMMA imm { emit8(LDB_D_IMM); emit8($4); }
			   | T_LDB T_D T_COMMA mem { emit8(LDB_B_MEM); emit16($4); }
               
               | T_LDB T_A T_COMMA error
               | T_LDB T_B T_COMMA error
               | T_LDB T_C T_COMMA error
               | T_LDB T_D T_COMMA error
               
               | T_LDB error T_COMMA T_A
               | T_LDB error T_COMMA T_B
               | T_LDB error T_COMMA T_C
               | T_LDB error T_COMMA T_D
               
               | T_LDB error T_COMMA error;
               
			   
stb_instruction: T_STB mem T_COMMA T_A { emit8(STB_MEM_A); emit16($2); }
			   | T_STB mem T_COMMA T_B { emit8(STB_MEM_B); emit16($2); }
			   | T_STB mem T_COMMA T_C { emit8(STB_MEM_C); emit16($2); }
			   | T_STB mem T_COMMA T_D { emit8(STB_MEM_D); emit16($2); }
			   | T_STB mem T_COMMA imm { emit8(STB_MEM_IMM); emit16($2); emit8($4); }
               
               | T_STB mem T_COMMA error
               | T_STB error T_COMMA T_A
               | T_STB error T_COMMA T_B
               | T_STB error T_COMMA T_C
               | T_STB error T_COMMA T_D
               | T_STB error T_COMMA imm
               | T_STB error T_COMMA error;
               
		
mvb_instruction: T_MVB T_A T_COMMA T_B { emit8(MVB_A_B); }
		       | T_MVB T_A T_COMMA T_C { emit8(MVB_A_C); }
		       | T_MVB T_A T_COMMA T_D { emit8(MVB_A_D); }
		       | T_MVB T_B T_COMMA T_A { emit8(MVB_B_A); }
		       | T_MVB T_B T_COMMA T_C { emit8(MVB_B_C); }
		       | T_MVB T_B T_COMMA T_D { emit8(MVB_B_D); }
		       | T_MVB T_C T_COMMA T_A { emit8(MVB_C_A); }
		       | T_MVB T_C T_COMMA T_B { emit8(MVB_C_B); }
		       | T_MVB T_C T_COMMA T_D { emit8(MVB_C_D); }
		       | T_MVB T_D T_COMMA T_A { emit8(MVB_D_A); }
		       | T_MVB T_D T_COMMA T_B { emit8(MVB_D_B); }
		       | T_MVB T_D T_COMMA T_C { emit8(MVB_D_C); }
			   
			   | T_MVB T_A T_COMMA T_F { emit8(MVB_A_F); }
			   | T_MVB T_B T_COMMA T_F { emit8(MVB_B_F); }
			   | T_MVB T_C T_COMMA T_F { emit8(MVB_C_F); }
			   | T_MVB T_D T_COMMA T_F { emit8(MVB_D_F); }
               
			   | T_MVB T_F T_COMMA T_A { emit8(MVB_F_A); }
			   | T_MVB T_F T_COMMA T_B { emit8(MVB_F_B); }
			   | T_MVB T_F T_COMMA T_C { emit8(MVB_F_C); }
			   | T_MVB T_F T_COMMA T_D { emit8(MVB_F_D); }
               
               | T_MVB T_A T_COMMA error
               | T_MVB T_B T_COMMA error
               | T_MVB T_C T_COMMA error
               | T_MVB T_D T_COMMA error
               | T_MVB T_F T_COMMA error
               
               | T_MVB error T_COMMA T_A
               | T_MVB error T_COMMA T_B
               | T_MVB error T_COMMA T_C
               | T_MVB error T_COMMA T_D
               | T_MVB error T_COMMA T_F;
			   
		
jez_instruction: T_JEZ mem { emit8(JEZ_MEM); emit16($2); }
               | T_JEZ T_JUMP { emitJump(JEZ_MEM, $2); }
               | T_JEZ error;

jgz_instruction: T_JGZ mem { emit8(JGZ_MEM); emit16($2); }
               | T_JGZ T_JUMP { emitJump(JGZ_MEM, $2); }
               | T_JGZ error;

jcs_instruction: T_JCS mem { emit8(JCS_MEM); emit16($2); }
               | T_JCS T_JUMP { emitJump(JCS_MEM, $2); }
               | T_JCS error;
		
push_instruction: T_PUSH T_A  { emit8(PUSH_A); }
			    | T_PUSH T_B  { emit8(PUSH_B); }
			    | T_PUSH T_C  { emit8(PUSH_C); }
			    | T_PUSH T_D  { emit8(PUSH_D); }
			    | T_PUSH T_F  { emit8(PUSH_F); }
			    | T_PUSH T_IP { emit8(PUSH_IP); }
			    | T_PUSH mem  { emit8(PUSH_MEM); emit16($2); }
			    | T_PUSH imm  { emit8(PUSH_IMM); emit8($2); }
                | T_PUSH error;
				
pop_instruction: T_POP     { emit8(POP_DISCARD); }
			   | T_POP T_A { emit8(POP_A); }
			   | T_POP T_B { emit8(POP_B); }
			   | T_POP T_C { emit8(POP_C); }
			   | T_POP T_D { emit8(POP_D); }
			   | T_POP T_F { emit8(POP_F); }
               | T_POP error;
				
dref_instruction: T_DREF T_AB T_COMMA T_A { emit8(DEREF_AB_A); }
				| T_DREF T_CD T_COMMA T_C { emit8(DEREF_CD_C); }
                | T_DREF T_AB T_COMMA error
                | T_DREF T_CD T_COMMA error;
                
imm: T_POUND   expression { $$ = $2; };
mem: T_PERCENT expression { $$ = $2; };
	
number: T_DEC
      | T_HEX
      | T_BIN;
	  
expression: number { $$ = $1; }
          | T_TEXT
		  {
			  bool found = false;
			  
			  for (int i = 0; i < (UCHAR_MAX + 1); ++i)
			  {
				  if (strcmp(definitions.list[i].name, $1) == 0)
				  {
					  $$ = definitions.list[i].value;
					  found = true;
					  break;
				  }
			  }
					  
			  if (!found)
			  {
                  yyerror("Variable %s is undefined", $1);
			  }
		  }
          | expression T_PLUS     error
          | expression T_MINUS    error
          | expression T_MULTIPLY error
          | expression T_DIVIDE   error
          | expression T_BSHL     error
          | expression T_BSHR     error
          | expression T_BAND     error
          | expression T_BLOR     error
          | expression T_BXOR     error
          |            T_BNOT     error
          | error      T_BNOT
          
		  | expression T_PLUS     expression { $$ =  $1 +  $3; }
		  | expression T_MINUS    expression { $$ =  $1 -  $3; }
		  | expression T_MULTIPLY expression { $$ =  $1 *  $3; }
		  | expression T_DIVIDE   expression { $$ =  $1 /  $3; }
		  | expression T_BSHL     expression { $$ =  $1 << $3; }
		  | expression T_BSHR     expression { $$ =  $1 >> $3; }
		  | expression T_BAND     expression { $$ =  $1 &  $3; }
		  | expression T_BLOR     expression { $$ =  $1 |  $3; }
		  | expression T_BXOR     expression { $$ =  $1 ^  $3; }
		  |            T_BNOT     expression { $$ = ~$2;       }
		  | T_LEFT expression T_RIGHT        { $$ =  $2;       }
		  
%%

int main(int argc, const char** argv)
{
#define file
//#define dbg
	
#if defined dbg
	yydebug = 1;
#endif
	
	const char* fmt = "[Error] File %s could not be opened for %s.\nExiting...\n";
	
#if defined file
	const char* filepath = argv[1];
	const char* filename = strtok(strdup(filepath), ".");
	FILE* fp = fopen(filepath, "r");
	
	
	fseek(fp, 0L, SEEK_END);
	size_t size = ftell(fp);
	rewind(fp);
	char* buffer = malloc(size);
	fread(buffer, sizeof(char), size, fp);
	fclose(fp);
	
	
	char* processed = process(buffer, filepath);
	
	const char* newfilepath = strcat(strdup(filename), ".i");
	
	FILE* out = fopen(newfilepath, "w");
	fwrite(processed, sizeof(char), strlen(processed), out);
	fclose(out);
	
	FILE* final = fopen(newfilepath, "r");
	

	if (!final)
	{
        fprintf(stderr, fmt, filepath, "reading");
	}
#if defined dbg
	else
	{
        printf("Reading...\n");
	}
#endif
	
	yyin = final;
#elif defined in
	yyin = stdin;
#endif
	
#if defined dbg
	printf("Parsing...\n");
#endif
    
	do
	{
		yyparse();
	} while (!feof(yyin));
	
#if defined dbg
	printf("Patching...\n");
#endif
    
	for (int i = 0; i < referenced_labels.addr; ++i)
	{
		Label referenced_label = referenced_labels.list[i];
		bool found = false;
		
		for (int j = 0; j < defined_labels.addr; ++j)
		{
			Label defined_label = defined_labels.list[j];
			
			if (strcmp(defined_label.name, referenced_label.name) == 0)
			{
				code.addr = referenced_label.addr + 1;
				emit16(defined_label.addr);
				found = true;
				break;
			}
		}
		
		if (!found)
		{
            fprintf(stderr, "[Error] Label %s is undefined\n", referenced_label.name);
		}
	}
	
	const char* outfile = strcat((char*)filename, ".o");
	FILE* output = fopen(outfile, "w");
	
#if defined dbg
    printf("Writing...\n");
#endif
	
	if (!output)
	{
        fprintf(stderr, fmt, outfile, "writing");
	}
	
	fwrite(&code.bytes[0], sizeof(code.bytes[0]), (USHRT_MAX + 1), output);
	
}
                                               
void yyerror(const char* s, ...)
{
    va_list args;
    va_start(args, s);
    fprintf(stderr, "Parse Error: ");
    vfprintf(stderr, s, args);
    fputs("\n", stderr);
    va_end(args);
    exit(1);
}
	
