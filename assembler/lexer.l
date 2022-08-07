%option warn nodefault noinput nounput noyywrap

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define YY_DECL int yylex()

#define CAPTURE_I_LMI(n, m) substr(strdup(yytext), n, (strlen(yytext) - m))

#include "parser.tab.h"
	
char* substr(const char *src, int m, int n)
{
	// get the length of the destination string
	int len = n - m;
 
	// allocate (len + 1) chars for destination (+1 for extra null character)
	char *dest = (char*)malloc(sizeof(char) * (len + 1));
 
	// extracts characters between m'th and n'th index from source string
	// and copy them into the destination string
	for (int i = m; i < n && (*(src + i) != '\0'); i++)
	{
		*dest = *(src + i);
		dest++;
	}
 
	// null-terminate the destination string
	*dest = '\0';
 
	// return the destination string
	return dest - len;
}
	 
%}

%%
    
[ \t]       ; //whitespace is skipped
[0-9]+      { yylval.ival = strtol(CAPTURE_I_LMI(0, 0), NULL, 10); return T_DEC; }
\$[0-9a-f]+ { yylval.ival = strtol(CAPTURE_I_LMI(1, 0), NULL, 16); return T_HEX; }
0b[0-1]+    { yylval.ival = strtol(CAPTURE_I_LMI(2, 0), NULL, 2);  return T_BIN; }

\n   { return T_NEWLINE;   }
"+"  { return T_PLUS;      }
"-"  { return T_MINUS;     }
"*"  { return T_MULTIPLY;  }
"/"  { return T_DIVIDE;    }
"<<" { return T_BSHL;      }
">>" { return T_BSHR;      }
"&"  { return T_BAND;      }
"~"  { return T_BNOT;      }
"|"  { return T_BLOR;      }
"^"  { return T_BXOR;      }
"("  { return T_LEFT;      }
")"  { return T_RIGHT;     }
","  { return T_COMMA;     }
"#"  { return T_POUND;     }
"%"  { return T_PERCENT;   }
"="  { return T_EQUALS;    }
">"  { return T_CARAT;     }
":"  { return T_COLON;     }


;[^\r\n]*               {                                    return T_COMMENT; }
\@[a-zA-Z][a-zA-Z_]+\:  { yylval.cval = CAPTURE_I_LMI(1, 1); return T_LABEL;   }
\"(([^\\\"]|\\.)*)\"    { yylval.cval = CAPTURE_I_LMI(1, 1); return T_STRING;  }
\[[a-zA-Z][a-zA-Z_]+\]  { yylval.cval = CAPTURE_I_LMI(1, 1); return T_JUMP;    }
\{[^\}]*\}              { yylval.cval = CAPTURE_I_LMI(1, 1); return T_BLOCK;   }

".org"     { return T_DORG;     }
".define"  { return T_DDEFINE;  }
".byte"    { return T_DBYTE;    }
".word"    { return T_DWORD;    }
".ascii"   { return T_DASCII;   }
".begin"   { return T_DBEGIN;   }

"r0-1" { return T_AB; }
"r2-3" { return T_CD; }

"r0"    { return T_A;   }
"r1"    { return T_B;   }
"r2"    { return T_C;   }
"r3"    { return T_D;   }
"flags" { return T_F;   }
"ip"    { return T_IP;  }

"nop"  { return T_NOP;  }
"brk"  { return T_BRK;  }
"adc"  { return T_ADC;  }
"sbb"  { return T_SBB;  }
"and"  { return T_AND;  }
"or"   { return T_LOR;  }
"not"  { return T_NOT;  }
"rol"  { return T_ROL;  }
"ror"  { return T_ROR;  }
"ldb"  { return T_LDB;  }
"stb"  { return T_STB;  }
"mvb"  { return T_MVB;  }
"jez"  { return T_JEZ;  }
"jgz"  { return T_JGZ;  }
"jcs"  { return T_JCS;  }
"push" { return T_PUSH; }
"pop"  { return T_POP;  }
"dref" { return T_DREF; }

[a-zA-Z][a-zA-Z_]* { yylval.cval = CAPTURE_I_LMI(0, 0); return T_TEXT; }


%%
