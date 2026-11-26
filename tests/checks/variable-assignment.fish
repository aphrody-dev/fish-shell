# RUN: %fish %s

# erase all lowercase variables to make sure they don't break our tests
for varname in (set -xn | string match -r '^[a-z].*')
    while set -q $varname
        set -e $varname
    end
end

# CHECK: bar
foo=bar echo $foo

# CHECK: nil
set -q foo; or echo nil

# CHECK: lx
foo=bar set -qlx foo; and echo lx

# CHECK: 3
a={1, 2, 3} count $a

# CHECK: 1+2+3
a={1, 2, 3} string join + $a

# CHECK: 1 2 3
a=(echo 1 2 3) echo $a

# CHECK: a a2
a=a b={$a}2 echo $a $b

# CHECK: a
a=a builtin echo $a

# CHECK: 0
a=failing-glob-* count $a

# CHECK: ''
a=b true | echo "'$a'"

if a=b true
    # CHECK: ''
    echo "'$a'"
end

# CHECK: b
not a=b echo $a

# CHECK: b
a=b not echo $a

# CHECK: b
a=b not builtin echo $a

# CHECK: /usr/bin:/bin
xPATH={/usr,}/bin sh -c 'echo $xPATH'

# CHECK: 2
yPATH=/usr/bin:/bin count $yPATH

# CHECK: b
a=b begin
    true | echo $a
end

# CHECK: b
a=b if true
    echo $a
end

# CHECK: b
a=b switch x
    case x
        echo $a
end

complete -c x --erase
complete -c x -xa arg
complete -C' a=b x ' # Mind the leading space.
# CHECK: arg
alias xalias=x
complete -C'a=b xalias '
# CHECK: arg
alias envxalias='a=b x'
complete -C'a=b envxalias '
# CHECK: arg

# A job of only assignments sets them like `set`, left to right.
a=(echo b)
# CHECK: b
echo $a
a=1 b={$a}2
# CHECK: 1 12
echo $a $b
a=
# CHECK: 1 ''
echo (count $a) "'$a'"
false; a=$status
# CHECK: 1 0
echo $a $status
a=(false)
# CHECK: 1
echo $status
a=c && echo and $a
# CHECK: and c
function bare_local
    bare_x=inner
    echo $bare_x
end
# CHECK: inner
bare_local
# CHECK: nil
set -q bare_x; or echo nil
set -gx bare_exported old
bare_exported=new
# CHECK: new
sh -c 'echo $bare_exported'
set -e a b bare_exported
status=2
# CHECKERR: fish: Tried to change the read-only variable 'status'
# CHECK: status 1
echo status $status

# Eval invalid grammar to allow fish to parse this file
eval ': | a=b'
# CHECKERR: {{.*}}: Unsupported use of '='. In fish, please use 'set a b'.
# CHECKERR: {{^}}: | a=b
# CHECKERR: {{^}}    ^~^
eval 'not a=b'
# CHECKERR: {{.*}}: Unsupported use of '='. In fish, please use 'set a b'.
# CHECKERR: {{^}}not a=b
# CHECKERR: {{^}}    ^~^

complete -c foo -xa '$a'
a=b complete -C'foo '
#CHECK: b
