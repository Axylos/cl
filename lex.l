/*
Solaris 2.8, probably original AT&T Bell Labs lex, needed this:
*/
%a 10000
%o 10000
%{
/*
	Copyright (C) 2007-2009, Bruce Ediger

    This file is part of cl.

    cl is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    cl is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with cl; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*/

/* $Id: lex.l,v 1.41 2011/05/22 23:30:06 bediger Exp $ */


#include <stdio.h>
#include <stdlib.h>
#include <errno.h>    /* errno */
#include <string.h>   /* strlen(), strerror() */

#include <hashtable.h>
#include <atom.h>
#include <node.h>
#include <parser.h>

#include "y.tab.h"
int lineno = 0;

const char *current_input_stream;

char *unescape_string(char *s);
void  push_and_open(const char *filename);

struct stream_node {
#ifdef FLEX_SCANNER   
	YY_BUFFER_STATE stream;
#else
	FILE *stream;
#endif
	struct stream_node *next;
	const char *old_filename;
	int old_lineno;
};

struct stream_node *file_stack = NULL;

void set_yyin_stdin(void);
void reset_yyin(void);
void set_yyin(const char *filename);
int possible_combinator_decision(enum primitiveName potential_combinator);

extern int as_combinator[];

extern int found_binary_command;
extern int look_for_algorithm;
extern int looking_for_filename;

extern int prompting;
int old_prompting = -1;


	extern FILE *yyin;
	extern int lineno;
	extern const char *current_input_stream;
%}

%%

\#.*$		{ return TK_EOL; }
\n		    { return TK_EOL; }
\\\n	    { /* Just eat it. */ }
\(		    { return TK_LPAREN; }
\)		    { return TK_RPAREN; }
\[		    { return TK_LBRACK; }
]		    { return TK_RBRACK; }
\,          { return TK_COMMA; }
"def"       { return TK_DEF; }
"define"    { return TK_DEF; }
"reduce"    { return TK_REDUCE; }
"redexes"    { return TK_COUNT_REDUCTIONS; }
"timer"     { yylval.command = TIME_O; return TK_COMMAND; }
"cycles"    { yylval.command = CYCLES_O; return TK_COMMAND; }
"timeout"   { return TK_TIMEOUT; }
"debug"     { yylval.command = DEBUG_O; return TK_COMMAND; }
"step"      { yylval.command = STEP_O; return TK_COMMAND; }
"trace"     { yylval.command = TRACE_O; return TK_COMMAND; }
"detect"    { yylval.command = DETECT_O; return TK_COMMAND; }
"cleanup"   { yylval.command = CLEANUP_O; return TK_COMMAND; }
"load"      { return TK_LOAD; }
"abstraction" { return TK_SET_BRACKET_ABSTRACTION; }
"count" { return TK_MAX_COUNT; }
"print" { return TK_PRINT; }
"printc" { return TK_CANONICALIZE; }
"size" { return TK_SIZE; }
"length" { return TK_LENGTH; }
"match"    { return TK_MATCH; }
"unmatch"    { return TK_UNMATCH; }
"on"|"off" {
	const char *p = Atom_string(yytext);
	if (found_binary_command)
	{
		yylval.string_constant = p;
		return BINARY_MODIFIER;
	} else if (looking_for_filename) {
		yylval.string_constant = p;
		return FILE_NAME;
	} else {
		yylval.identifier = p;
		return TK_IDENTIFIER;
	}
}
[0-9][0-9]* { yylval.numerical_constant = strtol(yytext, NULL, 10);
				return NUMERICAL_CONSTANT; }
\"(\\.|[^\\"])*\" {
	/* quoted string, for file names with spaces, escaped characters, etc */
	char *tmp;
	tmp = unescape_string(yytext);
	yylval.string_constant = Atom_string(tmp);
	free(tmp);
	return FILE_NAME;
}
S { return possible_combinator_decision(COMB_S); }
K { return possible_combinator_decision(COMB_K); }
I { return possible_combinator_decision(COMB_I); }
B { return possible_combinator_decision(COMB_B); }
C { return possible_combinator_decision(COMB_C); }
W { return possible_combinator_decision(COMB_W); }
T { return possible_combinator_decision(COMB_T); }
M { return possible_combinator_decision(COMB_M); }
J { return possible_combinator_decision(COMB_J); }
\* { yylval.identifier = Atom_string(yytext);
	return TK_IDENTIFIER;
	/* Previously: Ignore asterisks in input: output uses them to mark reducible atoms .*/
}

= { return TK_EQUALS; }
"curry"|"curry2"|"turner"|"grz"|"tromp"|"btmk"|"church" {
	yylval.identifier = Atom_string(yytext);
	if (look_for_algorithm)
		return TK_ALGORITHM_NAME;
	return TK_IDENTIFIER;
}

[a-zA-Z_][a-zA-Z_0-9]* {
	if (looking_for_filename)
	{
		yylval.string_constant = Atom_string(yytext);
		return FILE_NAME;
	} else {
		yylval.identifier = Atom_string(yytext);
		return TK_IDENTIFIER;
	}
}

(\/*[a-zA-Z_0-9\.:][a-zA-Z_0-9\.:]*)(\/[a-zA-Z0-9_\.:][a-zA-Z0-9_\.:]*)* {
	yylval.string_constant = Atom_string(yytext);
	return FILE_NAME;
}
.		    { /* Just eat it. */ }

%%

char *
unescape_string(char *s)
{
	char *n = NULL;
	if (s)
	{
		int i, j, l;
		if ('"' == s[0])
			++s;
		if ('"' == s[strlen(s) - 1])
			s[strlen(s) - 1] = '\0';
		n = malloc(strlen(s) + 1);
		l = strlen(s);
		for (i = 0, j = 0; i < l; ++i)
		{
			if ('\\' == s[i])
			{
				++i;
				switch (s[i])
				{
				/* XXX - doesn't do '\0' or other numerical escapes */
				case 't': n[j++] = '\t';  break;
				case 'r': n[j++] = '\r';  break;
				case 'n': n[j++] = '\n';  break;
				case '\\': n[j++] = '\\'; break;
				default:
					n[j++] = s[i];
					break;
				}
			} else {
				n[j++] = s[i];
			}
		}
		n[j] = '\0';
	}
	return n;
}

void
push_and_open(const char *filename)
{
	FILE *fin;

	if (NULL != (fin = fopen(filename, "r")))
	{
		struct stream_node *n;
		n = malloc(sizeof(*n));
#ifdef FLEX_SCANNER
		n->stream = YY_CURRENT_BUFFER;
		yyin = fin;
		yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));
#else
		n->stream = yyin;
		yyin = fin;
#endif
		n->next = file_stack;
		n->old_filename = current_input_stream;
		n->old_lineno = lineno;
		current_input_stream = filename;
		file_stack = n;
		lineno = 0;
		if (old_prompting < 0)
			old_prompting = prompting;
		prompting = 0;
	} else {
		fprintf(stderr, "Could not open \"%s\" for read: %s\n",
			filename, strerror(errno));
	}
}

void
set_yyin_stdin(void)
{
		yyin = stdin;
#ifdef FLEX_SCANNER
		yy_delete_buffer(YY_CURRENT_BUFFER);
		yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));
#endif
}

void
set_yyin(const char *filename)
{
	FILE *fin;

	if (NULL != (fin = fopen(filename, "r")))
	{
		yyin = fin;
#ifdef FLEX_SCANNER
		yy_delete_buffer(YY_CURRENT_BUFFER);
		yy_switch_to_buffer(yy_create_buffer(yyin, YY_BUF_SIZE));
#endif
		current_input_stream = filename;
		lineno = 0;
	} else {
		fprintf(stderr, "Could not open \"%s\" for read: %s\n",
			filename, strerror(errno));
	}
}

void
reset_yyin(void)
{
	if (yyin)
		fclose(yyin);
	yyin = NULL;
#ifdef FLEX_SCANNER
	yy_delete_buffer(YY_CURRENT_BUFFER);
#endif
}

int
yywrap()
{
	int r = 1;
	if (file_stack)
	{
		struct stream_node *tmp = file_stack->next;
		fclose(yyin);
#ifdef FLEX_SCANNER
		yy_delete_buffer(YY_CURRENT_BUFFER);
		yy_switch_to_buffer(file_stack->stream);
#else
		yyin = file_stack->stream;
#endif
		current_input_stream = file_stack->old_filename;
		lineno = file_stack->old_lineno;
		file_stack->stream = NULL;
		file_stack->next = NULL;
		free(file_stack);
		file_stack = tmp;
		r = 0;
	}
	if (!file_stack)
	{
		if (old_prompting > 0)
		{
			prompting = 1;
			old_prompting = -1;
			printf("CL> ");
		}
	}
	return r;
}

int
possible_combinator_decision(enum primitiveName potential_combinator)
{
	int treat_as_combinator = as_combinator[potential_combinator];
	int r = TK_IDENTIFIER;

	if (treat_as_combinator)
	{
		yylval.cn = potential_combinator;
		r = TK_PRIMITIVE;
	} else {
		yylval.identifier = Atom_string(yytext);
		r = TK_IDENTIFIER;
	}

	/* This overrides the other two cases, I believe */
	if (looking_for_filename)
	{
		yylval.string_constant = Atom_string(yytext);
		return FILE_NAME;
	}

	return r;
 }
