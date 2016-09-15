/*
Austin Tavenner
Daniel Black

Description:This is the implementation for project 1, a "simple" IR creator
			We ran into some difficulties with segmentation faults and only trying to
			use the provided hashmap. We resulted in using a linkedlist which allowed
			for the management of the order of variables to become much easier.
Source for linkedlist: http://www.tutorialspoint.com/data_structures_algorithms/linked_list_program_in_c.htm
*/

%{
#include <stdio.h>
#include "llvm-c/Core.h"
#include "llvm-c/BitReader.h"
#include "llvm-c/BitWriter.h"
#include <string.h>

#include "uthash.h"

#include <errno.h>

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
LLVMValueRef final_exp;

//definition of struct for linkedlist
struct node  
{
   int key;
   char *id;
   struct node *next;
};

struct node *head = NULL;

//insert to the front of the linkedlist
void insertFirst(char *id, int key)
{
   //create a link
   struct node *link = (struct node*) malloc(sizeof(struct node));
	
   	link->key = key;
	link->id = id;
	
   //point it to old first node
   link->next = head;
	
   //point first to new first node
   head = link;
}

struct node* find(char *id){

   //start from the first link
   struct node* current = head;

   //if list is empty
   if(head == NULL)
	{
      return NULL;
   }

   //navigate through list
   while(strcmp(current->id, id) != 0){
	
      //if it is last node
      if(current->next == NULL){
         return NULL;
      }else {
         //go to next link
         current = current->next;
      }
   }	
   //if data found, return the current Link
   return current;
}



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

%}

%union {
  char *tmp;
  int num;
  char *id;
  LLVMValueRef val;
}

%token ASSIGN SEMI COMMA MINUS PLUS VARS COLON LESSTHAN RAISE QUESTION MULTIPLY DIVIDE
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
    IMPLEMENT: return value of final expression
	a = 2 + 1
	a = 3
	<3>
  */
	 LLVMBuildRet(Builder,final_exp); 
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
	//add var to linkedlist
	insertFirst($3,params_cnt);
  	params_cnt++;
}
| ID
{
  /* IMPLEMENT: remember ID and its position for later reference*/
	//add var to linkedlist
	insertFirst($1,params_cnt);
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
	
	//manage tmp variables with expr
	add_tmp($1,$3);
	final_exp = $3;
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
	if($3 == 0){
		yyerror("DIVIDE BY ZERO\n");
		abort();
	}
	$$ = LLVMBuildSDiv(Builder,$1,$3,"div");
}
      | expr LESSTHAN expr
{
	/* IMPLEMENT: less than */
	LLVMValueRef less = LLVMBuildICmp(Builder,LLVMIntSLT,$1,$3,"compare");
	$$ = LLVMBuildZExt(Builder,less,LLVMInt64Type(),"intcast");
}

      | expr RAISE expr
{
  /* IMPLEMENT: raise */

	//convert value to int to be used in for loop
	long long b = LLVMConstIntGetSExtValue($3);
	if($1 == 0){
		yyerror("BASE OF ZERO\n");
		abort();
	}
	//divide base by itself to achieve a ValueRef of 1
	LLVMValueRef tempPro = LLVMBuildSDiv(Builder,$1,$1,"div");
	
	//for loop to calculate exponential term
	for(long long a = 0; a < b; a = a + 1){
		tempPro = LLVMBuildMul(Builder,tempPro,$1,"multiply");
	}
	$$ = tempPro;
}

      | expr QUESTION expr COLON expr
{
  /* IMPLEMENT: QUESTION AND COLON*/
	$$ = LLVMBuildSelect(Builder,$1,$3,$5,"select");
} 

      | NUM
{ 
  /* IMPLEMENT: constant */
	$$ = LLVMConstInt(LLVMInt64Type(),$1,0);
}
      | ID
{
  /* IMPLEMENT: get reference to function parameter */

	struct node *temp = find($1);
	if(temp == NULL){
		yyerror("NULL\n");
		abort();
	}
	$$  = LLVMGetParam(Function,temp->key);
}
      | TMP
{
  /* IMPLEMENT: get expression associated with TMP */
	LLVMValueRef n_val = get_val($1);
	if (n_val == NULL) {
		yyerror( "NULL\n" );
		abort();
	}
	$$ = n_val;
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
