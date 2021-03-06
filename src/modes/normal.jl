include("extra_modes.jl")

function after_normal(b::Buffer)
    clear_arg(b)
    clamp!(b)
    set_boundaries(b)
end

function delete_char(b::Buffer)
    setundo(b)
    deleteat(b, b.cursor.pos, parse_n(b))
    after(b)
end

function join_arg(b::Buffer)
    setundo(b)
    n = parse_n(b.args)
    join_lines(b, (b.cursor.pos[1],b.cursor.pos[1]+n))
    after(b)
end
function insert(b::Buffer)
    setmode(b,insert_mode)
    if x(b) == 0
        b.cursor.pos[2] = 1
    end
end
function inserta(b::Buffer)
    b.cursor.pos[2] += 1
    setmode(b, insert_mode)
end
function insert_beginning(b::Buffer) #different from vim on white non-empty lines
    b.cursor.pos[2] = nextword_pos(line(b), 1)
    insert(b)
end
insert_end(b::Buffer) = (move_eol(b); inserta(b))

function enter_cmdmode(b::Buffer)
    setmode(b,command_mode)
end

function start_replay(b::Buffer)
    setmode(b, replay_mode)
end

function enter_deletemode(b::Buffer)
    #This should be in a before() function
    #Also unsure if this is a good way of storing vars
    b.state[:lx] = xs(b)
    b.state[:ly] = ys(b)
    setmode(b, delete_mode)
end

function enter_yankmode(b::Buffer)
    #This should be in a before() function
    #Also unsure if this is a good way of storing vars
    b.state[:lx] = xs(b)
    b.state[:ly] = ys(b)
    setmode(b, yank_mode)
end

function enter_registermode(b::Buffer)
    setmode(b, register_clipboardmode )
end

function enter_replacemode(b::Buffer)
    setmode(b, replace_mode)
end

function pastea_register(b::Buffer)
    s = b.state[:register][1]
    pastea(b, s)
    b.state[:register] = "\""
end
function paste_register(b::Buffer)
    s = b.state[:register][1]
    paste(b, s)
    b.state[:register] = "\""
end
const normal_actions = merge(movements,
                       Dict('i'    => insert,
                            'a'    => inserta,
                            'I'    => insert_beginning,
                            'A'    => insert_end,
                            '\e'   => clear_arg,
                            ':'    => enter_cmdmode,
                            'x'    => delete_char,
                            'r'    => enter_replacemode,
                            'J'    => join_arg,
                            'q'    => start_record,
                            '@'    => start_replay,
                            'd'    => enter_deletemode,
                            'y'    => enter_yankmode,
                            '"'    => enter_registermode,
                            'p'    => pastea_register,
                            'P'    => paste_register,
                            'u'    => undo,
                            '\x12' => redo,
                            'Z'    => quit,
                           )
                      )

function nmap(c::Char, f)
    normal_actions[c] = f
end
function nmap(c::Char, s::String)
    normal_actions[c] = b -> replay(b, s)
end
normal_mode = Mode("normal", normal_actions)
