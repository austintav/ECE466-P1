%{
#include <stdio.h>
#include "llvm-c/Core.h"
#include "llvm-c/BitReader.h"
#include "llvm-c/BitWriter.h"
#include <string.h>

#include "uthash.h"

#include <errno.h>
  //#include <search.h>

extern FILE *yyin;
int yylex(void);
int yyerror(const char *);

extern char *fileNameOut;

extern LLVMModuleRef Module;
extern LLVMContextRef Context;

LLVMValueRef Function;
LLVMBasicBlockRef BasicBlock;
LLVMBuilderRef Builder;

int params_cnt=0;
int compare;

struct TmpMap{
  char *key;                  /* key */
  LLVMValueRef val;                /* data */
  UT_hash_handle hh;         /* makes this structure hashable */
};
 

struct TmpMap *map = NULL;    /* important! initialize to NULL */

void add_tmp(char *tmp, LLVMValueRef val) { 
  struct TmpMap *s; 
  s = malloc(sizeof(struct TmpMap)); 
  s->key = strdup(tmp); 
  s->val = val; 
  HASH_ADD_KEYPTR( hh, map, s->key, strlen(s->key), s ); 
}

LLVMValueRef get_val(char *tmp) {
  struct TmpMap *s;
  HASH_FIND_STR( map, tmp, s );  /* s: output pointer */
  if (s) 
    return s->val;
  else 
    return NULL; // returns NULL if not found
}

//add_tmp("tmpvar",0);

%}

%union {
  char *tmp;
  int num;
  char *id;
  LLVMValueRef val;
}

%token ASSIGN SEMI COMMA MINUS PLUS VARS COLON LESSTHAN RAISE QUESTION
%token <tmp> TMP 
%token <num> NUM 
%token <id> ID
%type <val> expr stmt stmtlist;

%nonassoc QUESTION COLON
%left LESSTHAN
%left PLUS MINUS
%left MULTIPLY DIVIDE RAISE

%start program

%%
program: decl stmtlist 
{ 
  /* 
    IMPLEMENT: return value
  */
	//LLVMBuildRet(Builder,tmpvar);
	LLVMBuildRet(Builder,LLVMConstInt(LLVMInt64Type(),0,0));
	//return 0;  
}
  ;

decl: VARS varlist SEMI 
{  
  /* NO NEED TO CHANGE ANYTHING IN THIS RULE */

  /* Now we know how many parameters we need.  Create a function type
     and add it to the Module */

  LLVMTypeRef Integer = LLVMInt64TypeInContext(Context);

  LLVMTypeRef *IntRefArray = malloc(sizeof(LLVMTypeRef)*params_cnt);
  int i;
  
  /* Build type for function */
  for(i=0; i<params_cnt; i++)
    IntRefArray[i] = Integer;

  LLVMBool var_arg = 0; /* false */
  LLVMTypeRef FunType = LLVMFunctionType(Integer,IntRefArray,params_cnt,var_arg);

  /* Found in LLVM-C -> Core -> Modules */
  char *tmp, *out = fileNameOut;

  if ((tmp=strchr(out,'.'))!='\0')
    {
      *tmp = 0;
    }

  /* Found in LLVM-C -> Core -> Modules */
  Function = LLVMAddFunction(Module,out,FunType);

  /* Add a new entry basic block to the function */
  BasicBlock = LLVMAppendBasicBlock(Function,"entry");

  /* Create an instruction builder class */
  Builder = LLVMCreateBuilder();

  /* Insert new instruction at the end of entry block */
  LLVMPositionBuilderAtEnd(Builder,BasicBlock);
}
;

varlist:   varlist COMMA ID 
{
  /* IMPLEMENT: remember ID and its position so that you can
     reference the parameter later
   */
  
  printf("%d \n",params_cnt);
  params_cnt++;
}
	| ID
{
  /* IMPLEMENT: remember ID and its position for later reference*/
  params_cnt++;
}
;

stmtlist:  stmtlist stmt { $$ = $2; }
| stmt                   { $$ = $1; }
;         

stmt: TMP ASSIGN expr SEMI
{
  /* IMPLEMENT: remember temporary and associated expression $3 */
  $$ = $3;
	LLVMValueRef addr = get_val($1);
	if (addr==NULL)
	{
		add_tmp("tmpVar", $$);
	}
}
;

expr:   expr MINUS expr
{
  /* IMPLEMENT: subtraction */
 $$ = LLVMBuildSub(Builder,$1,$3,"sub");
} 
     | expr PLUS expr
{
  /* IMPLEMENT: addition */
  $$ = LLVMBuildAdd(Builder,$1,$3,"add");
}
      | MINUS expr 
{
  /* IMPLEMENT: negation */
	$$ = LLVMBuildNeg(Builder,$2,"neg");
}
      | expr MULTIPLY expr
{
  /* IMPLEMENT: multiply */
	$$ = LLVMBuildMul(Builder,$1,$3,"mult");
}
      | expr DIVIDE expr
{
  /* IMPLEMENT: divide */
	$$ = LLVMBuildSDiv(Builder,$1,$3,"div");
	if($3 == 0){
		yyerror("DIV BY ZERO\n");
	}

  printf("DIVIDE\n");
}
      | expr LESSTHAN expr
{
  /* IMPLEMENT: less than */
	//add_tmp("cond",LLVMBuildICmp(Builder,'<',$1,$3,"compare"));
	$$ = LLVMBuildZExt(Builder,0,LLVMInt64Type(),"intcast");
}
      | expr RAISE expr
{
  /* IMPLEMENT: raise */
/*
	int a;
	char str[15] = "0";
	
	for( a = 0; a < $3; a = a + 1){
		int b = a + 1;
		LLVMBuildMul(Builder,tempPro,$1,"multiply");
	}
*/
	$$ = LLVMBuildMul(Builder,$1,$3,"raise");
}
      | expr QUESTION expr
{
  /* IMPLEMENT: QUESTION */
	compare = LLVMBuildICmp(Builder,'=',$1,LLVMConstInt(LLVMInt64Type(),1,0),"quest");
}      
	  | expr COLON expr
{
  /* IMPLEMENT: colon */
	$$ = LLVMBuildSelect(Builder,LLVMConstInt(LLVMInt64Type(),compare,0),$1,$3,"select");
}
      | NUM
{ 
  /* IMPLEMENT: constant */
  printf("$1:%d  \n", $1);
	$$ = LLVMConstInt(LLVMInt64Type(),$1,0);
}
      | ID
{
  /* IMPLEMENT: get reference to function parameter
     Hint: LLVMGetParam(...)
   */
	$$  = LLVMGetParam(Function,params_cnt);
}
      | TMP
{
  /* IMPLEMENT: get expression associated with TMP */
	//$$ = get_val("tmpvar");
	$$ = get_val($1);
}
;

%%


void initialize()
{
  /* IMPLEMENT: add something here if needed */
}

int yyerror(const char *msg)
{
  printf("%s",msg);
  return 0;
}
