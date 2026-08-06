'' Append performance: USTRING vs STRING vs WSTRING.
''
'' READ THIS BEFORE READING THE NUMBERS
''
'' These types do not move the same amount of memory per character, and no
'' benchmark can make them:
''
''   STRING   1 byte  per character
''   USTRING  2 bytes per character (a UTF-16 code unit, on every target)
''   WSTRING  2 bytes on Windows, 4 on Linux -- and FIXED LENGTH, so it cannot
''            grow at all; it is included to show what the alternative costs,
''            not because it is a like-for-like competitor
''
'' So a USTRING moving twice the bytes of a STRING at similar speed is the
'' expected good result, not a loss. What these tests are actually checking is
'' that appending is AMORTISED LINEAR -- that the growth strategy does not
'' degrade into the quadratic realloc-every-time behaviour a naive
'' implementation has.
''
'' The quadratic check at the end is the one that matters most: it compares the
'' same operation at 1x and 4x the iteration count. Linear growth gives a ratio
'' near 4. A ratio near 16 would mean every append reallocates.

const REPS = 3          '' each measurement is the best of REPS

dim shared as double t0

sub tic( )
    t0 = timer
end sub

function toc( ) as double
    return ( timer - t0 ) * 1000.0        '' milliseconds
end function

'' Prints one result row. 'moved' is the number of BYTES the type had to move,
'' so the last column is the honest cross-type comparison.
sub row( byref nm as string, byval ms as double, byval chars as longint, byval bytes_per as integer )
    dim as double mb = (chars * bytes_per) / 1048576.0
    print using "  \                    \ ####.## ms   ####.# MB moved   #####.# MB/s"; _
          nm; ms; mb; iif( ms > 0, mb / (ms / 1000.0), 0.0 )
end sub

'' ============================================================ single char
'' The classic case: append one character, a million times. This is where a
'' bad growth strategy shows up immediately.

sub bench_single( byval n as integer )
    dim as double best, ms
    dim as longint total

    print "Append 1 character x "; n

    best = 1e30
    for r as integer = 1 to REPS
        dim as string s
        tic()
        for i as integer = 1 to n
            s += "x"
        next
        ms = toc()
        total = len(s)
        if( ms < best ) then best = ms
    next
    row( "STRING", best, total, 1 )

    best = 1e30
    for r as integer = 1 to REPS
        dim as ustring u
        tic()
        for i as integer = 1 to n
            u += "x"
        next
        ms = toc()
        total = len(u)
        if( ms < best ) then best = ms
    next
    row( "USTRING", best, total, 2 )

    print
end sub

'' ============================================================ chunk append
'' Appending a longer run at a time: less loop overhead, more memcpy.

sub bench_chunk( byval n as integer )
    dim as double best, ms
    dim as longint total
    dim as string  chunk_s = "abcdefghijklmnopqrstuvwxyz012345"   '' 32 chars

    print "Append 32 characters x "; n

    best = 1e30
    for r as integer = 1 to REPS
        dim as string s
        tic()
        for i as integer = 1 to n
            s += chunk_s
        next
        ms = toc()
        total = len(s)
        if( ms < best ) then best = ms
    next
    row( "STRING", best, total, 1 )

    dim as ustring chunk_u = chunk_s
    best = 1e30
    for r as integer = 1 to REPS
        dim as ustring u
        tic()
        for i as integer = 1 to n
            u += chunk_u
        next
        ms = toc()
        total = len(u)
        if( ms < best ) then best = ms
    next
    row( "USTRING", best, total, 2 )

    print
end sub

'' ============================================== multi-term concatenation
'' u = a + b + c + d must lower to one assign plus three concat-assigns, with
'' no temporary allocated per term. If it did not, this would be far slower.

sub bench_multi( byval n as integer )
    dim as double best, ms
    dim as longint total

    print "u = a + b + c + d  x "; n

    dim as string sa = "alpha", sb = "beta", sc = "gamma", sd = "delta"
    best = 1e30
    for r as integer = 1 to REPS
        dim as string s
        tic()
        for i as integer = 1 to n
            s = sa + sb + sc + sd
        next
        ms = toc()
        total = len(s) * n
        if( ms < best ) then best = ms
    next
    row( "STRING", best, total, 1 )

    dim as ustring ua = "alpha", ub = "beta", uc = "gamma", ud = "delta"
    best = 1e30
    for r as integer = 1 to REPS
        dim as ustring u
        tic()
        for i as integer = 1 to n
            u = ua + ub + uc + ud
        next
        ms = toc()
        total = len(u) * n
        if( ms < best ) then best = ms
    next
    row( "USTRING", best, total, 2 )

    print
end sub

'' ================================================ WSTRING appends are O(n^2)
''
'' This is the sharpest practical difference, and it is not a tuning detail --
'' it is structural. A WSTRING has no length field: fb_WstrConcatAssign has to
'' WALK TO THE TERMINATOR on every single append to find out where the end is.
'' Appending n times therefore costs O(n^2).
''
'' A USTRING keeps its length in the descriptor, so an append is O(1) amortised.
''
'' The counts here are deliberately small. At the 2,000,000 used above, the
'' WSTRING loop does not finish in any reasonable time -- that is the point.

sub bench_wstring( byval n as integer )
    dim as double best, ms, t1, t2

    print "WSTRING vs USTRING append, at n and 2n"
    print "  (linear = ratio near 2;  quadratic = ratio near 4)"
    print

    for pass as integer = 0 to 1
        dim as integer m = iif( pass = 0, n, n * 2 )

        best = 1e30
        for r as integer = 1 to REPS
            dim as wstring ptr w = callocate( (m + 1) * sizeof(wstring) )
            *w = ""
            tic()
            for i as integer = 1 to m
                *w += "x"
            next
            ms = toc()
            if( len(*w) <> m ) then print "  WSTRING LENGTH WRONG"
            deallocate w
            if( ms < best ) then best = ms
        next
        if( pass = 0 ) then t1 = best else t2 = best
    next
    print using "  WSTRING  n = ####.## ms   2n = #####.## ms   ratio = ##.##"; _
          t1; t2; iif( t1 > 0, t2 / t1, 0.0 )

    for pass as integer = 0 to 1
        dim as integer m = iif( pass = 0, n, n * 2 )

        best = 1e30
        for r as integer = 1 to REPS
            dim as ustring u
            tic()
            for i as integer = 1 to m
                u += "x"
            next
            ms = toc()
            if( len(u) <> m ) then print "  USTRING LENGTH WRONG"
            if( ms < best ) then best = ms
        next
        if( pass = 0 ) then t1 = best else t2 = best
    next
    print using "  USTRING  n = ####.## ms   2n = #####.## ms   ratio = ##.##"; _
          t1; t2; iif( t1 > 0, t2 / t1, 0.0 )

    print
end sub

'' ====================================================== growth is linear
'' THE IMPORTANT ONE. Same work at 1x and 4x. Amortised-linear growth gives a
'' ratio near 4; realloc-on-every-append would give ~16.

sub bench_scaling( byval n0 as integer )
    dim as double t1, t4, best, ms

    print "Growth check -- ratio of 4x work to 1x work"
    print "  (near 4.0 = amortised linear;  near 16 = quadratic)"
    print

    for pass as integer = 0 to 1
        dim as integer n = iif( pass = 0, n0, n0 * 4 )

        best = 1e30
        for r as integer = 1 to REPS
            dim as ustring u
            tic()
            for i as integer = 1 to n
                u += "x"
            next
            ms = toc()
            if( len(u) <> n ) then print "  LENGTH WRONG"
            if( ms < best ) then best = ms
        next

        if( pass = 0 ) then t1 = best else t4 = best
    next

    print using "  USTRING  1x = ####.## ms    4x = ####.## ms    ratio = ##.##"; _
          t1; t4; iif( t1 > 0, t4 / t1, 0.0 )

    for pass as integer = 0 to 1
        dim as integer n = iif( pass = 0, n0, n0 * 4 )

        best = 1e30
        for r as integer = 1 to REPS
            dim as string s
            tic()
            for i as integer = 1 to n
                s += "x"
            next
            ms = toc()
            if( ms < best ) then best = ms
        next

        if( pass = 0 ) then t1 = best else t4 = best
    next

    print using "  STRING   1x = ####.## ms    4x = ####.## ms    ratio = ##.##"; _
          t1; t4; iif( t1 > 0, t4 / t1, 0.0 )

    print
end sub

'' ==========================================================================

print "USTRING append benchmark"
print "  built for "; __FB_SIGNATURE__
print "  sizeof(wstring) ="; sizeof(wstring); " bytes"
print

bench_single( 2000000 )
bench_chunk( 500000 )
bench_multi( 1000000 )
bench_wstring( 40000 )
bench_scaling( 1000000 )
