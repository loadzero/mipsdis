# This file contains various formatting and parsing utilities.

def islower(c)
    ('a'..'z').include?(c)
end

def isupper(c)
    ('A'..'Z').include?(c)
end

def iscomment(x)
    x =~ /^\s*#/
end

def isblank(x)
    x =~ /^\s*$/
end

def tohex8(d)
    sprintf("0x%08x", d)
end
