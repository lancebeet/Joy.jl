#Go mode

function after_go(b::Buffer)
    setmode(b, b.mode[2])
    after(b)
end
function go_join(b::Buffer)
    n = parse_n(b::Buffer)
    join_lines(b, y(b):y(b)+n, "")
    after(b)
    escape(b)
end
function gogo(b::Buffer)
    b.cursor.pos[1] = parse_n(b)
    after(b) 
    escape(b)
end

go_actions = Dict('g' => gogo,
                  'G' => gobottom,
                  'J' => go_join,
                  '\e' => escape,
                 )
go_mode = Mode("go", go_actions)

#Macro modes

function set_record_register(c)
    cv = string(c)
    function set(b)
        b.state[:recording] = cv
        #This is a bad solution since it assumes all key presses are saved and never purged
        b.state[:macroindex] = string(length(b.state[:actions])+1)
        escape(b)
        b.state[:log] = "Recording to register $c"
    end
end

register_recordmode = Mode("register macro", Action(set_record_register, x->true))

function start_record(b::Buffer)
    if !in(:recording, keys(b.state)) || b.state[:recording] == "\e"
        setmode(b, register_recordmode)
    else
        b.registers[b.state[:recording][1]] = join(b.state[:actions][parse(b.state[:macroindex]):end-1])
        b.state[:log] = "Finished recording to register $(b.state[:recording])"
        b.state[:recording] = "\e"
    end
end

#Macros can't refer to other macros with this solution, this produces two copies of the previous macro
function replay_register(c)
    function replay_macro(b::Buffer)
        escape(b)
        n = parse_n(b)
        resize!(b.args,0) #It would be better to just remove the numbers, this might be useful in the future
        if in(c, keys(b.registers))
            replay(b, b.registers[c], n)
        else
            b.state[:log] = "No macro in register $c"
        end
    end
end

replay_mode = Mode("replay", Action(replay_register, x->true))

#Delete mode

function after_delete(b::Buffer)
    p1 = [parse(b.state[:ly]), parse(b.state[:lx])]
    p2 = pos(b)
    delete_between(b, p1, p2, b.state[:register][1])
    clear_arg(b)
    b.state[:register] = "\""
    escape(b)
end

function delete_lines(b::Buffer)
    #We need a yank here
    n = parse_n(b.args)
    delete_lines(b, y(b):y(b)+n-1)
    escape(b)
end

delete_extras = Dict( 'd' => delete_lines,
                      '\e' => escape,
                     )
delete_actions = merge(movements, delete_extras)
delete_mode = Mode("delete", delete_actions)

function after_yank(b::Buffer)
    p1 = [parse(b.state[:ly]), parse(b.state[:lx])]
    p2 = pos(b)
    yank_between(b, p1, p2, b.state[:register][1])
    b.cursor.pos .= p1
    clear_arg(b)
    b.state[:register] = "\""
    escape(b)
end

function yank_lines(b::Buffer, range::Range)
    reg = b.state[:register][1]
    range = clamp_range(range, 1, height(b))
    b.registers[reg] = string('\e', join(b.text[range], '\n'))
    #Line copies add an escape symbol before the text
end
    
function yank_lines(b::Buffer)
    n = parse_n(b.args)
    yank_lines(b, y(b):y(b)+n-1)
    escape(b)
end

yank_extras = Dict( 'y' => yank_lines,
                      '\e' => escape,
                     )
yank_actions = merge(movements, yank_extras)
yank_mode = Mode("yank", yank_actions)

#bug or not? it does not reset the state[:register] if a non-yank/paste operation
#is performed, but we can reset it in the after procedures, not sure if there's a difference
function set_clipboard_register(c)
    cv = string(c)
    function set(b)
        b.state[:register] = cv
        escape(b)
    end
end

register_clipboardmode = Mode("register", Action(set_clipboard_register, x->true))
#Find char modes

#This doesn't quite work as intended with delete, the sensible approach in vim is to remove the last
# character as well (dtc is used for exlucive delete until)
function after_find(b::Buffer)
    setmode(b, b.mode[2])
    after(b)
end

function find_action(c::Char)
    function find(b::Buffer)
        b.cursor.pos[2] = findsymbol(b::Buffer, c)
        after(b)
    end
end

find_mode = Mode("find", Action(find_action, x->true))

function replace_action(c)
    function replace(b::Buffer)
        if c=='\e'
            escape(b)
        elseif c=='\x7f'
            escape(b)
        elseif c=='\r'
            deleteat(b, pos(b), 1)
            splitp(b)
            escape(b)
        else 
            setline(b, string(line(b)[1:x(b)-1], c, line(b)[x(b)+1:end]))  #Warning: Unicode might not work here
            escape(b)
        end
    end
end
replace_mode = Mode("replace", Action(replace_action, x->true))
