'' intrinsic runtime lib ustring functions (var-len UTF-16 strings)
''
'' The ustring twin of rtl-string.bas. Every entry point takes (ptr, size)
'' pairs, where the size discriminates the three forms an argument can take --
'' see FB_USTRSIZEVARLEN in src/rtlib/fb_ustring.h. rtlCalcStrLen() produces
'' that value on the compiler side.

#include once "fb.bi"
#include once "fbint.bi"
#include once "ast.bi"
#include once "rtl.bi"

	dim shared as FB_RTL_PROCDEF funcdata( 0 to ... ) = _
	{ _
		/' function fb_UStrInit( byref dst as any, byval dst_size as const integer, _
				byref src as const any, byval src_size as const integer, _
				byval fillrem as const long = 1 ) as ustring '/ _
		( _
			@FB_RTL_USTRINIT, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 1 ) _
			} _
		), _
		/' function fb_UStrAssign( ... ) as ustring '/ _
		( _
			@FB_RTL_USTRASSIGN, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 1 ) _
			} _
		), _
		/' sub fb_UStrDelete( byref str as const ustring ) '/ _
		( _
			@FB_RTL_USTRDELETE, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( typeSetIsConst( FB_DATATYPE_USTRING ), FB_PARAMMODE_BYREF, FALSE ) _
			} _
		), _
		/' function fb_hUStrDelTemp( byref str as const ustring ) as long '/ _
		( _
			@FB_RTL_HUSTRDELTEMP, NULL, _
			FB_DATATYPE_LONG, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( typeSetIsConst( FB_DATATYPE_USTRING ), FB_PARAMMODE_BYREF, FALSE ) _
			} _
		), _
		/' function fb_UStrConcat( byref dst as ustring, _
				byref str1 as const any, byval str1_size as const integer, _
				byref str2 as const any, byval str2_size as const integer ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCAT, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrConcatAssign( ... ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCATASSIGN, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 1 ) _
			} _
		), _
		/' function fb_UStrCompare( byref str1 as const any, byval str1_size as const integer, _
				byref str2 as const any, byval str2_size as const integer ) as long '/ _
		( _
			@FB_RTL_USTRCOMPARE, NULL, _
			FB_DATATYPE_LONG, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrLen( byref str as const any, byval str_size as const integer ) as integer '/ _
		( _
			@FB_RTL_USTRLEN, NULL, _
			FB_DATATYPE_INTEGER, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrAssignFromA( byref dst as any, byval dst_size as const integer, _
				byref src as const any, byval src_size as const integer, _
				byval fillrem as const long, byval is_init as const long ) as ustring '/ _
		( _
			@FB_RTL_USTRASSIGNFROMA, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			6, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ) _
			} _
		), _
		/' function fb_UStrAssignToA( ... ) as string '/ _
		( _
			@FB_RTL_USTRASSIGNTOA, NULL, _
			FB_DATATYPE_STRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			6, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ) _
			} _
		), _
		/' function fb_StrToUStr( byref src as const any, byval src_size as const integer ) as ustring '/ _
		( _
			@FB_RTL_STR2USTR, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrToStr( byref src as const any, byval src_size as const integer ) as string '/ _
		( _
			@FB_RTL_USTR2STR, NULL, _
			FB_DATATYPE_STRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrConcatAU( byref dst as ustring, ... ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCATAU, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrConcatUA( byref dst as ustring, ... ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCATUA, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrAllocTempResult( byref src as ustring ) as ustring '/ _
		( _
			@FB_RTL_USTRALLOCTEMPRES, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ) _
			} _
		), _
		/' function fb_UStrAssignFromW( byref dst as any, byval dst_size as const integer, _
				byval src as const wstring ptr, byval fillrem as const long, _
				byval is_init as const long ) as ustring '/ _
		( _
			@FB_RTL_USTRASSIGNFROMW, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeAddrOf( typeSetIsConst( FB_DATATYPE_WCHAR ) ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ) _
			} _
		), _
		/' function fb_UStrAssignToW( byval dst as wstring ptr, byval dst_chars as const integer, _
				byref src as const any, byval src_size as const integer ) as wstring ptr '/ _
		( _
			@FB_RTL_USTRASSIGNTOW, NULL, _
			typeAddrOf( FB_DATATYPE_WCHAR ), FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeAddrOf( FB_DATATYPE_WCHAR ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_WstrToUStr( byval src as const wstring ptr ) as ustring '/ _
		( _
			@FB_RTL_WSTR2USTR, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( typeAddrOf( typeSetIsConst( FB_DATATYPE_WCHAR ) ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrToWstr( byref src as const any, byval src_size as const integer ) as wstring ptr '/ _
		( _
			@FB_RTL_USTR2WSTR, NULL, _
			typeAddrOf( FB_DATATYPE_WCHAR ), FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' end of table '/ _
		( _
			NULL, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			0, _
			{ ( 0, 0, FALSE ) } _
		) _
	 }

'':::::
sub rtlUStringModInit( )

	rtlAddIntrinsicProcs( @funcdata(0) )

end sub

'':::::
sub rtlUStringModEnd( )

	'' procs will be deleted when symbEnd is called

end sub

'':::::
'' u = src   (or the initializing form, which skips deleting the old contents)
function rtlUStrAssign _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr, _
		byval is_init as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer ddtype = any, sdtype = any
	dim as longint dlgt = any, slgt = any

	function = NULL

	ddtype = astGetDataType( dst )
	sdtype = astGetDataType( src )

	'' WSTRING on either side is resolved by converting that side first, then
	'' falling into the ordinary path. Doing it here rather than adding two more
	'' entry-point shapes keeps the wstring temp handling in the one place fbc
	'' already gets it right.
	if( typeGet( sdtype ) = FB_DATATYPE_WCHAR ) then
		src = rtlWstrToUStr( src )
		sdtype = astGetDataType( src )
	elseif( typeGet( ddtype ) = FB_DATATYPE_WCHAR ) then
		'' ustring -> wstring, bounded by the destination's declared capacity
		return rtlUStrAssignToW( dst, src )
	end if

	'' Four combinations, because a ustring may be assigned from (or to) the
	'' narrow world. The conversion entry points take is_init as an explicit
	'' argument rather than having separate Init/Assign twins.
	dim as integer needs_conv = (typeIsUstring( ddtype ) <> typeIsUstring( sdtype ))

	if( needs_conv ) then
		if( typeIsUstring( ddtype ) ) then
			proc = astNewCALL( PROCLOOKUP( USTRASSIGNFROMA ) )
		else
			proc = astNewCALL( PROCLOOKUP( USTRASSIGNTOA ) )
		end if
	elseif( is_init ) then
		proc = astNewCALL( PROCLOOKUP( USTRINIT ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRASSIGN ) )
	end if

	'' NOTE: rtlCalcStrLen() must run BEFORE astNewARG(), because the latter
	'' can rewrite the expression (address-of etc) and lose the symbol the
	'' length is derived from. Same rule as the narrow builders.
	dlgt = rtlCalcStrLen( dst, ddtype )

	if( astNewARG( proc, dst ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( dlgt ) ) = NULL ) then exit function

	slgt = rtlCalcStrLen( src, sdtype )

	if( astNewARG( proc, src ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( slgt ) ) = NULL ) then exit function

	'' fillrem: only a fixed-length destination needs its tail zeroed
	dim as integer fillrem = any
	if( typeIsUstring( ddtype ) ) then
		fillrem = (ddtype = FB_DATATYPE_FIXUSTR)
	else
		fillrem = (ddtype = FB_DATATYPE_FIXSTR)
	end if
	if( astNewARG( proc, astNewCONSTi( fillrem ) ) = NULL ) then exit function

	'' the conversion entry points carry is_init as a sixth argument
	if( needs_conv ) then
		if( astNewARG( proc, astNewCONSTi( is_init ) ) = NULL ) then exit function
	end if

	'' the rtlib returns a pointer to the destination; nothing consumes it
	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
'' Mixed concatenation: one side ustring, the other narrow. The narrow side is
'' decoded to UTF-16 and the result is a ustring, so text never degrades to
'' bytes just because it was concatenated with a STRING.
function rtlUStrConcatMixed _
	( _
		byval str1 as ASTNODE ptr, _
		byval sdtype1 as integer, _
		byval str2 as ASTNODE ptr, _
		byval sdtype2 as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as FBSYMBOL ptr tmp = any
	dim as longint str1len = any, str2len = any

	function = NULL

	if( typeIsUstring( sdtype1 ) ) then
		proc = astNewCALL( PROCLOOKUP( USTRCONCATUA ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRCONCATAU ) )
	end if

	tmp = symbAddTempVar( FB_DATATYPE_USTRING )

	if( astNewARG( proc, astNewLINK( astBuildTempVarClear( tmp ), _
	                                 astNewVAR( tmp ), _
	                                 AST_LINK_RETURN_RIGHT ) ) = NULL ) then
		exit function
	end if

	'' lengths before astNewARG(), as everywhere else
	str1len = rtlCalcStrLen( str1, sdtype1 )
	str2len = rtlCalcStrLen( str2, sdtype2 )

	if( astNewARG( proc, str1, sdtype1 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str1len ) ) = NULL ) then exit function
	if( astNewARG( proc, str2, sdtype2 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str2len ) ) = NULL ) then exit function

	function = proc

end function

'':::::
'' a + b -> a fresh TEMP descriptor, so the assignment that consumes it can
'' steal the buffer rather than copy it
function rtlUStrConcat _
	( _
		byval str1 as ASTNODE ptr, _
		byval sdtype1 as integer, _
		byval str2 as ASTNODE ptr, _
		byval sdtype2 as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as FBSYMBOL ptr tmp = any
	dim as longint str1len = any, str2len = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRCONCAT ) )

	'' byref dst as ustring -- a temp the rtlib fills in and flags as temp
	tmp = symbAddTempVar( FB_DATATYPE_USTRING )

	if( astNewARG( proc, astNewLINK( astBuildTempVarClear( tmp ), _
	                                 astNewVAR( tmp ), _
	                                 AST_LINK_RETURN_RIGHT ) ) = NULL ) then
		exit function
	end if

	'' lengths first -- see the note in rtlUStrAssign()
	str1len = rtlCalcStrLen( str1, sdtype1 )
	str2len = rtlCalcStrLen( str2, sdtype2 )

	if( astNewARG( proc, str1, sdtype1 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str1len ) ) = NULL ) then exit function
	if( astNewARG( proc, str2, sdtype2 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str2len ) ) = NULL ) then exit function

	function = proc

end function

'':::::
'' u &= src
function rtlUStrConcatAssign _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer ddtype = any, sdtype = any
	dim as longint dlgt = any, slgt = any

	function = NULL

	ddtype = astGetDataType( dst )
	sdtype = astGetDataType( src )

	proc = astNewCALL( PROCLOOKUP( USTRCONCATASSIGN ) )

	dlgt = rtlCalcStrLen( dst, ddtype )
	if( astNewARG( proc, dst ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( dlgt ) ) = NULL ) then exit function

	slgt = rtlCalcStrLen( src, sdtype )
	if( astNewARG( proc, src ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( slgt ) ) = NULL ) then exit function

	if( astNewARG( proc, astNewCONSTi( ddtype = FB_DATATYPE_FIXUSTR ) ) = NULL ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
'' Convert a narrow string expression to a ustring temp. Used where an operation
'' has no mixed form of its own (comparison), so both sides can be made ustrings
'' first and the normal path taken.
'' Move a FUNCTION's ustring result out of its dying stack frame into a pooled
'' temp descriptor, and return a pointer to that.
function rtlUStrAllocTempResult _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRALLOCTEMPRES ) )

	if( astNewARG( proc, expr ) = NULL ) then exit function

	function = proc

end function

'':::::
'' u -> wstring destination.
''
'' Needs its own entry point rather than going through rtlWstrAssign(): the
'' destination's capacity has to be passed so the copy can be clamped, and the
'' runtime re-encodes (a copy where wchar is 16 bits, UTF-16 -> UTF-32 where it
'' is 32).
function rtlUStrAssignToW _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer sdtype = any
	dim as longint dlgt = any, slgt = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRASSIGNTOW ) )

	'' capacity INCLUDING the terminator, as rtlCalcStrLen() reports for WCHAR
	dlgt = rtlCalcStrLen( dst, astGetDataType( dst ) )
	if( astNewARG( proc, dst ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( dlgt ) ) = NULL ) then exit function

	sdtype = astGetDataType( src )
	slgt = rtlCalcStrLen( src, sdtype )
	if( astNewARG( proc, src, sdtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( slgt ) ) = NULL ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
'' Convert a wstring expression to a ustring temp.
''
'' On a target where wchar is 16 bits this is a straight copy; on Linux it is a
'' UTF-32 -> UTF-16 re-encode. The compiler cannot tell the two apart here --
'' the runtime branches on sizeof(FB_WCHAR).
function rtlWstrToUStr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( WSTR2USTR ) )

	'' byval src as wchar ptr -- let astNewARG() do the decay, as rtlWstrLen()
	'' does; forcing the dtype here passes a WSTRING * N by value instead
	if( astNewARG( proc, expr ) = NULL ) then exit function

	function = proc

end function

'':::::
'' Convert a ustring expression to a freshly allocated wchar buffer, which the
'' caller must delete -- same contract as every other wstring-returning rtlib
'' function.
function rtlUStrToWstr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( USTR2WSTR ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr, dtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
function rtlStrToUStr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( STR2USTR ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr, dtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
'' Convert a ustring expression to a narrow (UTF-8) string temp.
function rtlUStrToStr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( USTR2STR ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr, dtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
function rtlUStrDelete _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	'' A CALL result is already a temp descriptor from the pool, so it must go
	'' back through fb_hUStrDelTemp (which frees the descriptor slot too).
	'' A variable's own descriptor is not pooled -- only its data is freed.
	if( astIsCALL( expr ) ) then
		proc = astNewCALL( PROCLOOKUP( HUSTRDELTEMP ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRDELETE ) )
	end if

	if( astNewARG( proc, expr ) = NULL ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
function rtlUStrLen _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( USTRLEN ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
function rtlUStrCompare _
	( _
		byval str1 as ASTNODE ptr, _
		byval sdtype1 as integer, _
		byval str2 as ASTNODE ptr, _
		byval sdtype2 as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as longint str1len = any, str2len = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRCOMPARE ) )

	str1len = rtlCalcStrLen( str1, sdtype1 )
	str2len = rtlCalcStrLen( str2, sdtype2 )

	if( astNewARG( proc, str1, sdtype1 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str1len ) ) = NULL ) then exit function
	if( astNewARG( proc, str2, sdtype2 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str2len ) ) = NULL ) then exit function

	function = proc

end function
