'' Heap-leak probe: each iteration allocates ~1 KB of ustring buffers inside a
'' UDT, an array, and a dynamic array. If any destructor is missing, the working
'' set climbs without bound; if all fire, it stays flat.
type Rec
  s as ustring
end type

#include once "windows.bi"

declare function GetProcessMemoryInfoA alias "GetProcessMemoryInfo" (byval as any ptr, byval as any ptr, byval as ulong) as long

type PROCMEM
  cb as ulong
  PageFaultCount as ulong
  PeakWorkingSetSize as uinteger
  WorkingSetSize as uinteger
  QuotaPeakPagedPoolUsage as uinteger
  QuotaPagedPoolUsage as uinteger
  QuotaPeakNonPagedPoolUsage as uinteger
  QuotaNonPagedPoolUsage as uinteger
  PagefileUsage as uinteger
  PeakPagefileUsage as uinteger
end type

function ws() as uinteger
  dim as PROCMEM pm : pm.cb = sizeof(pm)
  GetProcessMemoryInfoA( GetCurrentProcess(), @pm, sizeof(pm) )
  return pm.WorkingSetSize
end function

sub churn( byval n as integer )
  for i as integer = 1 to n
    dim as Rec q
    q.s = string(500, asc("x"))
    dim as ustring a(1 to 4)
    a(1) = q.s : a(2) = q.s
    redim as ustring d(0 to 3)
    d(0) = q.s
    erase d
  next
end sub

churn(2000)          '' warm up
dim as uinteger before = ws()
churn(40000)
dim as uinteger after = ws()
print "working set before:"; before \ 1024; " KB"
print "working set after :"; after \ 1024; " KB"
dim as longint growth = cast(longint, after) - cast(longint, before)
print "growth            :"; growth \ 1024; " KB"
if growth > 4*1024*1024 then
  print "LEAK: working set grew by more than 4 MB over 40000 iterations"
  end 1
else
  print "OK: flat"
end if
