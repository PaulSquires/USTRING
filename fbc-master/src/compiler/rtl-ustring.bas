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

	if( is_init ) then
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
	if( astNewARG( proc, astNewCONSTi( ddtype = FB_DATATYPE_FIXUSTR ) ) = NULL ) then exit function

	'' the rtlib returns a pointer to the destination; nothing consumes it
	astSetType( proc, FB_DATATYPE_VOID, NULL )

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
