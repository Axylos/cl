/*
	Copyright (C) 2008-2009, Bruce Ediger

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

/* $Id: parser.h,v 1.4 2011/05/22 23:30:06 bediger Exp $ */

/*
 * Enums to allow lexer code (in lex.l) and parser code (in grammar.y) to
 * communicate about which output-control command the parser found.
 * Enum names have a value assigned so as to use them as array indexes, too.
 */

enum OutputModifierCommands {DEBUG_O = 0, TRACE_O = 1, TIME_O = 2, STEP_O = 3, CYCLES_O = 4, DETECT_O = 5, CLEANUP_O = 6};
