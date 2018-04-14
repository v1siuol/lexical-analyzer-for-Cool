/**
 * FILE        : cool.flex
 * 
 * DESCRIPTION : This is a cirrect and working lexer for Cool in the C++ version.
 *
 * AUTHOR      : Zhaohong Lyu (v1siuol)
 * 
 * DATE        : 14 Apr 2018
 */

/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */

%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
    YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

/* count nested comments */
int comment_layer = 0;

int buf_str_count = 0;
%}

/* start conditions */
%x COMMENT_SINGLE COMMENT_MULTI STRING STRERROR


/*
 * Define names for regular expressions here.
 */

/* keywords */
CLASS          [cC][lL][aA][sS][sS]
ELSE           [eE][lL][sS][eE]
FI             [fF][iI]
IF             [iI][fF]
IN             [iI][nN]
INHERITS       [iI][nN][hH][eE][rR][iI][tT][sS]
LET            [lL][eE][tT]
LOOP           [lL][oO][oO][pP]
POOL           [pP][oO][oO][lL]
THEN           [tT][hH][eE][nN]
WHILE          [wW][hH][iI][lL][eE]
CASE           [cC][aA][sS][eE]
ESAC           [eE][sS][aA][cC]
OF             [oO][fF]
NEW            [nN][eE][wW]
ISVOID         [iI][sS][vV][oO][iI][dD]
NOT            [nN][oO][tT] 
TRUE           t[rR][uU][eE] 
FALSE          f[aA][lL][sS][eE]

/* basic */
INTEGER        [0-9]+
NEWLINE        "\n"
WHITESPACE     [ \f\r\t\v]
STRING_REG     [0-9a-zA-Z_]*
/* all allowed single character symbols */
SYMBOL         [:;{}().+\-*/<,~@=]  

/* cool */
DARROW         =>
OBJECTID       [a-z]{STRING_REG}
TYPEID         [A-Z]{STRING_REG}
SELFID         "self"
SELF_TYPEID    "SELF_TYPE"


%%

 /*
  *  Nested comments
  */

<INITIAL>--                       { BEGIN(COMMENT_SINGLE); }

<COMMENT_SINGLE>.*                ; /* eat anything that's not a '\n' */ 

<COMMENT_SINGLE>\n                {
                                  curr_lineno++;
                                  BEGIN(INITIAL);
                                  }

<COMMENT_SINGLE><<EOF>>           { yyterminate(); }


<INITIAL>"(*"                     { 
                                  BEGIN(COMMENT_MULTI);
                                  comment_layer++;
                                  }

<INITIAL>"*)"                     {
                                  cool_yylval.error_msg = "Unmatched *)";
                                  return ERROR;
                                  }

<COMMENT_MULTI>"("+"*"            { comment_layer++; }

<COMMENT_MULTI>"*"+")"            {  
                                  comment_layer--;
                                  if (comment_layer == 0)
                                    {
                                      BEGIN(INITIAL);
                                    }
                                  }

<COMMENT_MULTI>\n                 { curr_lineno++; }

<COMMENT_MULTI>"("+[^(*\n]*       ; /* eat up （'s not followed by '*'s */
<COMMENT_MULTI>"*"+[^*)\n]*       ; /* eat up '*'s not followed by ')'s */
<COMMENT_MULTI>[^*(\n]*           ; /* eat up string comments */

<COMMENT_MULTI><<EOF>>            {
                                  cool_yylval.error_msg = "EOF in comment";
                                  BEGIN(INITIAL);
                                  return ERROR;
                                  }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */     

<INITIAL>\"                 {
                            string_buf_ptr = string_buf;
                            buf_str_count = 0;
                            BEGIN(STRING);
                            }

<STRING>\"                  {   /* saw closing quote - all done */

                            /* return string constant token type and
                             * value to parser
                             */
                            *string_buf_ptr = '\0';
                            cool_yylval.symbol = stringtable.add_string(string_buf);
                            buf_str_count = 0;
                            BEGIN(INITIAL); 
                            return STR_CONST;
                            }

<STRING>\\b                 {  
                            if(buf_str_count  >= MAX_STR_CONST)
                              {
                              cool_yylval.error_msg = "String constant too long";
                              BEGIN(STRERROR);
                              return ERROR;
                              }                                 
                            *string_buf_ptr++ = '\b';
                            buf_str_count++;
                            }

<STRING>\\t                 {  
                            if(buf_str_count  >= MAX_STR_CONST)
                              {
                              cool_yylval.error_msg = "String constant too long";
                              BEGIN(STRERROR);
                              return ERROR;
                              }                                 
                            *string_buf_ptr++ = '\t';
                            buf_str_count++;
                            }       

<STRING>\\n                 { 
                            if(buf_str_count + 1 + 1 > MAX_STR_CONST)
                              {
                              cool_yylval.error_msg = "String constant too long";
                              BEGIN(STRERROR);
                              return ERROR;
                              }                                 
                            *string_buf_ptr++ = '\n';
                            buf_str_count++;
                            }

<STRING>\\f                 {  
                            if(buf_str_count  >= MAX_STR_CONST)
                              {
                              cool_yylval.error_msg = "String constant too long";
                              BEGIN(STRERROR);
                              return ERROR;
                              }                                 
                            *string_buf_ptr++ = '\f';
                            buf_str_count++;
                            }

<STRING>\\\x00              {
                            BEGIN(STRERROR);
                            cool_yylval.error_msg = "String contains escaped null character.";
                            return ERROR;
                            }

<STRING>\\(.|\n)            {
                            if (buf_str_count + 1 + 1 > MAX_STR_CONST) 
                              {
                              cool_yylval.error_msg = "String constant too long";
                              BEGIN(STRERROR);
                              return ERROR;
                              }       
                            *string_buf_ptr++ = yytext[1];  
                            buf_str_count++;                        
                            }                              
   
<STRING>\n                  {  
                            cool_yylval.error_msg = "Unterminated string constant";
                            curr_lineno++;
                            BEGIN(INITIAL); 
                            return ERROR;
                            }

<STRING>\x00                { 
                            BEGIN(STRERROR);
                            cool_yylval.error_msg = "String contains null character.";
                            return ERROR;
                            }    
                    
                 
<STRING>([^"\\\n\x00])+     {
                            if (buf_str_count + strlen(yytext) >= MAX_STR_CONST) 
                              {  
                              cool_yylval.error_msg = "String constant too long";
                              BEGIN(STRERROR);
                              return (ERROR);
                              }
                            char *temp = yytext;
                            while (*temp) 
                              {
                              *string_buf_ptr++ = *temp++;  
                              buf_str_count++;
                              }
                            }

<STRERROR>[^\\]\n           { BEGIN(INITIAL); }
<STRERROR>\"                { BEGIN(INITIAL); }
<STRERROR>(.|\n)            ;


<STRING><<EOF>>             {
                            cool_yylval.error_msg = "EOF in string constant";
                            BEGIN(INITIAL);
                            return ERROR;
                            }


 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */    

<INITIAL>{CLASS}        { return CLASS; } 
<INITIAL>{ELSE}         { return ELSE; }    
<INITIAL>{FI}           { return FI; }
<INITIAL>{IF}           { return IF; }
<INITIAL>{IN}           { return IN; }
<INITIAL>{INHERITS}     { return INHERITS; }
<INITIAL>{LET}          { return LET; }
<INITIAL>{LOOP}         { return LOOP; } 
<INITIAL>{POOL}         { return POOL; } 
<INITIAL>{THEN}         { return THEN; }     
<INITIAL>{WHILE}        { return WHILE; } 
<INITIAL>{CASE}         { return CASE; } 
<INITIAL>{ESAC}         { return ESAC; } 
<INITIAL>{NEW}          { return NEW; }
<INITIAL>{ISVOID}       { return ISVOID; }         
<INITIAL>{OF}           { return OF; } 
<INITIAL>{NOT}          { return NOT; }
<INITIAL>{FALSE}        { 
                        cool_yylval.boolean = false;
                        return BOOL_CONST;
                        }
<INITIAL>{TRUE}         {
                        cool_yylval.boolean = true;
                        return BOOL_CONST;
                        }  


 /*
  *  Operators.
  */               


<INITIAL>{SYMBOL}         { return *yytext; }
<INITIAL>"<="             { return LE; }
<INITIAL>"<-"             { return ASSIGN; }   
<INITIAL>{DARROW}         { return DARROW; } 
<INITIAL>{INTEGER}        {
                          cool_yylval.symbol = inttable.add_string(yytext); 
                          return INT_CONST;
                          }


 /*
 *  Identifiers
 */ 

<INITIAL>{TYPEID}         {
                          cool_yylval.symbol = stringtable.add_string(yytext); 
                          return TYPEID;
                          } 

<INITIAL>{OBJECTID}       {
                          cool_yylval.symbol = stringtable.add_string(yytext); 
                          return OBJECTID;
                          }
                        
<INITIAL>{NEWLINE}        { curr_lineno++; }          
<INITIAL>{WHITESPACE}     ;  /* non keyword simple tokens */

<INITIAL>.                { 
                          cool_yylval.error_msg = yytext;
                          return ERROR;
                          }           

%%