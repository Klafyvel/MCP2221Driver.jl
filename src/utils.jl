"""
Produces bytes associated to a string, with at least `L` bytes per character.
If it is `strict`, then each character will be exactly `L` bytes, regardless of
correctness.
"""
struct ByteStringIterator{L}
    s::AbstractString
    strict::Bool
end
function Base.iterate(iter::ByteStringIterator{L}) where {L}
    if isempty(iter.s)
        return nothing
    end
    i = firstindex(iter.s)
    c = iter.s[i]
    if L == 1
        return (UInt8(c), (nextind(iter.s, i), 1))
    else
        return (UInt8(c & 0xff), (i, 2))
    end
end
function Base.iterate(iter::ByteStringIterator{L}, st) where {L}
    i = first(st)
    j = last(st)
    c = iter.s[i]
    val = UInt8((UInt32(c) >> (8 * j)) & 0xff)
    n = ncodeunits(c)
    if (j == L && iter.strict) || j == n
        nextstate = (nextind(iter.s, i), 1)
    else
        nextstate = (i, j + 1)
    end
    if !checkbounds(Bool, iter.s, first(nextstate))
        return nothing
    else
        return (val, nextstate)
    end
end
Base.eltype(::Type{ByteStringIterator{L}}) where {L} = UInt8
Base.isdone(iter::ByteStringIterator) = false
Base.isdone(iter::ByteStringIterator{L}, st) where {L} = (first(st) > lastindex(iter.s))
